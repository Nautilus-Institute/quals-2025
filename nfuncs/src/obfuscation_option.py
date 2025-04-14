from __future__ import annotations

import random
from enum import Enum
from typing import Type
from ctypes import c_uint32
import struct
import binascii
from jinja2 import Environment, Template


class ObfuscationScheme(Enum):
    XOR_8B = "xor_8b"
    XOR_16B = "xor_16b"
    TEA = "tea"
    CHACHA20 = "chacha20"


class ObfuscationOption:
    def __init__(self, obf_name: ObfuscationScheme, addr: int, size: int, file_offset: int, key_offset: int = 0):
        self.obf_name = obf_name
        self.addr = addr
        self.size = size
        self.file_offset = file_offset
        self.key_offset = key_offset

    def c_code(self, env: Environment, call_next: str) -> str:
        raise NotImplementedError()

    def encrypt_data(self, data: bytes, func_file_addr: int, func_size: int, key: int) -> bytes:
        chunk = data[func_file_addr:func_file_addr + func_size]
        chunk = self._encrypt_chunk(chunk, key)
        return data[:func_file_addr] + chunk + data[func_file_addr + func_size:]

    def _encrypt_chunk(self, chunk: bytes) -> bytes:
        raise NotImplementedError()


class Xor8B(ObfuscationOption):
    def __init__(self, addr: int, size: int, file_offset: int, key_offset: int = 0):
        super().__init__(ObfuscationScheme.XOR_8B, addr, size, file_offset, key_offset)

    def c_code(self, env: Environment, call_next: str) -> str:
        tmpl: Template = env.get_template("obf_xor8b.c")
        return tmpl.render(
            addr=self.addr,
            size=self.size,
            key_offset=self.key_offset,
            call_next=call_next,
        )

    def _shuffle_key(self, key: int) -> int:
        key = (key << 13) | (key >> (64 - 13))
        key = key & 0xFFFFFFFFFFFFFFFF
        key ^= 0xDEADBEEFCAFEBABE
        key = (key >> 7) | (key << (64 - 7))
        key = key & 0xFFFFFFFFFFFFFFFF
        key ^= 0x123456789ABCDEF0
        key = (key << 5) | (key >> (64 - 5))
        key = key & 0xFFFFFFFFFFFFFFFF
        # print(f"shuffled key: {key:x}")
        return key

    def _encrypt_chunk(self, chunk: bytes, key: int) -> bytes:
        key_bytes = self._shuffle_key(key + self.key_offset).to_bytes(8, "little")
        encrypted = b""
        for i in range(len(chunk)):
            encrypted += bytes([chunk[i] ^ key_bytes[i % 8]])
        return encrypted


class Xor16B(ObfuscationOption):
    def __init__(self, addr: int, size: int, file_offset: int, key_offset: int = 0):
        super().__init__(ObfuscationScheme.XOR_16B, addr, size, file_offset, key_offset)

    def c_code(self, env: Environment, call_next: str) -> str:
        tmpl: Template = env.get_template("obf_xor16b.c")
        return tmpl.render(
            addr=self.addr,
            size=self.size,
            key_offset=self.key_offset,
            call_next=call_next,
        )

    def _shuffle_key(self, key: int) -> bytes:
        # expand key from 8 bytes to 16 bytes using the AES S-box
        key_bytes = [0] * 16
        for i in range(16):
            key_bytes[i] = AES_SBOX[key & 0xff]
            key >>= 4
            key ^= key_bytes[i]
        return bytes(key_bytes)

    def _encrypt_chunk(self, chunk: bytes, key: int) -> bytes:
        key_bytes = self._shuffle_key(key + self.key_offset)
        assert len(key_bytes) == 16
        encrypted = b""
        for i in range(len(chunk)):
            encrypted += bytes([chunk[i] ^ key_bytes[i % 16]])
        return encrypted


