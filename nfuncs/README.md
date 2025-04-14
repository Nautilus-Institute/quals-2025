# nfuncs

```
No more cutting; only functioning!
```

## Challenge type

Reversing (Flags 1 & 2) + Forensics (Flag 3)

## Difficulty level

Medium / Medium / Easy

## Sup?

This binary is intentionally un-runnable:

- We attach a large resource file with the executable so that its image size is close to 4GB (a hard limit of PE).
- The default stack reserve is too small to allow a full decryption of all the bytes.

This binary does not load in angr by default (issue in CLE; I'll fix after the game).
There are also other bugs in angr that can be triggered when unicorn is in use.

## Build Instructions

### Prerequisites

- MinGW-w64 cross-compiler (`sudo apt-get install mingw-w64` on Ubuntu/Debian)

### Building

Make sure you have enough cores!

```bash
cd flag_video
python make_video.py
mv flag_2.mp4 ../src
```

Ensure `flag_1.png` and `flag_3.png` also exist under `src`.

Make `src/resources/icon.ico` large enough.

```bash
cd src
make
```

The resulting executable will be named `nfuncs.exe`.

### Flags

Flag 1: `flag{kitty_kitty_on_the_wall_439xb8q@}`

Flag 2: `flag{1_000_000_p1eces_2cf8e7f99db1f30aa7f2cf12368b5c0p}`

Flag 3: `flag{dont_you_miss_ncuts_ofKfN9RcOZvpvWzGCaMq}`
