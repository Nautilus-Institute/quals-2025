package main

import (
	"encoding/binary"
	"fmt"
	"os"
	o "totem1/totemvm"
)

func main() {
	vm, err := o.NewVirtualMachine(8192)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Failed to create VM: %v\n", err)
		os.Exit(1)
	}

	initializeVMMemory(vm)
	instructions := createFlagCheckerBytecode()
	vm.LoadBytecode(instructions)

	// Run the VM
	if err := vm.Run(); err != nil {
		fmt.Fprintf(os.Stderr, "VM execution error: %v\n", err)
		os.Exit(1)
	}
}

func createFlagCheckerBytecode() []o.Instruction {
	const (
		SYS_READ_CHAR = 1
		SYS_PRINT_STR = 2
		SYS_EXIT      = 3
	)

	// Memory locations
	const (
		MEM_WELCOME_MSG  = 100 // "Enter the flag: "
		MEM_CORRECT_MSG  = 200 // "Correct! You found the flag!\n"
		MEM_WRONG_MSG    = 300 // "Sorry, that's not right.\n"
		MEM_SUCCESS_FLAG = 400 // Flag to track if all chars were correct
	)

	type Inst = o.Instruction

	instructions := make([]o.Instruction, 400)
	for i := range instructions {
		instructions[i] = Inst{OpCode: o.OP_NOP}
	}

	instructions[0] = Inst{OpCode: o.OP_LOAD, Operand1: 5, Operand2: MEM_SUCCESS_FLAG}

	instructions[1] = Inst{OpCode: o.OP_LOADI, Operand1: 0, Operand2: SYS_PRINT_STR}
	instructions[2] = Inst{OpCode: o.OP_LOADI, Operand1: 1, Operand2: MEM_WELCOME_MSG}
	instructions[3] = Inst{OpCode: o.OP_SYSCALL}

	instructions[4] = Inst{OpCode: o.OP_LOADI, Operand1: 3, Operand2: 0}  // r3=i(0)
	instructions[5] = Inst{OpCode: o.OP_LOADI, Operand1: 4, Operand2: 29} // r4=29 (length of flag)

	instructions[6] = Inst{OpCode: o.OP_LOADI, Operand1: 0, Operand2: SYS_READ_CHAR}
	instructions[7] = Inst{OpCode: o.OP_SYSCALL} // r1=read(1)

	instructions[8] = Inst{OpCode: o.OP_LOADI, Operand1: 6, Operand2: 10}              // r6=='\n'
	instructions[10] = Inst{OpCode: o.OP_JEQ, Operand1: 1, Operand2: 6, Operand3: 100} // if r1=='\n' jump to results check
	instructions[13] = Inst{OpCode: o.OP_LOADI, Operand1: 7, Operand2: 0}

	instructions[14] = Inst{OpCode: o.OP_MOV, Operand1: 6, Operand2: 3} // r1=input char r6=i
	instructions[15] = Inst{OpCode: o.OP_CALL, Operand1: 200}           // func to check each char

	// If not equal, set success flag to 0 (false)
	instructions[17] = Inst{OpCode: o.OP_JEQ, Operand1: 7, Operand2: 2, Operand3: 20} // if r2 == r7(0) char is correct
	instructions[18] = Inst{OpCode: o.OP_LOADI, Operand1: 5, Operand2: 0}             // Set success flag to 0
	instructions[19] = Inst{OpCode: o.OP_STORE, Operand1: 5, Operand2: 400}           // Store to memory

	instructions[20] = Inst{OpCode: o.OP_LOADI, Operand1: 0, Operand2: 1}            // r0=1
	instructions[21] = Inst{OpCode: o.OP_ADD, Operand1: 3, Operand2: 3, Operand3: 0} // r3=i+1

	// Check if we've processed all expected characters
	instructions[23] = Inst{OpCode: o.OP_JLT, Operand1: 3, Operand2: 4, Operand3: 6} // if i < 29, jump to read next char

	instructions[25] = Inst{OpCode: o.OP_JEQ, Operand1: 3, Operand2: 4, Operand3: 100} // Jump to result check if lengths match
	instructions[26] = Inst{OpCode: o.OP_LOADI, Operand1: 5, Operand2: 0}              // Set success flag to 0 if lengths don't match
	instructions[27] = Inst{OpCode: o.OP_STORE, Operand1: 5, Operand2: 400}            // Store to memory
	instructions[28] = Inst{OpCode: o.OP_JMP, Operand1: 100}                           // Jump to result check

	// Instruction 100: Check success flag
	instructions[100] = Inst{OpCode: o.OP_LOAD, Operand1: 5, Operand2: 400} // Load success flag from memory
	instructions[101] = Inst{OpCode: o.OP_LOADI, Operand1: 7, Operand2: 1}

	instructions[103] = Inst{OpCode: o.OP_JEQ, Operand1: 5, Operand2: 7, Operand3: 110} // Jump to success if flag is 1

	instructions[104] = Inst{OpCode: o.OP_LOADI, Operand1: 0, Operand2: SYS_PRINT_STR}
	instructions[105] = Inst{OpCode: o.OP_LOADI, Operand1: 1, Operand2: MEM_WRONG_MSG}
	instructions[106] = Inst{OpCode: o.OP_SYSCALL}
	instructions[107] = Inst{OpCode: o.OP_JMP, Operand1: 120}

	instructions[110] = Inst{OpCode: o.OP_LOADI, Operand1: 0, Operand2: SYS_PRINT_STR}
	instructions[111] = Inst{OpCode: o.OP_LOADI, Operand1: 1, Operand2: MEM_CORRECT_MSG}
	instructions[112] = Inst{OpCode: o.OP_SYSCALL}

	instructions[120] = Inst{OpCode: o.OP_LOADI, Operand1: 0, Operand2: SYS_EXIT}
	instructions[121] = Inst{OpCode: o.OP_SYSCALL}
	instructions[122] = Inst{OpCode: o.OP_HALT}

	// First section stub
	instructions[200] = Inst{OpCode: o.OP_LOADI, Operand1: 7, Operand2: 5}              //r7=5 (length of flag{)
	instructions[202] = Inst{OpCode: o.OP_JLT, Operand1: 6, Operand2: 7, Operand3: 220} // if r6(i) < r7(length of flag{) })

	//second section
	instructions[203] = Inst{OpCode: o.OP_LOADI, Operand1: 7, Operand2: 15} // Check 'd0nt_Th1nk'
	instructions[205] = Inst{OpCode: o.OP_JLT, Operand1: 6, Operand2: 7, Operand3: 240}

	//third section
	instructions[209] = Inst{OpCode: o.OP_JMP, Operand1: 260}

	// first section (positions 0-4)
	instructions[220] = Inst{OpCode: o.OP_MOV, Operand1: 7, Operand2: 6} // r7=r6

	instructions[221] = Inst{OpCode: o.OP_LOADI, Operand1: 2, Operand2: 17}           // r2=17
	instructions[222] = Inst{OpCode: o.OP_MUL, Operand1: 2, Operand2: 2, Operand3: 7} // r2=r2*i
	instructions[223] = Inst{OpCode: o.OP_LOADI, Operand1: 0, Operand2: 23}           // r0=23
	instructions[224] = Inst{OpCode: o.OP_XOR, Operand1: 2, Operand2: 2, Operand3: 0} // r2=r2^23

	instructions[225] = Inst{OpCode: o.OP_LOADI, Operand1: 0, Operand2: 500}          // r0=500
	instructions[226] = Inst{OpCode: o.OP_LOADI, Operand1: 5, Operand2: 4}            // r5=4
	instructions[228] = Inst{OpCode: o.OP_MUL, Operand1: 5, Operand2: 6, Operand3: 5} // r5=r6(i)*r5(4)
	instructions[229] = Inst{OpCode: o.OP_ADD, Operand1: 0, Operand2: 0, Operand3: 5} // r0=r0+i*4

	instructions[230] = Inst{OpCode: o.OP_LOADR, Operand1: 0, Operand2: 0} // r0=mem[500+i*4]
	instructions[231] = Inst{OpCode: o.OP_XOR, Operand1: 2, Operand2: 1, Operand3: 2}
	instructions[232] = Inst{OpCode: o.OP_SUB, Operand1: 2, Operand2: 2, Operand3: 0}
	instructions[233] = Inst{OpCode: o.OP_ADD, Operand1: 2, Operand2: 2, Operand3: 6}

	instructions[234] = Inst{OpCode: o.OP_RET}

	// second section (positions 5-14)
	instructions[240] = Inst{OpCode: o.OP_MOV, Operand1: 7, Operand2: 6}   // r7=r6(i)
	instructions[241] = Inst{OpCode: o.OP_LOADI, Operand1: 0, Operand2: 5} // r0=5

	instructions[243] = Inst{OpCode: o.OP_LOADI, Operand1: 0, Operand2: 13}
	instructions[244] = Inst{OpCode: o.OP_MUL, Operand1: 2, Operand2: 7, Operand3: 0}
	instructions[245] = Inst{OpCode: o.OP_LOADI, Operand1: 0, Operand2: 41}
	instructions[246] = Inst{OpCode: o.OP_ADD, Operand1: 2, Operand2: 2, Operand3: 0} // constant in r2

	instructions[247] = Inst{OpCode: o.OP_LOADI, Operand1: 0, Operand2: 550}          // r0=550
	instructions[248] = Inst{OpCode: o.OP_LOADI, Operand1: 5, Operand2: 4}            // r5=4
	instructions[249] = Inst{OpCode: o.OP_MUL, Operand1: 5, Operand2: 6, Operand3: 5} // r5=r6(i)*r5(4)
	instructions[250] = Inst{OpCode: o.OP_ADD, Operand1: 0, Operand2: 0, Operand3: 5} // r0=r0+i*4

	instructions[251] = Inst{OpCode: o.OP_LOADR, Operand1: 13, Operand2: 0} // r13=mem[500+i*4]
	instructions[252] = Inst{OpCode: o.OP_XOR, Operand1: 2, Operand2: 1, Operand3: 2}
	instructions[253] = Inst{OpCode: o.OP_SUB, Operand1: 2, Operand2: 13, Operand3: 2}
	instructions[254] = Inst{OpCode: o.OP_ADD, Operand1: 2, Operand2: 2, Operand3: 6}
	instructions[255] = Inst{OpCode: o.OP_RET}

	// third section 15 onwards
	instructions[260] = Inst{OpCode: o.OP_MOV, Operand1: 7, Operand2: 6} // r7=r6(i)
	instructions[261] = Inst{OpCode: o.OP_LOADI, Operand1: 0, Operand2: 15}

	instructions[263] = Inst{OpCode: o.OP_LOADI, Operand1: 0, Operand2: 29}
	instructions[264] = Inst{OpCode: o.OP_MUL, Operand1: 2, Operand2: 7, Operand3: 0}
	instructions[265] = Inst{OpCode: o.OP_LOADI, Operand1: 0, Operand2: 19}
	instructions[266] = Inst{OpCode: o.OP_XOR, Operand1: 2, Operand2: 2, Operand3: 0}

	instructions[267] = Inst{OpCode: o.OP_LOADI, Operand1: 0, Operand2: 700}          // r0=700
	instructions[268] = Inst{OpCode: o.OP_LOADI, Operand1: 5, Operand2: 4}            // r5=4
	instructions[269] = Inst{OpCode: o.OP_MUL, Operand1: 5, Operand2: 6, Operand3: 5} // r5=r6(i)*r5(4)
	instructions[270] = Inst{OpCode: o.OP_ADD, Operand1: 0, Operand2: 0, Operand3: 5} // r0=r0+i*4

	instructions[271] = Inst{OpCode: o.OP_LOADR, Operand1: 14, Operand2: 0} // r13=mem[700+i*4]
	instructions[272] = Inst{OpCode: o.OP_XOR, Operand1: 2, Operand2: 1, Operand3: 2}
	instructions[273] = Inst{OpCode: o.OP_SUB, Operand1: 2, Operand2: 14, Operand3: 2}
	instructions[274] = Inst{OpCode: o.OP_ADD, Operand1: 2, Operand2: 2, Operand3: 6}
	instructions[275] = Inst{OpCode: o.OP_RET}

	// dead code
	instructions[280] = Inst{OpCode: o.OP_MOV, Operand1: 7, Operand2: 6}
	instructions[281] = Inst{OpCode: o.OP_LOADI, Operand1: 0, Operand2: 21}
	instructions[282] = Inst{OpCode: o.OP_SUB, Operand1: 7, Operand2: 7, Operand3: 0}

	instructions[283] = Inst{OpCode: o.OP_LOADI, Operand1: 0, Operand2: 37}
	instructions[284] = Inst{OpCode: o.OP_MUL, Operand1: 2, Operand2: 7, Operand3: 0}
	instructions[285] = Inst{OpCode: o.OP_LOADI, Operand1: 0, Operand2: 47}
	instructions[286] = Inst{OpCode: o.OP_XOR, Operand1: 2, Operand2: 2, Operand3: 0}
	instructions[287] = Inst{OpCode: o.OP_LOADI, Operand1: 0, Operand2: 53}
	instructions[288] = Inst{OpCode: o.OP_ADD, Operand1: 2, Operand2: 2, Operand3: 0}

	instructions[289] = Inst{OpCode: o.OP_LOADI, Operand1: 0, Operand2: 650}
	instructions[290] = Inst{OpCode: o.OP_ADD, Operand1: 0, Operand2: 0, Operand3: 7}
	instructions[291] = Inst{OpCode: o.OP_LOAD, Operand1: 0, Operand2: 0}
	instructions[292] = Inst{OpCode: o.OP_XOR, Operand1: 2, Operand2: 2, Operand3: 0}

	instructions[293] = Inst{OpCode: o.OP_RET}

	return instructions
}