class TEA(ObfuscationOption):
    """
    Uses the TEA algorithm to encrypt the data.

    # https://en.wikipedia.org/wiki/Tiny_Encryption_Algorithm
    """
    def __init__(self, addr: int, size: int, file_offset: int, key_offset: int = 0):
        super().__init__(ObfuscationScheme.TEA, addr, size, file_offset, key_offset)

    def c_code(self, env: Environment, call_next: str) -> str:
        tmpl: Template = env.get_template("obf_tea.c")
        return tmpl.render(
            addr=self.addr,
            size=self.size,
            key_offset=self.key_offset,
            call_next=call_next,
        )

    def _encipher(self, v: list[int], k: list[int]) -> list[int]:
        y = c_uint32(v[0])
        z = c_uint32(v[1])
        sum = c_uint32(0)
        delta = 0x9e3779b9
        n = 32
        w = [0,0]

        while(n>0):
            sum.value += delta
            y.value += ( z.value << 4 ) + k[0] ^ z.value + sum.value ^ ( z.value >> 5 ) + k[1]
            z.value += ( y.value << 4 ) + k[2] ^ y.value + sum.value ^ ( y.value >> 5 ) + k[3]
            n -= 1

        w[0] = y.value
        w[1] = z.value
        return w

    def _key_schedule(self, key: int) -> list[int]:
        k = [0, 0, 0, 0]
        k[0] = key & 0xFFFFFFFF
        k[1] = (key >> 32) & 0xFFFFFFFF
        k[2] = ((key >> 3) ^ (key << 7)) & 0xFFFFFFFF
        k[3] = ((key >> 15) ^ (key << 5)) & 0xFFFFFFFF
        return k

    def _encrypt_chunk(self, chunk: bytes, key: int) -> bytes:
        key += self.key_offset
        tail = chunk[len(chunk) // 8 * 8:]
        # print(f"Encrypting {len(chunk)} bytes, tail: {len(tail)}")
        v = [int.from_bytes(chunk[i:i+4], "little") for i in range(0, len(chunk) // 8 * 8, 4)]
        k = self._key_schedule(key)
        encrypted = b""
        for i in range(len(v) // 2):
            w = self._encipher(v[i*2:i*2+2], k)
            encrypted += w[0].to_bytes(4, "little") + w[1].to_bytes(4, "little")
        encrypted += tail
        assert len(encrypted) == len(chunk), f"Encrypted chunk length mismatch: {len(encrypted)} != {len(chunk)}"
        return encrypted


AES_SBOX = (
            0x63, 0x7C, 0x77, 0x7B, 0xF2, 0x6B, 0x6F, 0xC5, 0x30, 0x01, 0x67, 0x2B, 0xFE, 0xD7, 0xAB, 0x76,
            0xCA, 0x82, 0xC9, 0x7D, 0xFA, 0x59, 0x47, 0xF0, 0xAD, 0xD4, 0xA2, 0xAF, 0x9C, 0xA4, 0x72, 0xC0,
            0xB7, 0xFD, 0x93, 0x26, 0x36, 0x3F, 0xF7, 0xCC, 0x34, 0xA5, 0xE5, 0xF1, 0x71, 0xD8, 0x31, 0x15,
            0x04, 0xC7, 0x23, 0xC3, 0x18, 0x96, 0x05, 0x9A, 0x07, 0x12, 0x80, 0xE2, 0xEB, 0x27, 0xB2, 0x75,
            0x09, 0x83, 0x2C, 0x1A, 0x1B, 0x6E, 0x5A, 0xA0, 0x52, 0x3B, 0xD6, 0xB3, 0x29, 0xE3, 0x2F, 0x84,
            0x53, 0xD1, 0x00, 0xED, 0x20, 0xFC, 0xB1, 0x5B, 0x6A, 0xCB, 0xBE, 0x39, 0x4A, 0x4C, 0x58, 0xCF,
            0xD0, 0xEF, 0xAA, 0xFB, 0x43, 0x4D, 0x33, 0x85, 0x45, 0xF9, 0x02, 0x7F, 0x50, 0x3C, 0x9F, 0xA8,
            0x51, 0xA3, 0x40, 0x8F, 0x92, 0x9D, 0x38, 0xF5, 0xBC, 0xB6, 0xDA, 0x21, 0x10, 0xFF, 0xF3, 0xD2,
            0xCD, 0x0C, 0x13, 0xEC, 0x5F, 0x97, 0x44, 0x17, 0xC4, 0xA7, 0x7E, 0x3D, 0x64, 0x5D, 0x19, 0x73,
            0x60, 0x81, 0x4F, 0xDC, 0x22, 0x2A, 0x90, 0x88, 0x46, 0xEE, 0xB8, 0x14, 0xDE, 0x5E, 0x0B, 0xDB,
            0xE0, 0x32, 0x3A, 0x0A, 0x49, 0x06, 0x24, 0x5C, 0xC2, 0xD3, 0xAC, 0x62, 0x91, 0x95, 0xE4, 0x79,
            0xE7, 0xC8, 0x37, 0x6D, 0x8D, 0xD5, 0x4E, 0xA9, 0x6C, 0x56, 0xF4, 0xEA, 0x65, 0x7A, 0xAE, 0x08,
            0xBA, 0x78, 0x25, 0x2E, 0x1C, 0xA6, 0xB4, 0xC6, 0xE8, 0xDD, 0x74, 0x1F, 0x4B, 0xBD, 0x8B, 0x8A,
            0x70, 0x3E, 0xB5, 0x66, 0x48, 0x03, 0xF6, 0x0E, 0x61, 0x35, 0x57, 0xB9, 0x86, 0xC1, 0x1D, 0x9E,
            0xE1, 0xF8, 0x98, 0x11, 0x69, 0xD9, 0x8E, 0x94, 0x9B, 0x1E, 0x87, 0xE9, 0xCE, 0x55, 0x28, 0xDF,
            0x8C, 0xA1, 0x89, 0x0D, 0xBF, 0xE6, 0x42, 0x68, 0x41, 0x99, 0x2D, 0x0F, 0xB0, 0x54, 0xBB, 0x16
            )


class ChaCha20(ObfuscationOption):
    def __init__(self, addr: int, size: int, file_offset: int, key_offset: int = 0):
        super().__init__(ObfuscationScheme.CHACHA20, addr, size, file_offset, key_offset)

    def c_code(self, env: Environment, call_next: str) -> str:
        tmpl: Template = env.get_template("obf_chacha20.c")
        return tmpl.render(
            addr=self.addr,
            size=self.size,
            key_offset=self.key_offset,
            call_next=call_next,
        )

    @staticmethod
    def yield_chacha20_xor_stream(key, iv, position=0):
        """Generate the xor stream with the ChaCha20 cipher."""
        if not isinstance(position, int):
            raise TypeError
        if position & ~0xffffffff:
            raise ValueError('Position is not uint32.')
        if not isinstance(key, bytes):
            raise TypeError
        if not isinstance(iv, bytes):
            raise TypeError
        if len(key) != 32:
            raise ValueError
        if len(iv) != 12:
            raise ValueError

        def rotate(v, c):
            return ((v << c) & 0xffffffff) | v >> (32 - c)

        def quarter_round(x, a, b, c, d):
            x[a] = (x[a] + x[b]) & 0xffffffff
            x[d] = rotate(x[d] ^ x[a], 16)
            x[c] = (x[c] + x[d]) & 0xffffffff
            x[b] = rotate(x[b] ^ x[c], 12)
            x[a] = (x[a] + x[b]) & 0xffffffff
            x[d] = rotate(x[d] ^ x[a], 8)
            x[c] = (x[c] + x[d]) & 0xffffffff
            x[b] = rotate(x[b] ^ x[c], 7)

        ctx = [0] * 16
        ctx[:4] = (1634760805, 857760878, 2036477234, 1797285236)
        ctx[4 : 12] = struct.unpack('<8L', key)
        ctx[12] = position
        ctx[13 : 16] = struct.unpack('<LLL', iv)
        while 1:
            x = list(ctx)
            for i in range(10):
                quarter_round(x, 0, 4,  8, 12)
                quarter_round(x, 1, 5,  9, 13)
                quarter_round(x, 2, 6, 10, 14)
                quarter_round(x, 3, 7, 11, 15)
                quarter_round(x, 0, 5, 10, 15)
                quarter_round(x, 1, 6, 11, 12)
                quarter_round(x, 2, 7,  8, 13)
                quarter_round(x, 3, 4,  9, 14)
            for c in struct.pack('<16L', *((x[i] + ctx[i]) & 0xffffffff for i in range(16))):
                yield c
            ctx[12] = (ctx[12] + 1) & 0xffffffff
            if ctx[12] == 0:
                ctx[13] = (ctx[13] + 1) & 0xffffffff

    @staticmethod
    def chacha20_encrypt(data, key, iv=None, position=0) -> bytes:
        """Encrypt (or decrypt) with the ChaCha20 cipher."""
        if not isinstance(data, bytes):
            raise TypeError
        if iv is None:
            iv = b'\0' * 8
        if isinstance(key, bytes):
            if not key:
                raise ValueError('Key is empty.')
            if len(key) < 32:
                # TODO(pts): Do key derivation with PBKDF2 or something similar.
                key = (key * (32 // len(key) + 1))[:32]
            if len(key) > 32:
                raise ValueError('Key too long.')

        return bytes(a ^ b for a, b in zip(data, ChaCha20.yield_chacha20_xor_stream(key, iv, position)))

    def _key_expansion(self, key: int) -> bytes:
        key_bytes = [0] * 32
        for i in range(32):
            key_bytes[i] = AES_SBOX[key & 0xff]
            key >>= 2
            key ^= 0xc3
        return bytes(key_bytes)

    def _encrypt_chunk(self, chunk: bytes, key: int) -> bytes:
        key_bytes = self._key_expansion(key)
        # print(f"Encrypting {len(chunk)} bytes, key: {binascii.hexlify(key_bytes)}")
        return ChaCha20.chacha20_encrypt(chunk, key_bytes, iv=b'\0' * 12, position=self.key_offset)


NAME_TO_OBFUSCATION_SCHEME = {
    ObfuscationScheme.XOR_8B.value: Xor8B,
    ObfuscationScheme.XOR_16B.value: Xor16B,
    ObfuscationScheme.TEA.value: TEA,
    ObfuscationScheme.CHACHA20.value: ChaCha20,
}

EASY_OBFUSCATION_SCHEMES = [
    Xor8B,
    Xor16B,
]


def get_obfuscation_scheme(obf_name: str) -> Type[ObfuscationOption]:
    return NAME_TO_OBFUSCATION_SCHEME[obf_name]


def get_random_obfuscation_scheme(easy: bool = False) -> Type[ObfuscationOption]:
    if easy:
        return random.choice(EASY_OBFUSCATION_SCHEMES)
    return random.choice(list(NAME_TO_OBFUSCATION_SCHEME.values()))
