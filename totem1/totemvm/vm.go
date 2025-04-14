package totemvm

import (
	"encoding/binary"
	"fmt"
	"io"
	"os"
	"strings"
)

type OpCode byte

const (
	OP_NOP     OpCode = iota // No operation
	OP_LOAD                  // Load value from memory
	OP_STORE                 // Store value to memory
	OP_ADD                   // Add two values
	OP_SUB                   // Subtract two values
	OP_MUL                   // Multiply two values
	OP_DIV                   // Divide two values
	OP_JMP                   // Unconditional jump
	OP_JEQ                   // Jump if equal
	OP_JNE                   // Jump if not equal
	OP_JLT                   // Jump if less than
	OP_CALL                  // Call function
	OP_RET                   // Return from function
	OP_HALT                  // Stop execution
	OP_PUSH                  // Push value to stack
	OP_POP                   // Pop value from stack
	OP_MOV                   // Move value between registers
	OP_CMP                   // Compare two registers
	OP_XOR                   // XOR operation
	OP_INC                   // Increment register
	OP_JGE                   // Jump if greater or equal
	OP_SYSCALL               // System call
	OP_LOADI                 // Load immediate value into register
	OP_LOADR                 // Load value from memory address in register
)

// MaxInstructionCount defines the maximum number of instructions
// that can be executed before the VM aborts (to prevent infinite loops)
const MaxInstructionCount = 2000

// Instruction represents a single VM instruction with its operands
type Instruction struct {
	OpCode   OpCode
	Operand1 uint32
	Operand2 uint32
	Operand3 uint32
}

// VirtualMachine represents the RISC-style VM
type VirtualMachine struct {
	Registers [16]uint32    // General purpose registers
	Memory    []byte        // VM memory
	Stack     []uint32      // Call/data stack
	PC        uint32        // Program counter
	Bytecode  []Instruction // Program bytecode
	InstCount uint64        // Count of executed instructions
}

// NewVirtualMachine creates a new VM instance
func NewVirtualMachine(memorySize int) (*VirtualMachine, error) {
	return &VirtualMachine{
		Memory:    make([]byte, memorySize),
		Stack:     make([]uint32, 0, 1024),
		InstCount: 0,
	}, nil
}

// LoadBytecode loads bytecode into the VM
func (vm *VirtualMachine) LoadBytecode(instructions []Instruction) {
	vm.Bytecode = instructions
	vm.PC = 0
	vm.InstCount = 0
}

func loadMemory(vm *VirtualMachine, offset int, values []uint32) {
	for i, v := range values {
		binary.LittleEndian.PutUint32(vm.Memory[offset+i*4:], v)
	}
}

// Run executes the VM until halted
func (vm *VirtualMachine) Run() error {
	for {
		// Infinite loop protection
		vm.InstCount++
		if vm.InstCount > MaxInstructionCount {
			return fmt.Errorf("abrt (%d)", MaxInstructionCount)
		}

		if int(vm.PC) >= len(vm.Bytecode) {
			return fmt.Errorf("ob: %d", vm.PC)
		}

		instr := vm.Bytecode[vm.PC]

		if err := vm.executeInstruction(instr); err != nil {
			return err
		}

		// Check for halt
		if instr.OpCode == OP_HALT {
			break
		}
	}
	return nil
}

