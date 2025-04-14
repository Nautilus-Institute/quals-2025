from typing import List, Callable, Optional, Dict
import argparse
import json
import binascii
import random
import struct
import tempfile
import subprocess
import os
import shutil
import multiprocessing
from concurrent.futures import ProcessPoolExecutor

import jinja2
from rich import print
from rich.progress import (
    Progress,
    BarColumn,
    TextColumn,
    TaskProgressColumn,
    TimeRemainingColumn,
    TimeElapsedColumn,
    MofNCompleteColumn,
)

from template import TEMPLATES
from obfuscation_option import ObfuscationOption, Xor8B, get_random_obfuscation_scheme


DEBUG = False
STATIC = False


def make_large_function(asm_path: str, padding: bytes) -> None:
    with open(asm_path, "r") as f:
        data = f.read()
    padding_text = "\n".join([f".byte {b:#02x}" for b in padding])
    data += "\n\n" + ".text\n" + padding_text + "\n"
    with open(asm_path, "w") as f:
        f.write(data)


def compile_c_plain(source: str, dst_path: str, png_hidden_config: dict[str, int | bytes] | None, mp_lock) -> None:
    """
    Zero protection whatsoever
    """
    arch = "x86_64"
    with tempfile.TemporaryDirectory() as tmpdir:
        src_path = os.path.join(tmpdir, "src.c")
        # tmp_dst_path = os.path.join(tmpdir, "dst")
        tmp_dst_obj_path = os.path.join(tmpdir, "dst.o")
        tmp_dst_asm_path = os.path.join(tmpdir, "dst.s")
        with open(src_path, "w") as f:
            f.write(source)

        if arch == "x86_64":
            gpp = "x86_64-w64-mingw32-gcc"
            strip = "x86_64-w64-mingw32-strip"
        else:
            raise NotImplementedError(f"Unknown arch {arch}")

        src = [src_path]
        if STATIC:
            static_ = ["-static"]
        else:
            static_ = []
        if DEBUG:
            proc = subprocess.Popen(
                [gpp, "-g"]
                + static_
                + src
                + [
                    "-S",
                    "-O1",
                    "-masm=intel",
                    "-mcmodel=large",
                    "-fcf-protection=none",
                    "-fno-stack-protector",
                    "-Wno-format-security",
                    "-fno-asynchronous-unwind-tables",
                    "-fno-unwind-tables",
                    "-fno-exceptions",
                    "-o",
                    tmp_dst_asm_path,
                    "-Wno-unused-result",
                ],
                stdin=subprocess.DEVNULL,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                shell=False,
            )
        else:
            proc = subprocess.Popen(
                [gpp, "-O0"]
                + static_
                + src
                + [
                    "-S",
                    "-O1",
                    "-masm=intel",
                    "-mcmodel=large",
                    "-fcf-protection=none",
                    "-fno-stack-protector",
                    "-Wno-format-security",
                    "-fno-asynchronous-unwind-tables",
                    "-fno-unwind-tables",
                    "-fno-exceptions",
                    "-o",
                    tmp_dst_asm_path,
                    "-Wno-unused-result",
                ],
                stdin=subprocess.DEVNULL,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                shell=False,
            )
        out, err = proc.communicate()
        if proc.returncode != 0:
            print(err.decode("utf-8"))
            # copy the file somewhere
            shutil.copy(src_path, "/tmp/gen_failure.c")
            raise RuntimeError("Decompilation failed")

        chain_idx = int(os.path.basename(dst_path).split(".")[0])
        # TODO: Use chain_idx to determine the configuration

        if png_hidden_config is not None:
            total_length = random.randint(90000, 120000)
            if png_hidden_config["store_before_encryption"] == 1:
                prefix_length = random.randint(1, total_length - len(png_hidden_config["chunk"]) - 1)
                suffix_length = total_length - prefix_length - len(png_hidden_config["chunk"])
                assert prefix_length >= 0 and suffix_length >= 0
                rand_bytes = random.randbytes(prefix_length) + png_hidden_config["chunk"] + random.randbytes(suffix_length)
            else:
                rand_bytes = random.randbytes(total_length)
        else:
            total_length = random.randint(10000, 120000)
            rand_bytes = random.randbytes(total_length)

        make_large_function(tmp_dst_asm_path, rand_bytes)

        subprocess.check_call(
            [gpp, tmp_dst_asm_path] + ["-c", "-o", tmp_dst_obj_path], stdin=subprocess.DEVNULL, shell=False
        )
        shutil.move(tmp_dst_obj_path, dst_path)


