import os
import struct
import sys
import json
import time

from pwn import *
context.log_level = "DEBUG"

HOST = "localhost"
PORT = 1337

TICKET = "your-ticket-here"

if "REMOTE" in os.environ:
    p = remote(HOST, PORT)
    p.recvuntil("Ticket please: ")
    p.sendline((TICKET).encode("utf-8"))
else:
    p = process("./main")

time.sleep(1)

def pioasm_to_bytes(instructions):
	return [int(y) for y in b"".join([struct.pack("<H", x) for x in instructions])]

def weird_uart_solve():
    # it is basically a 15-n-1 uart
    instructions = [
        0xe72f, #  0: set    x, 15                  [7] 
        0x2081, #  1: wait   1 gpio, 1                  
        0x4001, #  2: in     pins, 1                    
        0x2001, #  3: wait   0 gpio, 1                  
        0x0041, #  4: jmp    x--, 1                     
        0x4070, #  5: in     null, 16                   
        0x8020, #  6: push   block      
    ]

    payload = {
        # for the meaning of these json keys, check main.swift
        "i": pioasm_to_bytes(instructions),

        # in base
        "ib": 0,

        # input shiftdir
        "isd": 1,

        "sh": True,
    }
    return payload

def subtracter_solve():
    instructions = [
        # this is effectively the official raspberry pi addition program. however, the TX is off by 1, so you must fix that
        0x80a0, #  0: pull   block                      
        0xa027, #  1: mov    x, osr                     
        0xa0c1, #  2: mov    isr, x                     
        0x80a0, #  3: pull   block                      
        0xa04f, #  4: mov    y, !osr                    
        0x0007, #  5: jmp    7                          
        0x0087, #  6: jmp    y--, 7                     
        0x0046, #  7: jmp    x--, 6                     
        0x0089, #  8: jmp    y--, 9                     
        0x8020, #  9: push   block                      
        0xa0ca, # 10: mov    isr, !y                    
        0x8020, # 11: push   block                      
        0x208e, # 12: wait   1 gpio, 14                 
        0xe000, # 13: set    pins, 0            
    ]

    payload = {
        "i": pioasm_to_bytes(instructions),

        # in base
        "ib": 0,

        # set base
        "seb": 14,

        "sh": True,
    }
    return payload

def wait_and_mask_solve():
    # use pull noblock to check on the earliest instruction for each possible value of the bottom 2 bits
    # when we get it, we can mask it back into the value.
    instructions = [
    0xac42,# 0: nop                           [12]
    0xa0c3,# 1: mov    isr, null                  
    0xa043,# 2: mov    y, null                    
    0xa023,# 3: mov    x, null                    
    0x8080,# 4: pull   noblock                    
    0xa027,# 5: mov    x, osr                     
    0xe040,# 6: set    y, 0                       
    0x00b6,# 7: jmp    x != y, 22                 
    0xe021,# 8: set    x, 1                       
    0x8080,# 9: pull   noblock                    
    0xa027,#10: mov    x, osr                     
    0xe041,#11: set    y, 1                       
    0x00b6,#12: jmp    x != y, 22                 
    0xe022,#13: set    x, 2                       
    0x8080,#14: pull   noblock                    
    0xa027,#15: mov    x, osr                     
    0xe042,#16: set    y, 2                       
    0x00b6,#17: jmp    x != y, 22                 
    0xe023,#18: set    x, 3                       
    0x80a0,#19: pull   block                      
    0xa027,#20: mov    x, osr                     
    0xe043,#21: set    y, 3                       
    0xa0e1,#22: mov    osr, x                     
    0x6062,#23: out    null, 2                    
    0xa0c7,#24: mov    isr, osr                   
    0x4042,#25: in     y, 2                       
    0x8d20,#26: push   block                  [8] 
    0x0001,#27: jmp    1                          
    ]
    payload = {
        "i": pioasm_to_bytes(instructions),
        "isd": False,
        "ib": 0,
        "osd": True,
        "sb": 0,
        "sh": False,
    }
    return payload

p.recvuntil("level 1")
p.sendline(json.dumps(weird_uart_solve()).encode("utf-8"))
p.recvuntil("level 2")
p.sendline(json.dumps(subtracter_solve()).encode("utf-8"))
p.recvuntil("level 3")
p.sendline(json.dumps(wait_and_mask_solve()).encode("utf-8"))

p.recvall()
