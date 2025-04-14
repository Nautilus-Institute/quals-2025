from __future__ import annotations
import json

from sortedcontainers import SortedDict

import angr


def main():
    proj = angr.Project("./nfuncs.exe", auto_load_libs=False)
    func_addr_to_name = SortedDict()
    for idx in range(0, 1000000, 8):
        try:
            symbol = list(proj.loader.find_all_symbols(f"run_{idx}"))[0]
            func_addr_to_name[symbol.rebased_addr] = f"run_{idx}"
        except Exception as ex:
            break

    section = proj.loader.main_object.find_section_containing(proj.entry)
    assert section.name == ".text"

    # compute sizes of each function
    func_info: dict[str, dict[str, int]] = {}
    for func_addr in sorted(func_addr_to_name.keys()):
        try:
            next_func_addr = next(func_addr_to_name.irange(func_addr + 1))
        except StopIteration:
            next_func_addr = list(proj.loader.find_all_symbols("__do_global_dtors"))[0].rebased_addr
        func_size = next_func_addr - func_addr
        func_info[func_addr_to_name[func_addr]] = {
            "rebased_addr": func_addr, 
            "file_offset": section.addr_to_offset(func_addr),
            "size": func_size
        }

    with open("func_info.json", "w") as f:
        json.dump(func_info, f, indent=2)


if __name__ == "__main__":
    main()
