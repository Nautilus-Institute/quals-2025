#!/usr/bin/env python3

from PIL import Image
import sys

def png_to_hex(image_path, channel='red'):
    # Open the image
    img = Image.open(image_path)
    
    # Convert to RGBA to ensure we have all channels
    img = img.convert('RGBA')
    
    # Get the specific channel data
    channels = img.split()
    
    channel_index = {
        'red': 0,
        'green': 1,
        'blue': 2,
        'alpha': 3
    }

    out = ''

    # iterate over the pixels in the image
    for y in range(img.height):
        for x in range(img.width):
            # get the pixel data
            pixel = img.getpixel((x, y))
            r = pixel[channel_index['red']]
            print(hex(r), chr(r))
            out += chr(r)

    print(out)



if __name__ == "__main__":
    if len(sys.argv) < 2 or len(sys.argv) > 3:
        print(f"Usage: {sys.argv[0]} <png_file> [channel]")
        print("Channels: red (default), green, blue, alpha")
        sys.exit(1)
    
    image_path = sys.argv[1]
    channel = 'red'  # Default channel
    
    if len(sys.argv) == 3:
        channel = sys.argv[2].lower()
    
    try:
        hex_data = png_to_hex(image_path, channel)
        
        
    except Exception as e:
        print(f"Error: {e}")
        sys.exit(1) 