def chop_data(data: bytes) -> List[int]:
    lst = []
    for i in range(0, len(data), 8):
        chunk = data[i : i + 8]
        if len(chunk) < 8:
            chunk = chunk + b"\x00" * (8 - len(chunk))
        lst.append(struct.unpack("<Q", chunk)[0])
    return lst


def gen_source_file(
    env: jinja2.Environment,
    template_name: str,
    idx: int,
    is_last_func: bool,
    next_obf_option: ObfuscationOption | None,
    **kwargs,
) -> str:
    tmpl = env.get_template(template_name)
    # update kwargs with more necessary arguments
    func_idx = f"{idx * 8}"
    if not is_last_func:
        decrypt_next = next_obf_option.c_code(
            env,
            call_next=f"run_{idx * 8 + 8}();",
        ) if next_obf_option else "static void decrypt_next(unsigned long long key) {}"
        call_next_decl = f"void run_{idx * 8 + 8}();\nstatic void decrypt_next(unsigned long long key);\n"
    else:
        decrypt_next = "static void decrypt_next(unsigned long long key) {}"
        call_next_decl = "static void decrypt_next(unsigned long long key);"
    return tmpl.render(
        func_idx=func_idx,
        decrypt_next=decrypt_next,
        call_next_decl=call_next_decl,
        **kwargs,
    )


def build_binaries(
    all_workers: int,
    n: int,
    task_id,
    chopped_ints: list[int],
    easy_ints: int,
    templates_expanded: list[tuple[str, Callable, Callable]],
    templates_expanded_easy: list[tuple[str, Callable, Callable]],
    output_dir: str,
    func_obf_options: dict[str, ObfuscationOption],
    mp_lock,
    progress,
):
    env = jinja2.Environment(loader=jinja2.FileSystemLoader("templates/"))
    random.seed(0x1333337 + n)  # seed the process

    png_hidden_config = load_png_hidden_config()

    for idx, int_ in enumerate(chopped_ints):
        if idx % all_workers == n:
            if idx < easy_ints:
                tmpl, get_args, compile_ = random.choice(templates_expanded_easy)
            else:
                tmpl, get_args, compile_ = random.choice(templates_expanded)

            kwargs = get_args(int_)
            next_func_name = f"run_{(idx + 1) * 8}"
            obf_option = func_obf_options[next_func_name] if next_func_name in func_obf_options else None
            src = gen_source_file(env, tmpl, idx, idx == len(chopped_ints) - 1, obf_option, **kwargs)

            try:
                os.mkdir(output_dir)
            except FileExistsError:
                pass
            dst = os.path.join(output_dir, f"{str(idx).zfill(5)}.o")
            compile_(src, dst, png_hidden_config.get(idx, None), mp_lock)
        progress[task_id] = {"progress": idx + 1, "total": len(chopped_ints)}


def generate_function_obfuscation_options(total_funcs: int, easy_funcs: int, is_dummy: bool) -> dict[str, ObfuscationOption]:
    options = {}
    if is_dummy:
        for i in range(total_funcs):
            if i == 0:
                cls = Xor8B
                key_offset = 0
            elif i < easy_funcs:
                cls = get_random_obfuscation_scheme(easy=True)
                key_offset = random.randint(0, 0xffff_ffff)
            else:
                cls = get_random_obfuscation_scheme()
                key_offset = random.randint(0, 0xffff_ffff)
            options[f"run_{i * 8}"] = cls(0x140001111, 5007, 0, key_offset=key_offset)
        return options

    with open("func_info.json", "r") as f:
        func_info = json.load(f)

    assert len(func_info) == total_funcs

    i = 0
    for func_name, info in sorted(func_info.items(), key=lambda x: x[1]["rebased_addr"]):
        if func_name == "run_0":
            cls = Xor8B
            key_offset = 0
        elif i < easy_funcs:
            cls = get_random_obfuscation_scheme(easy=True)
            key_offset = random.randint(0, 0xffff_ffff)
        else:
            cls = get_random_obfuscation_scheme()
            key_offset = random.randint(0, 0xffff_ffff)
        options[func_name] = cls(info["rebased_addr"], info["size"], info["file_offset"], key_offset=key_offset)
        i += 1
    return options


