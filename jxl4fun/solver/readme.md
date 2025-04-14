# Flag 1

The first flag is automatically loaded into a "seed buffer" on the heap which is immediately freed

Then after that a new pixel buffer is allocated and the intention is for it to be filled with prandom data

However there is a logic bug such that when the image is wider than tall, it will no actually initialize this buffer

This means that the initial pixel buffer used to render the jxl has uninitialized data

To actually get the flag into that uninitialized data, we need to make sure the pixel buffer is the same size as the seed buffer.

An image of 48x13 will match the correct allocation size. At this point the flag (along with several other useful pointers) will be in the pixel buffer.

To actually get that data back, we need to abuse one of the new opcodes, specifically the "E" or east opcode (normally jxl has north and west opcodes). This east opcode will copy the pixel value of the next pixel (which is uninitialized), leading to the flag being dumped as pixel values in the rendered png image


# Flag 2

TO get flag 2 we actually have to exploit this binary to get a shell.

The second vulnerability is in a new `pallet` predictor opcode. The intention of this opcode is to allow the predictors to "associate" a North and East value, and pull it out of the pallet at a later time. (pallet[north] = east)

However the pallet assumes the north pixel is 0 - 255 (8 bit color).

In reality JXLs pixel values are 64 bit integers (although most ops truncate to 32 or fewer bits).

We can get an OOB read/write using this opcode.

Now the hard part is calculating the correct offsets for our write-what-where.

This is done by utilizing the uninitialized memory in the first step. We can chain
predictors together to modify and manipulate the pixel values.
In particular we want to substract the `.text` section leak from the heap leak, plus/minus some static offsets based on the heap layout / binary / libc

Once we have chained these operations together we will be able to write over the @got (due to default settings on the library and clang)

The intended exploit overwrites `bzero@got` with `system` and writes the shell payload to the original seed buffer (which is what is getting bzero'd here)

My final rendered image looks something like this:

![final exploit image enlarged to show texture](../exp_screenshot.png)

