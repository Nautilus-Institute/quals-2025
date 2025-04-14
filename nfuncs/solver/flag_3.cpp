#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <vector>
#include <algorithm>

#define MAX_CHUNKS 1000
#define CHUNK_SIZE 1024 * 1024  // 1MB buffer for chunks

typedef struct {
    size_t offset;
    unsigned char* data;
    size_t length;
} PNGChunk;

// Function to find PNG chunks in binary data
int find_png_chunks(const unsigned char* data, size_t data_len, PNGChunk* chunks, int* chunk_count) {
    int found = 0;

    for (size_t i = 0; i < data_len; i++) {
        if (i % 1000 == 0) {
            printf("Scanning %zu of %zu, %.2f%%, %d chunks found\r",
                i, data_len, (float)i / data_len * 100, found);
            fflush(stdout);
        }

        if (i + 12 < data_len) {
            // Check if this is a PNG chunk header
            const unsigned char* chunk_type = &data[i + 4];

            if ((chunk_type[0] == 'I' && chunk_type[1] == 'D' && chunk_type[2] == 'A' && chunk_type[3] == 'T') ||
                (chunk_type[0] == 'P' && chunk_type[1] == 'L' && chunk_type[2] == 'T' && chunk_type[3] == 'E') ||
                (chunk_type[0] == 'I' && chunk_type[1] == 'H' && chunk_type[2] == 'D' && chunk_type[3] == 'R') ||
                (chunk_type[0] == 'I' && chunk_type[1] == 'E' && chunk_type[2] == 'N' && chunk_type[3] == 'D')) {

                // Get chunk length (big-endian)
                uint32_t length = (data[i] << 24) | (data[i + 1] << 16) | (data[i + 2] << 8) | data[i + 3];

                if (length <= 0xfffff && i + length + 12 <= data_len) {
                    // Store chunk information
                    chunks[*chunk_count].offset = i;
                    chunks[*chunk_count].data = (unsigned char*)malloc(length + 12);
                    if (chunks[*chunk_count].data == NULL) {
                        fprintf(stderr, "Memory allocation failed\n");
                        return -1;
                    }
                    memcpy(chunks[*chunk_count].data, &data[i], length + 12);
                    chunks[*chunk_count].length = length + 12;

					printf("Found chunk at offset %zu, length %u <-- \n", i, length + 12);

                    (*chunk_count)++;
                    found++;
                }
            }
        }
    }

    printf("\n");
    return found;
}

int main() {
    FILE* f1, * f2, * out;
    unsigned char* data1, * data2;
    size_t size1, size2;
    PNGChunk chunks[MAX_CHUNKS];
    int chunk_count = 0;

    // Open and read the first file
    f1 = fopen("nfuncs.exe", "rb");
    if (!f1) {
        fprintf(stderr, "Failed to open nfuncs.exe\n");
        return 1;
    }

    fseek(f1, 0, SEEK_END);
    size1 = _ftelli64(f1);
    fseek(f1, 0, SEEK_SET);

	printf("File size: %zu bytes\n", size1);
    data1 = (unsigned char*)malloc(size1);
    if (!data1) {
        fprintf(stderr, "Memory allocation failed\n");
        fclose(f1);
        return 1;
    }

    if (fread(data1, 1, size1, f1) != size1) {
        fprintf(stderr, "Failed to read nfuncs.exe\n");
        free(data1);
        fclose(f1);
        return 1;
    }
    fclose(f1);

    // Open and read the second file
    f2 = fopen("nfuncs_decrypted.exe", "rb");
    if (!f2) {
        fprintf(stderr, "Failed to open nfuncs_decrypted.exe\n");
        free(data1);
        return 1;
    }

    fseek(f2, 0, SEEK_END);
    size2 = _ftelli64(f2);
    fseek(f2, 0, SEEK_SET);

    printf("File size: %zu bytes\n", size2);
    data2 = (unsigned char*)malloc(size2);
    if (!data2) {
        fprintf(stderr, "Memory allocation failed\n");
        free(data1);
        fclose(f2);
        return 1;
    }

    if (fread(data2, 1, size2, f2) != size2) {
        fprintf(stderr, "Failed to read nfuncs_decrypted.exe\n");
        free(data1);
        free(data2);
        fclose(f2);
        return 1;
    }
    fclose(f2);

    // Find PNG chunks in both files
    int chunks1 = find_png_chunks(data1, size1, chunks, &chunk_count);
    int chunks2 = find_png_chunks(data2, size2, chunks, &chunk_count);

    printf("Found %d chunks.\n", chunk_count);

    // Write the PNG file
    out = fopen("what_is_this.png", "wb");
    if (!out) {
        fprintf(stderr, "Failed to create output file\n");
        free(data1);
        free(data2);
        for (int i = 0; i < chunk_count; i++) {
            free(chunks[i].data);
        }
        return 1;
    }

    // Write PNG header
    unsigned char png_header[] = { 0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A };
    fwrite(png_header, 1, 8, out);

	// Sort chunks by offset
	std::sort(chunks, chunks + chunk_count, [](const PNGChunk& a, const PNGChunk& b) {
		return a.offset < b.offset;
		});

    // Write chunks in order of offset
    for (int i = 0; i < chunk_count; i++) {
        fwrite(chunks[i].data, 1, chunks[i].length, out);
    }

    fclose(out);

    // Clean up
    free(data1);
    free(data2);
    for (int i = 0; i < chunk_count; i++) {
        free(chunks[i].data);
    }

    return 0;
}
