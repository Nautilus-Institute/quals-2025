from __future__ import annotations

from typing import Callable
import random
import struct

# tmpl_0: a simple xor


def t0_args(plain: int):
    key = random.randint(0, 0xFFFF_FFFF_FFFF_FFFF)
    key_lo = key & 0xFFFF_FFFF
    key_hi = (key >> 32) & 0xFFFF_FFFF
    plain_lo = plain & 0xFFFF_FFFF
    plain_hi = (plain >> 32) & 0xFFFF_FFFF

    k0, k1, k2, k3 = key_lo & 0xFF, (key_lo >> 8) & 0xFF, (key_lo >> 16) & 0xFF, (key_lo >> 24) & 0xFF
    k4, k5, k6, k7 = key_hi & 0xFF, (key_hi >> 8) & 0xFF, (key_hi >> 16) & 0xFF, (key_hi >> 24) & 0xFF
    p0, p1, p2, p3 = plain_lo & 0xFF, (plain_lo >> 8) & 0xFF, (plain_lo >> 16) & 0xFF, (plain_lo >> 24) & 0xFF
    p4, p5, p6, p7 = plain_hi & 0xFF, (plain_hi >> 8) & 0xFF, (plain_hi >> 16) & 0xFF, (plain_hi >> 24) & 0xFF
    c0, c1, c2, c3 = k0 ^ p0, k1 ^ p1, k2 ^ p2, k3 ^ p3
    c4, c5, c6, c7 = k4 ^ p4, k5 ^ p5, k6 ^ p6, k7 ^ p7
    return {
        "c0": c0,
        "c1": c1,
        "c2": c2,
        "c3": c3,
        "c4": c4,
        "c5": c5,
        "c6": c6,
        "c7": c7,
        "k0": k0,
        "k1": k1,
        "k2": k2,
        "k3": k3,
        "k4": k4,
        "k5": k5,
        "k6": k6,
        "k7": k7,
    }


# tmpl_1: bit shuffling


def t1_args(plain: int):
    def t1_transform(n: int) -> int:
        mapping: dict[int, int] = {
            0: 5,
            1: 6,
            2: 7,
            3: 4,
            4: 0,
            5: 1,
            6: 3,
            7: 2,
        }
        stream = bin(n)[2:].rjust(8, "0")[::-1]
        new_stream = [None] * 8
        for i in range(8):
            new_stream[mapping[i]] = stream[i]
        new_stream = new_stream[::-1]
        # stream = stream[::-1]
        return int("".join(new_stream), 2)

    plain_lo = plain & 0xFFFF_FFFF
    plain_hi = (plain >> 32) & 0xFFFF_FFFF
    p0, p1, p2, p3 = plain_lo & 0xFF, (plain_lo >> 8) & 0xFF, (plain_lo >> 16) & 0xFF, (plain_lo >> 24) & 0xFF
    p4, p5, p6, p7 = plain_hi & 0xFF, (plain_hi >> 8) & 0xFF, (plain_hi >> 16) & 0xFF, (plain_hi >> 24) & 0xFF
    k0 = t1_transform(p0)
    k1 = t1_transform(p1)
    k2 = t1_transform(p2)
    k3 = t1_transform(p3)
    k4 = t1_transform(p4)
    k5 = t1_transform(p5)
    k6 = t1_transform(p6)
    k7 = t1_transform(p7)
    return {
        "k0": k0,
        "k1": k1,
        "k2": k2,
        "k3": k3,
        "k4": k4,
        "k5": k5,
        "k6": k6,
        "k7": k7,
    }


# tmpl_2: ROT-13


def t2_args(plain: int):
    plain_lo = plain & 0xFFFF_FFFF
    plain_hi = (plain >> 32) & 0xFFFF_FFFF
    p0, p1, p2, p3 = plain_lo & 0xFF, (plain_lo >> 8) & 0xFF, (plain_lo >> 16) & 0xFF, (plain_lo >> 24) & 0xFF
    p4, p5, p6, p7 = plain_hi & 0xFF, (plain_hi >> 8) & 0xFF, (plain_hi >> 16) & 0xFF, (plain_hi >> 24) & 0xFF
    k0 = (p0 + 13) & 0xFF
    k1 = (p1 + 13) & 0xFF
    k2 = (p2 + 13) & 0xFF
    k3 = (p3 + 13) & 0xFF
    k4 = (p4 + 13) & 0xFF
    k5 = (p5 + 13) & 0xFF
    k6 = (p6 + 13) & 0xFF
    k7 = (p7 + 13) & 0xFF
    return {
        "k0": k0,
        "k1": k1,
        "k2": k2,
        "k3": k3,
        "k4": k4,
        "k5": k5,
        "k6": k6,
        "k7": k7,
    }


def t3_args(plain: int):
    # rc4

    def key_scheduling(key):
        sched = [i for i in range(0, 256)]
        i = 0
        for j in range(0, 256):
            i = (i + sched[j] + key[j % len(key)]) % 256
            tmp = sched[j]
            sched[j] = sched[i]
            sched[i] = tmp
        return sched

    def stream_generation(sched):
        i = 0
        j = 0
        while True:
            i = (1 + i) % 256
            j = (sched[i] + j) % 256
            
            tmp = sched[j]
            sched[j] = sched[i]
            sched[i] = tmp
            
            yield sched[(sched[i] + sched[j]) % 256]        

    def encrypt(text, key) -> bytes:      
        sched = key_scheduling(key)
        key_stream = stream_generation(sched)
        ciphertext = b''
        for char in text:
            enc = bytes([char ^ next(key_stream)])
            ciphertext += enc
            
        return ciphertext

    key = random.randint(1, 0xffff_ffff_ffff_ffff)
    key_bytes = struct.pack("<Q", key)
    plain_bytes = struct.pack("<Q", plain)
    encrypted = encrypt(plain_bytes, key_bytes)

    return {
        "key": f"{key}ULL",
        "encrypted": "".join(f"\\x{ch:02x}" for ch in encrypted),
    }


class Template:
    def __init__(self, template_name: str, arg_func: Callable, easy: bool):
        self.template_name = template_name
        self.arg_func = arg_func
        self.easy = easy


TEMPLATES: list[Template] = [
    Template(
        "tmpl_0.c",
        t0_args,
        True,
    ),
    Template(
        "tmpl_1.c",
        t1_args,
        True,
    ),
    Template(
        "tmpl_2.c",
        t2_args,
        True,
    ),
    Template(
        "tmpl_3.c",
        t3_args,
        False,
    )
]