// Initialize the VM's memory directly
func initializeVMMemory(vm *o.VirtualMachine) {
	// Welcome message at MEM_WELCOME_MSG (100)
	welcomeMsg := []byte("Enter the flag: ")
	for i, b := range welcomeMsg {
		vm.Memory[100+i] = b
	}
	vm.Memory[100+len(welcomeMsg)] = 0

	// Success message at MEM_CORRECT_MSG (200)
	correctMsg := []byte("Correct! You found the flag!\n")
	for i, b := range correctMsg {
		vm.Memory[200+i] = b
	}
	vm.Memory[200+len(correctMsg)] = 0

	// Failure message at MEM_WRONG_MSG (300)
	wrongMsg := []byte("Sorry, that's not right.\n")
	for i, b := range wrongMsg {
		vm.Memory[300+i] = b
	}
	vm.Memory[300+len(wrongMsg)] = 0

	// Initialize success flag at MEM_SUCCESS_FLAG (400)
	binary.LittleEndian.PutUint32(vm.Memory[400:404], 1)

	// First section correction values for 'flag{' (positions 0-4)
	correctionValues1 := []uint32{113, 106, 84, 67, 40}
	for i, val := range correctionValues1 {
		binary.LittleEndian.PutUint32(vm.Memory[500+i*4:504+i*4], val)
	}

	// Second section for 'd0nt_Th1nk' (positions 5-14)
	correctionValues2 := []uint32{153, 89, 177, 171, 138, 14, 71, 234, 229, 193, 255, 208, 244, 188, 180}
	for i, val := range correctionValues2 {
		binary.LittleEndian.PutUint32(vm.Memory[550+i*4:554+i*4], val)
	}

	// Third section for rest
	correctionValues3 := []uint32{397, 499, 408, 564, 519, 571, 577, 541, 736, 671, 680, 661, 870, 834}
	for i, val := range correctionValues3 {
		binary.LittleEndian.PutUint32(vm.Memory[760+i*4:764+i*4], val)
	}

	// dead code
	correctionValues4 := []uint32{64, 97, 155, 64, 114, 73}

	for i, val := range correctionValues4 {
		binary.LittleEndian.PutUint32(vm.Memory[900+i*4:904+i*4], val)
	}
}