def dump_function_obfuscation_options(func_obf_options: dict[str, ObfuscationOption], chopped_ints: List[int]):
    options = {}

    keys = [0x220c15c8ddfefaf0] + chopped_ints[:-1]
    for i, key in enumerate(keys):
        func_name = f"run_{i * 8}"
        option = func_obf_options[func_name]
        options[func_name] = {
            "obf_name": option.obf_name.value,
            "addr": option.addr,
            "size": option.size,
            "file_offset": option.file_offset,
            "key_offset": option.key_offset,
            "key": key,
        }

    with open("func_obf_options.json", "w") as f:
        json.dump(options, f, indent=2)


def chop_png(data: bytes) -> list[bytes]:
    chunks = []
    assert data.startswith(b"\x89PNG\r\n\x1a\n")
    offset = 8
    while True:
        chunk_len = struct.unpack(">I", data[offset:offset+4])[0]
        if chunk_len == 0:
            break
        chunk = data[offset : offset + chunk_len + 12]
        assert len(chunk) == chunk_len + 12, f"Broken PNG chunks at offset {offset}"
        chunks.append(chunk)
        offset += chunk_len + 12
    return chunks


def determine_png_hidden_config(total_ints: int, chopped_png_chunks: list[bytes]) -> dict[dict[str, int | bytes]]:
    config = {}
    choped_png_chunks_len = min(total_ints, len(chopped_png_chunks))
    interval = total_ints // choped_png_chunks_len
    for i in range(choped_png_chunks_len):
        d = {
            "int_idx": i * interval,
            "chunk": chopped_png_chunks[i],
            "store_before_encryption": random.randint(0, 1),
        }
        config[d["int_idx"]] = d
    if len(config) < len(chopped_png_chunks):
        print(f"[red]Warning: Not enough chopped png chunks to hide all the functions. "
              f"Only {len(config)} out of {len(chopped_png_chunks)} will be stored![/red]")
    return config


def dump_png_hidden_config(png_hidden_config: dict[int, dict[str, int | bytes]]):
    with open("png_hidden_config.json", "w") as f:
        d = []
        for int_idx, conf in sorted(png_hidden_config.items(), key=lambda x: x[0]):
            d.append({
                "int_idx": int_idx,
                "chunk": conf["chunk"].hex(),
                "store_before_encryption": conf["store_before_encryption"],
            })
        json.dump(d, f, indent=2)


def load_png_hidden_config() -> dict[int, dict[str, int | bytes]]:
    with open("png_hidden_config.json", "r") as f:
        d = json.load(f)
    config = {}
    for x in d:
        config[x["int_idx"]] = {
            "int_idx": x["int_idx"],
            "chunk": binascii.unhexlify(x["chunk"]),
            "store_before_encryption": x["store_before_encryption"],
        }
    return config


