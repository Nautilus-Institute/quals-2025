# im-pio-ssible

Easy/medium re/misc challenge, sequel to last year's pass-it-on. Players must correctly write PIO-based RX programs for some increasing-in-difficulty TX ones.

Each level consists of 8 random values between 0 and 0xfff being put through the TX-RX combo. Success means reading out the same values.

Three levels were included with the challenge:

- level1 is a basic UART, but with some funky parameters. It is very similar to the baked in TX program from pass-it-on, from DEF CON 2024 quals
- level2 is a subtraction TX. It performs x-y and sends you one of the parameters and the result. It can be (almost) solved by the addition example from the RP2040 docs, but that example requires a small amount of tweaking
- level3 transmits a value over a FIFO but unconditionally masks the bottom 2 bits to 0. However, in doing so, it exposes a side channel. Players must write a program to count cycles between pushes in order to recover the bottom 2 bits

The challenge was distributed as a zip file containing the source (main.swift), a pre-compiled binary (main), and a small collection of swift dynamic libraries. All included binaries were purely for convenience. The challenge was compiled with Swift 6.1, though it doesn't really use any cutting edge Swift features.

The chal requires a zip file with swift dynamic libraries. total size of the download is about 54 mb. GH pipeline produces a .zip.zip, so extract the outer layer before distributing the inner one.
