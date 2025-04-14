#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>

int main(int argc, char** argv) {
    if (argc < 2) {
        puts("Usage: ./secrets access <name>\n");
        exit(1);
    }

    if (strcmp(argv[1], "access") != 0) {
        puts("Usage: ./secrets access <name>\n");
        exit(1);
    }

    if (argc < 3) {
        puts("Usage: ./secrets access <name>\n");
        exit(1);
    }

    if (strcmp(argv[2], "flag2") == 0) {
        FILE* f = fopen("/secrets/flag2", "r");
        if (f == NULL) {
            puts("Secrets Error: Could not open flag2 file\n");
            exit(1);
        }
        while(1) {
            char buf[1024] = {0};
            size_t n = fread(buf, 1, 1024, f);
            fwrite(buf, 1, n, stdout);
            fflush(stdout);
            if (n < 1) {
                break;
            }
        }
    }
}
