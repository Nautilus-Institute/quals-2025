#! /usr/bin/env python3

import sys
import glob
import os
import time
import subprocess

def convert_to_png(path):
    print(f"Converting {path} to PNG")
    sys.stdout.flush()
    print(['./djxl', path, './zrt.png'])
    subprocess.call(['./djxl', path, './zrt.png'])
    os.system('ls -la')
    sys.stdout.flush()

def read_jxl(path):
    print("Please enter size of art: ", end='')
    sys.stdout.flush()
    val = input()
    size = int(val, 0)

    print(f"Please send your art [{size} bytes]: ", end='')
    sys.stdout.flush()
    data = b''

    if size <= 0:
        print("Invalid size")
        sys.stdout.flush()
        return

    if size > 0x1000000:
        print("Invalid size")
        sys.stdout.flush()
        return

    while len(data) < size:
        n = size - len(data)
        if n > 0x1:
            n = 0x1
        data += sys.stdin.buffer.read(n)
        #print(f"Received {len(data)} bytes....")
        sys.stdout.flush()

    print(f"Received {len(data)} bytes")
    sys.stdout.flush()

    with open(path, 'wb') as f:
        f.write(data)


def send_png(path):
    with open(path, 'rb') as f:
        data = f.read()
    print(f"Rendered Art Size: {len(data)}")
    sys.stdout.flush()

    sys.stdout.buffer.write(data)
    sys.stdout.flush()

def main():
    # tmp
    path = '/tmp/art.jxl'
    read_jxl(path)


    time.sleep(1)

    convert_to_png(path)

    time.sleep(1)

    matching = list(glob.glob('./*.png'))
    print(f'Matching: {matching}')

    for f in matching:
        send_png(f)
        break

if __name__ == "__main__":
    main()

    
    
