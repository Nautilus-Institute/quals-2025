#!/usr/bin/env python3

from __future__ import annotations

import hashlib
import time
import random
import string
import sys
import base64

import nclib


class MyRedisClient:
    """
    This class implements a simple (and intentionally vulnerable) Redis client.
    """

    def __init__(self, host='localhost', port=6379, db=0):
        self.host = host
        self.port = port
        self.db = db
        self.data = {}
        self.sock = None

    def connect(self):
        self.sock = nclib.Netcat(self.host, self.port)
        self.sock.settimeout(2)

    def disconnect(self):
        if self.sock is not None:
            self.sock.close()
            self.sock = None

    def ping(self) -> bool:
        if self.sock is None:
            return False
        self.sock.sendall(b"ping\r\n")
        return self.sock.recv(1024) == b"+PONG\r\n"

    def setex(self, key: str, ttl: int, value: str) -> bool:
        if "\r\n" in key or "\x00" in key:
            raise ValueError("Invalid key; it should not contain any newlines or null bytes")
        # VULN: No protection against "\n" in key
        self.sock.sendall(f"SETEX {key} {ttl} {value}\r\n".encode('utf-8'))
        return self.sock.recv(1024) == b"+OK\r\n"
    
    def get(self, key: str) -> str | None:
        if "\r\n" in key or "\x00" in key:
            raise ValueError("Invalid key; it should not contain any newlines or null bytes")
        
        try:
            # VULN: No protection against "\n" in key
            self.sock.sendall(f"GET {key}\r\n".encode('utf-8'))
            # get the "$" sign
            sign = self.sock.recv(1)
            if sign != b"$":
                raise ValueError("Invalid response")
            # get length
            length = int(self.sock.recvuntil(b"\r\n"))
            if length <= 0:
                return None
            return self.sock.recv(length).decode('utf-8').strip("\r\n")
        except Exception:
            # damn something bad has happened; just try again later
            self.disconnect()
            self.connect()
            return None
    
    def set(self, key: str, value: str) -> bool:
        if "\r\n" in key or "\x00" in key:
            raise ValueError("Invalid key; it should not contain any newlines or null bytes")
        # VULN: No protection against "\n" in key
        self.sock.sendall(f"SET {key} {value}\r\n".encode('utf-8'))
        return self.sock.recv(1024) == b"+OK\r\n"


PREFIX = "000000"

# Initialize Redis connection
redis_client = MyRedisClient(host='localhost', port=6379, db=0)


def generate_random_prefix():
    """Generate a random prefix for proof-of-work."""
    return ''.join(random.choices(string.ascii_letters + string.digits, k=8))


def verify_proof_of_work(user_id, prefix, nonce):
    """Verify if the provided nonce satisfies the proof-of-work requirement."""
    data = f"{user_id}:{prefix}:{nonce}".encode('utf-8')
    hash_result = hashlib.sha256(data).hexdigest()
    print(f"[.] SHA256(user_id:prefix:nonce) => {hash_result}")
    return hash_result.startswith(PREFIX)  # Adjust difficulty by changing number of leading zeros


def find_valid_nonce(user_id, prefix):
    """Find a valid nonce that satisfies the proof-of-work requirement."""
    nonce = 0
    while True:
        if verify_proof_of_work(user_id, prefix, nonce):
            return nonce
        nonce += 1


def get_user_id() -> str:
    data = sys.stdin.readline().strip()
    if data.startswith("base64:"):
        try:
            return base64.b64decode(data[6:]).decode('utf-8')
        except Exception:
            return None
    return data


