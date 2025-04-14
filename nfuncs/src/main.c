#include <stdio.h>
#include <windows.h>
#include <fcntl.h>
#include <io.h>
#include "resources/resource.h"

#define RUN_0_ADDR 5368714720
#define RUN_0_SIZE 56016

void run_0();

static void shuffle_key(unsigned long long *key)
{
    // Rotate left by 13 bits
    *key = (*key << 13) | (*key >> (64 - 13));
    
    // XOR with a constant value
    *key ^= 0xDEADBEEFCAFEBABEULL;
    
    // Rotate right by 7 bits
    *key = (*key >> 7) | (*key << (64 - 7));
    
    // XOR with another constant value
    *key ^= 0x123456789ABCDEF0ULL;
    
    // Rotate left by 5 bits
    *key = (*key << 5) | (*key >> (64 - 5));
}

void decrypt_0()
{
    // get the address and size of run_0
    unsigned long long run_0_addr = RUN_0_ADDR;
    unsigned long long run_0_size = RUN_0_SIZE;

    // get the old protection
    DWORD old_prot;
    VirtualProtect((void*)run_0_addr, run_0_size, PAGE_EXECUTE_READWRITE, &old_prot);

    // decrypt the code
    // 0x220c15c8ddfefaf0
    unsigned char key_buf[8] = {0xf0, 0xfa, 0xfe, 0xdd, 0xc8, 0x15, 0xc, 0x22};
    shuffle_key((unsigned long long*)&key_buf);
    for (int i = 0; i < run_0_size; i++) {
        *((char *)run_0_addr + i) = *((char *)run_0_addr + i) ^ key_buf[i % 8];
    }

    // remap the memory again to enable execution
    VirtualProtect((void*)run_0_addr, run_0_size, old_prot, NULL);

    // run the code
    run_0();
}

int main() {
    // Load and set the application icon
    HICON hIcon = LoadIcon(GetModuleHandle(NULL), MAKEINTRESOURCE(IDI_ICON1));
    if (hIcon) {
        SendMessage(GetConsoleWindow(), WM_SETICON, ICON_BIG, (LPARAM)hIcon);
    }

    // switch to binary mode
    _setmode(_fileno(stdin), _O_BINARY);
    
    decrypt_0();
    return 0;
}
