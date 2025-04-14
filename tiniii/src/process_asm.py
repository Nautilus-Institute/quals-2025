# Process the assembly code to generate functions that wrap individual instructions

from __future__ import annotations

import re
import sys
from collections import defaultdict
from itertools import chain
import random


def new_tiny_func(func_id: int, lines: list[str], ret_to: str) -> list[str]:
    # if lines[0] == "mov	rbp, rsp":
    #     lines = ["mov rbp, rsp", "add rbp, 128"]
    return [
        f".tiny_{func_id}:",
        "add rsp, 8",
    ] + lines + [
        f"jmp {ret_to}",
    ]


def main():
    random.seed(0xc0debabe)

    with open(sys.argv[1], "r") as f:
        lines = f.readlines()

    header = []
    functions = defaultdict(list)
    extra_functions = defaultdict(list)
    
    is_header = True
    func_name = None
    for line in lines:
        line = line.strip()
        if line == ".text":
            is_header = False
            continue
        if is_header:
            header.append(line)
        else:
            m = re.match(r"^\.globl\s+(.*)", line)
            if m is not None:
                # Start of a new function
                is_header = False
                func_name = m.group(1)
                functions[func_name].append(".text")  # hack
            functions[func_name].append(line)

    tiny_func_id = 0
    j_prefixes = ["je", "jne", "jz", "jnz", "ja", "jb", "jbe", "jae", "jg", "jge", "jl", "jle", "sete"]

    garbage_lines = [
        ["leave", "ret"],
        ["ret"],
        [".byte 0xff", ".byte 0x00"],
        [".byte 0xff", ".byte 0x7f"],
        [".byte 0xcc", ".byte 0xcc"],
        ["xor rax, rax", "pop rax", "jmp rax"],
        ["call $+6"],
    ]


    # let's process each function
    for func_name, lines in list(functions.items()):
        new_lines = []
        func_ended = False
        for line in lines:
            func_ended = line == ".cfi_endproc"
            if func_ended:
                new_lines.append(line)
                continue

            if line.startswith(".") or line.endswith(":") or not line:
                new_lines.append(line)
            elif any(line.startswith(prefix) for prefix in j_prefixes):
                new_lines.append(line)
            elif line in ["push\trbp", "pop\trbp"]:
                new_lines.append(line)
            else:
                ret_to = f".tf_{tiny_func_id}"
                tf = new_tiny_func(tiny_func_id, [line], ret_to)
                extra_functions[f"tiny_{tiny_func_id}"] = tf
                # replace the line with a call to the tiny function
                garbage = random.choice(garbage_lines)
                new_lines += [
                    f"call .tiny_{tiny_func_id}",
                ] + garbage + [
                    f"{ret_to}:",
                ]
                tiny_func_id += 1

        functions[func_name] = new_lines

    # write the header and functions to a new file
    with open(sys.argv[2], "w") as f:
        f.write("\n".join(header))
        f.write("\n")
        for func_name, lines in chain(extra_functions.items(), functions.items()):
            f.write(f"# {func_name}\n")
            f.write("\n".join(lines))
            f.write("\n")


if __name__ == "__main__":
    main()