def pow() -> bool:
    time.sleep(0.5)
    print(
        "======================  PET SHOP ANNOUNCEMENT   ======================\n"
        "Due to the recent tariff, our pet shop is experiencing an influx of \n"
        "customers. We had to implement a proof-of-work mechanism to limit \n"
        "the number of requests per user. We are extremely sorry for the \n"
        "inconvenience.\n"
        "======================================================================\n"
    )
    sys.stdout.flush()

    time.sleep(0.5)
    print(
        "======================  PET SHOP ANNOUNCEMENT   ======================\n"
        "Valid proof-of-work solutions will be stored for 300 seconds, so you \n"
        "can come back later to adopt your favorite pet!\n"
        "======================================================================\n"
    )
    sys.stdout.flush()

    time.sleep(0.5)
    print(
        "======================  PET SHOP ANNOUNCEMENT   ======================\n"
        "You can now use emojis (🐱 🐶) in your user name! Please remember to \n"
        "encode your name in Base64 before entering to prevent confusion. In \n"
        "that case, your input should start with 'base64:'. Enjoy!\n"
        "======================================================================\n"
    )
    sys.stdout.flush()

    time.sleep(0.5)

    # Get user ID from stdin
    print("[+] Welcome! Please enter your name: ", end="")
    sys.stdout.flush()
    user_id = get_user_id()

    if not user_id:
        print("[-] Invalid user name.")
        return False
    
    # wait two seconds
    time.sleep(2)

    # Check if user already has an active proof-of-work
    pow_key = f"pet_pow_4e09:{user_id}"
    solution_key = f"pet_solution_xx20:{user_id}"
    prefix = redis_client.get(pow_key)
    if prefix:
        # this is where the format is leaked
        sys.stdout.write(f"[.] Requested {pow_key}.\r")
        print(f"[.] We found an existing proof-of-work challenge for {user_id}.")
        # is there already a valid solution?
        solution = redis_client.get(solution_key)
        if solution:
            print("[.] We also found an existing valid solution. Welcome!")
            print("[+] Please enter the shop!")
            return True
    else:
        # Generate new prefix and store it with 5-minute expiration
        print("[+] Generating a new proof-of-work challenge, specifically for you... Hang on tight!")
        prefix = generate_random_prefix()
        print(f"[.] Storing...")
        redis_client.setex(pow_key, 300, prefix)
    
    print(f"[+] Proof-of-work challenge for user {user_id}:")
    print(f"[+] Prefix: {prefix}")
    print(f"[+] Please find an alphanumeric nonce such that SHA256(user_id:prefix:nonce) starts with '{PREFIX}'")
    
    # Let the user input their nonce
    nonce = input("[+] Enter your nonce: ").strip()
    print("[.] Validating input...")
    if not nonce:
        print("[-] Invalid input. Is your input empty?")
        return False
    # filtering
    if not nonce.isalnum():
        print("[-] Invalid input. Please don't include non-alphanumeric characters in your input.")
        return False
    if "flag" in nonce.lower():
        print("[-] Invalid input. Please don't include 'flag' in your input.")
        return False
    
    # Verify the solution
    print("[.] Verifying POW...")
    if verify_proof_of_work(user_id, prefix, nonce):
        print("[+] Congratulations! Valid proof-of-work solution!")
        # Store the successful solution
        redis_client.setex(solution_key, 300, str(nonce))
        return True

    print("[-] Invalid solution. Try again!")
    return False


def banner():
    print(r"""
                        o                o                               
                       <|>              <|>                              
                       < >              / >                              
 \o_ __o     o__  __o   |         __o__ \o__ __o     o__ __o   \o_ __o   
  |    v\   /v      |>  o__/_    />  \   |     v\   /v     v\   |    v\  
 / \    <\ />      //   |        \o     / \     <\ />       <\ / \    <\ 
 \o/     / \o    o/     |         v\    \o/     o/ \         / \o/     / 
  |     o   v\  /v __o  o          <\    |     <|   o       o   |     o  
 / \ __/>    <\/> __/>  <\__  _\o__</   / \    / \  <\__ __/>  / \ __/>  
 \o/                                                           \o/       
  |                                                             |        
 / \                                                           / \       
""")
    sys.stdout.flush()


def main():
    banner()
    while True:
        redis_client.disconnect()
        redis_client.connect()
        try:
            if pow():
                # TODO: launch the real service
                break
        except EOFError:
            print("[-] Connection closed by the user.")
            break


if __name__ == "__main__":
    main()
