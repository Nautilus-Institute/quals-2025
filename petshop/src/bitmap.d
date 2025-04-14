module bitmap;

import std.stdio;

bool parse_bitmap(ubyte[] data, out int width, out int height, out int bits_per_pixel, out ubyte[] pixel_array)
{
    if (data.length <= 54) {
        writefln("[DEBUG] Incorrect bitmap length.");
        return false;
    }
    if (data[0] != 0x42 || data[1] != 0x4D) {
        writefln("[DEBUG] Incorrect bitmap signature.");
        return false;
    }
    // size
    int size = data[2] | data[3] << 8 | data[4] << 16 | data[5] << 24;
    if (size != data.length) {
        writefln("[DEBUG] Incorrect bitmap size.");
        return false;
    }
    if (size <= 0x100) {
        // too small
        writefln("[DEBUG] Bitmap size is too small.");
        return false;
    }

    int pixel_array_offset = data[0x0a] | data[0x0b] << 8 | data[0x0c] << 16 | data[0x0d] << 24;
    if (pixel_array_offset < 54 || pixel_array_offset > size || pixel_array_offset >= data.length) {
        writefln("[DEBUG] Incorrect pixel array offset.");
        return false;
    }

    // header size
    int header_size = data[0xe] | data[0xf] << 8 | data[0x10] << 16 | data[0x11] << 24;
    if (header_size != 40) {
        writefln("[DEBUG] Incorrect header size.");
        return false;
    }
    // width
    width = data[0x12] | data[0x13] << 8 | data[0x14] << 16 | data[0x15] << 24;
    // height
    height = data[0x16] | data[0x17] << 8 | data[0x18] << 16 | data[0x19] << 24;
    // bits per pixel
    bits_per_pixel = data[0x1c] | data[0x1d] << 8;
    // compression
    int compression = data[0x1e] | data[0x1f] << 8 | data[0x20] << 16 | data[0x21] << 24;
    if (compression != 0) {
        // we don't support compressed bitmaps
        writefln("[DEBUG] Unsupported compression type.");
        return false;
    }
    
    // pixel array
    pixel_array = data[pixel_array_offset .. $];
    return true;
}