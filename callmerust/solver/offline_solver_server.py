#!/usr/bin/env python

import socket
import hashlib
import sys
import struct

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


host = '0.0.0.0'
port = 5434

try:
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEPORT, 1)
except socket.error:
    print('Failed to create socket')
    sys.exit()
print('[+] Listening for connections on port '+str(port)+'.')
s.bind((host,port))
s.listen(5)




while True:
    conn, address = s.accept()
    print("Connected", conn, address)
    while True:
        try:
            line = recvline(conn)
            if  not hashlib.sha256(line).hexdigest()== "7fc4f2a3b3982ddc047f8234859fd0ef438881761221bc3065ccd4b82f046bf3":
                print("invalid hash")
                break
            line = recvline(conn)
            print("recived line:", line)
            v = int(line.strip())
            with open("/var/tmp/f1","rb") as fd:
                for cv in range(v,v-16,-1):
                    fd.seek(cv*4)
                    ev = struct.unpack("<I",fd.read(4))[0]
                    print(cv,ev)
                    if ev!=0:
                        break
                conn.sendall(str(cv).encode("utf8")+b" "+str(ev).encode("utf8")+b"\n")
                break

        except Exception as e:
            print("Exception", e, repr(e))
            break