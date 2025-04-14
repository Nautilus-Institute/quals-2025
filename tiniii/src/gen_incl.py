import random
import struct
import hashlib


def is_feasible(bad_s, stamp_roll, total, prefix_sums) -> bool:
    if bad_s > total:
        return False
    elif bad_s in prefix_sums:
        return True
    else:
        s = 0
        for i in range(len(stamp_roll) - 1, 0, -1):
            s += stamp_roll[i]
            if s > bad_s:
                return False
            if bad_s - s in prefix_sums:
                return True
    return False


def main():
    flag_str = (
        "flag{stick_t0_0ne_thing_until_y0u_get_there_just_like_a_stamp!!!!!!}"
    )
    md5sum = hashlib.md5(flag_str.encode("utf-8")).hexdigest()
    print(md5sum)

    flag_bytes = flag_str.encode("utf-8").ljust(125, b"\x00")
    flag_bits = "".join(f"{b:08b}" for b in flag_bytes)
    assert len(flag_bits) == 1000

    random.seed(0xdeadb33f)

    # Generate the stamp roll
    roll_size = 800000
    stamp_roll = [random.randint(1, 1000) for _ in range(roll_size)]
    
    prefix_sums = {0}
    total_sum = 0
    for i in stamp_roll:
        total_sum += i
        prefix_sums.add(total_sum)

    # Generate the intended selections
    queries = []
    selections = []
    for i in range(1000):
        print(i)
        query_success = flag_bits[i] == "1"

        if query_success:
            front = random.randint(0, roll_size - 1)
            back = random.randint(0, roll_size - front - 1)
            s = sum(stamp_roll[:front]) + sum(stamp_roll[-back:])
            queries.append(s)
            selections.append((front, back))
        else:
            while True:
                bad_s = random.randint(0, total_sum)
                if not is_feasible(bad_s, stamp_roll, total_sum, prefix_sums):
                    break
            queries.append(bad_s)
            selections.append((0, 0))

    # dump the stamp roll
    with open("stamp_roll.incl", "w") as f:
        for i in range(roll_size):
            f.write(f"stamp_roll[{i}] = {stamp_roll[i]};\n")
        f.write("\n");
    
    # dump the queries
    with open("queries.incl", "w") as f:
        for i in range(1000):
            f.write(f"queries[{i}] = {queries[i]};\n")
        f.write("\n");

    # dump the selections
    with open("selections.bin", "wb") as f:
        for sel in selections:
            f.write(struct.pack("<II", sel[0], sel[1]))


if __name__ == "__main__":
    main()