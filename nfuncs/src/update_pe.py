from __future__ import annotations

import json
import os
import binascii
import argparse
import multiprocessing as mp
from concurrent.futures import ProcessPoolExecutor

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

from obfuscation_option import get_obfuscation_scheme


def get_file_chunk(file_path: str, offset: int, size: int) -> bytes:
    with open(file_path, "rb") as f:
        f.seek(offset)
        return f.read(size)


def process_chunks(
    worker_id: int,
    all_workers: int,
    task_id: int,
    progress,
) -> list[bytes]:
    with open("func_obf_options.json", "r") as f:
        func_obf_options = json.load(f)

    with open("png_hidden_config.json", "r") as f:
        png_hidden_config = json.load(f)

    offset_to_config = {}
    for conf in png_hidden_config:
        offset = conf["int_idx"] * 8
        offset_to_config[offset] = conf

    file_size = os.path.getsize("nfuncs.exe")
    # with open("nfuncs.exe", "rb") as f:
    #     data = f.read()
    # assert len(data) == file_size

    processed_chunks = []

    total_jobs = len(func_obf_options)
    jobs_per_worker = total_jobs // (all_workers - 1) if all_workers > 1 else total_jobs
    start_job = worker_id * jobs_per_worker
    end_job = (worker_id + 1) * jobs_per_worker
    if end_job > total_jobs:
        end_job = total_jobs

    all_jobs = sorted(func_obf_options.items(), key=lambda x: x[1]["addr"])
    last_pos = all_jobs[start_job][1]["file_offset"] if start_job > 0 else 0
    for idx, (func_name, info) in enumerate(all_jobs[start_job : end_job]):
        # print(f"[.] Encrypting {func_name} at {info['addr']:#x}: {info["obf_name"]}")
        assert func_name.startswith("run_")
        offset = int(func_name[4:])

        func_file_addr = info["file_offset"]
        func_size = info["size"]
        obf_scheme = get_obfuscation_scheme(info["obf_name"])(info["addr"], info["size"], info["file_offset"], key_offset=info["key_offset"])
        if last_pos < func_file_addr:
            file_chunk = get_file_chunk("nfuncs.exe", last_pos, func_file_addr - last_pos)
            # assert file_chunk == data[last_pos : func_file_addr]
            processed_chunks.append(file_chunk)
        last_pos = func_file_addr
        original_chunk = get_file_chunk("nfuncs.exe", func_file_addr, func_size)
        encrypted_chunk = obf_scheme._encrypt_chunk(original_chunk, info["key"])

        if offset in offset_to_config and offset_to_config[offset]["store_before_encryption"] == 0:
            # print("[.] Apply post-encryption data store.")
            # we assume there is enough space at the end of the encrypted chunk
            chunk = binascii.unhexlify(offset_to_config[offset]["chunk"])
            assert func_size > len(chunk) + 10000
            assert len(encrypted_chunk) > len(chunk) + 10000
            encrypted_chunk = encrypted_chunk[:-len(chunk) - 10000] + chunk + encrypted_chunk[-10000:]

        last_pos += len(encrypted_chunk)
        processed_chunks.append(encrypted_chunk)

        progress[task_id] = {"progress": idx + 1, "total": end_job - start_job}

    if end_job < total_jobs:
        next_job = all_jobs[end_job]
        next_job_file_offset = next_job[1]["file_offset"]
        if last_pos < next_job_file_offset:
            processed_chunks.append(get_file_chunk("nfuncs.exe", last_pos, next_job_file_offset - last_pos))
    else:
        if last_pos < file_size:
            processed_chunks.append(get_file_chunk("nfuncs.exe", last_pos, file_size - last_pos))

    return processed_chunks


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--workers", type=int, required=True)
    args = parser.parse_args()
    nworkers = args.workers

    progress = Progress(
        TextColumn("[progress.description]{task.description}"),
        BarColumn(),
        TaskProgressColumn(),
        MofNCompleteColumn(),
        TimeElapsedColumn(),
        TimeRemainingColumn(),
        expand=True,
    )

    processed_chunks = []

    with progress:
        futures = []  # keep track of the jobs
        with mp.Manager() as manager:
            # this is the key - we share some state between our
            # main process and our worker functions
            _progress = manager.dict()
            overall_progress_task = progress.add_task("[green]All jobs progress:")

            with ProcessPoolExecutor(max_workers=nworkers) as executor:
                for n in range(0, nworkers):  # iterate over the jobs we need to run
                    # set visible false so we don't have a lot of bars all at once:
                    task_id = progress.add_task(f"task {n}", visible=False)
                    futures.append(
                        executor.submit(
                            process_chunks,
                            n,
                            nworkers,
                            task_id,
                            _progress,
                        )
                    )

                while (n_finished := sum([future.done() for future in futures])) < len(futures):
                    progress.update(overall_progress_task, completed=n_finished, total=len(futures))
                    for task_id, update_data in _progress.items():
                        latest = update_data["progress"]
                        total = update_data["total"]
                        # update the progress bar for this task:
                        progress.update(task_id, completed=latest, total=total, visible=latest < total)

                for future in futures:
                    chunks = future.result()
                    processed_chunks.extend(chunks)

    data = b"".join(processed_chunks)
    with open("nfuncs.exe", "wb") as f:
        f.write(data)


if __name__ == "__main__":
    main()
