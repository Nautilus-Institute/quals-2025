import os
import sys
import math
import random
import json
import struct

def pioasm_to_bytes(instructions):
	return [int(y) for y in b"".join([struct.pack("<H", x) for x in instructions])]

def weird_uart():
	# //         //     .wrap_target
	# // 0x9fa0, //  0: pull   block           side 1 [7] 
	# // 0xf72f, //  1: set    x, 15           side 0 [7] 
	# // 0x7e01, //  2: out    pins, 1         side 1 [6] 
	# // 0x1142, //  3: jmp    x--, 2          side 0 [1] 
	# //         //     .wrap
	payload = {
		"i": [0xa0, 0x9f, 0x2f, 0xf7, 0x01, 0x7e, 0x42, 0x11],
		"gp": 2,
		"gpd": 2,
		"osd": True,
		"pt": 32,
		"at": False,
		"ob": 0,
		"sb": 1,
		"sc": 2,
		"se": True,
		"sh": True, # share pins
	}

	return payload

def subtracter():
	# very straightforward, based on the example from raspberry pi themselves
	instructions = [
	    0x80a0, #  0: pull   block                      
	    0xa027, #  1: mov    x, osr                     
	    0xa0c7, #  2: mov    isr, osr                   
	    0x8000, #  3: push   noblock                    
	    0x80a0, #  4: pull   block                      
	    0xa047, #  5: mov    y, osr                     
	    0x0008, #  6: jmp    8                          
	    0x0048, #  7: jmp    x--, 8                     
	    0x0087, #  8: jmp    y--, 7                 
	    0xa0c9, #  9: mov    isr, !x                    
	    0x8000, # 10: push   noblock
	    0xe001, # 11: set    pins, 1              
	    0x200e, # 12: wait   0 gpio, 14
	]
	payload = {
		"i": pioasm_to_bytes(instructions),
		"ps": 32,
		"seb": 14,
		"sh": True,
	}
	return payload

def wait_and_mask():
	# this is masking off the bottom 3 bits of the output, which are recoverable by counting cycles.
	# players must just mask them back in again
	instructions = [
	    0x80a0, #  0: pull   block                      
	    0x6000, #  1: out    pins, 32                   
	    0x4002, #  2: in     pins, 2                    
	    0xa046, #  3: mov    y, isr                     
	    0x0584, #  4: jmp    y--, 4                 [5] 
	    0xe000, #  5: set    pins, 0                    
	    0x4000, #  6: in     pins, 32                   
	    0xa003, #  7: mov    pins, null                 
	    0x8a20, #  8: push   block                  [8]
	]
	payload = {
	   	"i": pioasm_to_bytes(instructions),
		"isd": False,
		"osd": False,
		"seb": 29, # mask off the bottom 2 pins with set wraparound
	}
	return payload

def gen():

	with open("level1.json", "wb") as f:
	    f.write(json.dumps(weird_uart()).encode("utf-8"))

	with open("level2.json", "wb") as f:
	    f.write(json.dumps(subtracter()).encode("utf-8"))

	with open("level3.json", "wb") as f:
		f.write(json.dumps(wait_and_mask()).encode("utf-8"))

if __name__ == "__main__":
	gen()