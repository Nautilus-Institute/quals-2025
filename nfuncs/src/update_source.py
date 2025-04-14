from __future__ import annotations

import re
import json


def main():
    with open("func_info.json", "r") as f:
        func_info = json.load(f)

    with open("main.c", "r") as f:
        data = f.read()

    # get the function addr and size for run_0
    run_0_size = func_info["run_0"]["size"]
    run_0_addr = func_info["run_0"]["rebased_addr"]

    m = re.search(r"#define RUN_0_ADDR [x0-9a-f]+", data)
    assert m is not None
    data = data.replace(m.group(0), f"#define RUN_0_ADDR {run_0_addr}")

    m = re.search(r"#define RUN_0_SIZE [x0-9a-f]+", data)
    assert m is not None
    data = data.replace(m.group(0), f"#define RUN_0_SIZE {run_0_size}")

    with open("main.c", "w") as f:
        f.write(data)

if __name__ == "__main__":
    main()