// executeInstruction executes a single instruction
func (vm *VirtualMachine) executeInstruction(instr Instruction) error {
	switch instr.OpCode {
	case OP_NOP:
		vm.PC++

	case OP_LOAD:
		reg := instr.Operand1
		addr := instr.Operand2
		vm.Registers[reg] = binary.LittleEndian.Uint32(vm.Memory[addr : addr+4])
		vm.PC++

	case OP_STORE:
		reg := instr.Operand1
		addr := instr.Operand2
		binary.LittleEndian.PutUint32(vm.Memory[addr:addr+4], vm.Registers[reg])
		vm.PC++

	case OP_ADD:
		dst := instr.Operand1
		src1 := instr.Operand2
		src2 := instr.Operand3
		vm.Registers[dst] = vm.Registers[src1] + vm.Registers[src2]
		vm.PC++

	case OP_SUB:
		dst := instr.Operand1
		src1 := instr.Operand2
		src2 := instr.Operand3
		vm.Registers[dst] = vm.Registers[src1] - vm.Registers[src2]
		vm.PC++

	case OP_MUL:
		dst := instr.Operand1
		src1 := instr.Operand2
		src2 := instr.Operand3
		vm.Registers[dst] = vm.Registers[src1] * vm.Registers[src2]
		vm.PC++

	case OP_DIV:
		dst := instr.Operand1
		src1 := instr.Operand2
		src2 := instr.Operand3
		if vm.Registers[src2] == 0 {
			return fmt.Errorf("dz")
		}
		vm.Registers[dst] = vm.Registers[src1] / vm.Registers[src2]
		vm.PC++

	case OP_JMP:
		vm.PC = instr.Operand1

	case OP_JEQ:
		src1 := instr.Operand1
		src2 := instr.Operand2
		target := instr.Operand3
		if vm.Registers[src1] == vm.Registers[src2] {
			vm.PC = target
		} else {
			vm.PC++
		}

	case OP_JNE:
		reg1 := instr.Operand1
		reg2 := instr.Operand2
		target := instr.Operand3
		if vm.Registers[reg1] != vm.Registers[reg2] {
			vm.PC = target
		} else {
			vm.PC++
		}

	case OP_JLT:
		src1 := instr.Operand1
		src2 := instr.Operand2
		target := instr.Operand3
		if vm.Registers[src1] < vm.Registers[src2] {
			vm.PC = target
		} else {
			vm.PC++
		}
	case OP_JGE:
		reg1 := instr.Operand1
		reg2 := instr.Operand2
		target := instr.Operand3

		if vm.Registers[reg1] >= vm.Registers[reg2] {
			vm.PC = target
		} else {
			vm.PC++
		}
	case OP_PUSH:
		reg := instr.Operand1
		vm.Stack = append(vm.Stack, vm.Registers[reg])
		vm.PC++

	case OP_POP:
		reg := instr.Operand1
		if len(vm.Stack) == 0 {
			return fmt.Errorf("stack underflow")
		}
		vm.Registers[reg] = vm.Stack[len(vm.Stack)-1]
		vm.Stack = vm.Stack[:len(vm.Stack)-1]
		vm.PC++

	case OP_CALL:
		target := instr.Operand1
		vm.Stack = append(vm.Stack, vm.PC+1)
		vm.PC = target

	case OP_RET:
		if len(vm.Stack) == 0 {
			return fmt.Errorf("uf")
		}
		returnAddr := vm.Stack[len(vm.Stack)-1]
		vm.Stack = vm.Stack[:len(vm.Stack)-1]
		vm.PC = returnAddr

	case OP_HALT:
		{
		}
	case OP_MOV:
		dst := instr.Operand1
		src := instr.Operand2
		vm.Registers[dst] = vm.Registers[src]
		vm.PC++

	case OP_CMP:
		reg1 := instr.Operand1
		reg2 := instr.Operand2
		// CMP typically sets flags, but since our VM doesn't have flags,
		// we'll store the result in r0 for testing purposes
		if vm.Registers[reg1] == vm.Registers[reg2] {
			vm.Registers[0] = 0 // equal
		} else if vm.Registers[reg1] > vm.Registers[reg2] {
			vm.Registers[0] = 1 // greater than
		} else {
			vm.Registers[0] = 2 // less than
		}
		vm.PC++

	case OP_XOR:
		dst := instr.Operand1
		src1 := instr.Operand2
		src2 := instr.Operand3
		vm.Registers[dst] = vm.Registers[src1] ^ vm.Registers[src2]
		vm.PC++

	case OP_INC:
		reg := instr.Operand1
		vm.Registers[reg]++
		vm.PC++

	case OP_SYSCALL:
		syscallNum := vm.Registers[0]

		switch syscallNum {
		case 1: // SYS_READ_CHAR - Read single character from stdin
			var buf [1]byte
			_, err := os.Stdin.Read(buf[:])
			if err != nil {
				if err == io.EOF {
					vm.Registers[1] = 10 // Treat EOF as newline
				} else {
					return fmt.Errorf("sie: %v", err)
				}
			} else {
				vm.Registers[1] = uint32(buf[0])
			}

		case 2: // SYS_PRINT_STR - Print null-terminated string
			addr := vm.Registers[1]
			var str strings.Builder

			for {
				if int(addr) >= len(vm.Memory) {
					return fmt.Errorf("ob2: %d", addr)
				}

				ch := vm.Memory[addr]
				if ch == 0 {
					break // Null terminator
				}

				str.WriteByte(ch)
				addr++
			}
			fmt.Print(str.String())
		case 3: // SYS_EXIT - Exit program
			{
			}
		default:
			return fmt.Errorf("us: %d", syscallNum)
		}

		vm.PC++

	case OP_LOADI:
		reg := instr.Operand1
		value := instr.Operand2
		vm.Registers[reg] = value
		vm.PC++

	case OP_LOADR:
		dstReg := instr.Operand1
		addrReg := instr.Operand2
		addr := vm.Registers[addrReg]

		// Check memory bounds
		if int(addr+3) >= len(vm.Memory) {
			return fmt.Errorf("ob3: %d", addr)
		}

		// Load the value from memory address in addrReg into dstReg
		vm.Registers[dstReg] = binary.LittleEndian.Uint32(vm.Memory[addr : addr+4])
		vm.PC++

	default:
		return fmt.Errorf("uo: %d", instr.OpCode)
	}

	return nil
}