def main():
    # parse command line arguments
    parser = argparse.ArgumentParser()
    parser.add_argument("--img1", type=str, required=True)
    parser.add_argument("--img2", type=str, required=True)
    parser.add_argument("--img3", type=str, required=True)
    parser.add_argument("--output", type=str, required=True)
    parser.add_argument("--workers", type=int, default=1)
    parser.add_argument("--pass-idx", type=int, required=True)
    args = parser.parse_args()

    img0_path = args.img1
    img1_path = args.img2
    img2_path = args.img3
    output_dir = args.output
    nworkers = args.workers
    pass_idx = args.pass_idx

    assert pass_idx in {1, 2}

    with open(img0_path, "rb") as f:
        data0 = f.read()
    with open(img1_path, "rb") as f:
        data1 = f.read()
    with open(img2_path, "rb") as f:
        data2 = f.read()

    chopped_ints0 = chop_data(data0)
    chopped_ints1 = chop_data(data1)
    print(f"We got {len(chopped_ints0)} chopped ints out of the first file.")
    print(f"We got {len(chopped_ints1)} chopped ints out of the second file.")

    chopped_png_chunks = chop_png(data2)
    print(f"We got {len(chopped_png_chunks)} chopped png chunks out of the third file.")

    # let's determine where we put these chopped png chunks
    random.seed(0xc0debabe)
    orig_png_hidden_config = determine_png_hidden_config(len(chopped_ints1), chopped_png_chunks)
    # since we don't hide any PNG data for chopped_ints0, we need to update the offsets
    png_hidden_config = {}
    for conf in orig_png_hidden_config.values():
        conf["int_idx"] += len(chopped_ints0)
        png_hidden_config[conf["int_idx"]] = conf
    dump_png_hidden_config(png_hidden_config)

    # load functions and generate their obfuscation options
    if pass_idx == 2:
        func_obf_options = generate_function_obfuscation_options(len(chopped_ints0) + len(chopped_ints1), len(chopped_ints0), False)
        dump_function_obfuscation_options(func_obf_options, chopped_ints0 + chopped_ints1)
    else:
        func_obf_options = generate_function_obfuscation_options(len(chopped_ints0) + len(chopped_ints1), len(chopped_ints0), True)
    assert func_obf_options

    # seed it again because generate_function_obfuscation_options uses random (sometimes*
    random.seed(0x1333337)
    # expand TEMPLATES
    templates_expanded = []
    templates_expanded_easy = []
    for template in TEMPLATES:
        compile_choice = compile_c_plain
        templates_expanded.append((template.template_name, template.arg_func, compile_choice))
        if template.easy:
            templates_expanded_easy.append((template.template_name, template.arg_func, compile_choice))

    print(f"[+] Expanded templates: {len(templates_expanded)}")
    print(f"[+] Expanded easy templates: {len(templates_expanded_easy)}")

    progress = Progress(
        TextColumn("[progress.description]{task.description}"),
        BarColumn(),
        TaskProgressColumn(),
        MofNCompleteColumn(),
        TimeElapsedColumn(),
        TimeRemainingColumn(),
        expand=True,
    )
    with progress:
        futures = []  # keep track of the jobs
        with multiprocessing.Manager() as manager:
            # this is the key - we share some state between our
            # main process and our worker functions
            _progress = manager.dict()
            overall_progress_task = progress.add_task("[green]All jobs progress:")
            mp_lock = manager.Lock()

            with ProcessPoolExecutor(max_workers=nworkers) as executor:
                for n in range(0, nworkers):  # iterate over the jobs we need to run
                    # set visible false so we don't have a lot of bars all at once:
                    task_id = progress.add_task(f"task {n}", visible=False)
                    futures.append(
                        executor.submit(
                            build_binaries,
                            nworkers,
                            n,
                            task_id,
                            chopped_ints0 + chopped_ints1,
                            len(chopped_ints0),
                            templates_expanded,
                            templates_expanded_easy,
                            output_dir,
                            func_obf_options,
                            mp_lock,
                            _progress,
                        )
                    )

                # monitor the progress:
                while (n_finished := sum([future.done() for future in futures])) < len(futures):
                    progress.update(overall_progress_task, completed=n_finished, total=len(futures))
                    for task_id, update_data in _progress.items():
                        latest = update_data["progress"]
                        total = update_data["total"]
                        # update the progress bar for this task:
                        progress.update(
                            task_id,
                            completed=latest,
                            total=total,
                            visible=latest < total,
                        )

                # raise any errors:
                for future in futures:
                    future.result()


if __name__ == "__main__":
    main()
