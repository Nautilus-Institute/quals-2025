#! /usr/bin/env python3

import sys
import glob
import os
import time
import subprocess

def accept_pull_request(path):
    print("Please enter size of bundle file: ", end='')
    sys.stdout.flush()
    val = input()
    size = int(val, 0)

    print(f"Please send your bundle file [{size} bytes]: ", end='')
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
        sys.stdout.flush()

    print(f"Received {len(data)} bytes")
    sys.stdout.flush()

    with open(path, 'wb') as f:
        f.write(data)

def run_cicd(path):
    print(f"Running NI/CI/CD for {path}")
    sys.stdout.flush()
    subprocess.call([
        'elixir',
        '--erl','+Bi',
        '/nicicd/process_git_repo.exs',
        path
    ])

def main():
    # tmp
    path = '/tmp/pull-request.bundle'
    accept_pull_request(path)

    time.sleep(1)

    run_cicd(path)

    status = None
    if os.path.exists('/pr-status/status'):
        with open('/pr-status/status', 'r') as f:
            status = f.read().strip()
    
    if status == 'reject':
        print("Your pull request has been rejected ❌❌")
        sys.exit(1)
    
    print("[MAINTAINER MESSAGE] SORRY At this time, due to spam against our repo, we cannot accept any PRs. The software is good enough!")
    sys.exit(1)
        

if __name__ == "__main__":
    main()

    
    
