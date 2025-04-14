# tiniii

## Challenge type

Reversing

## Challenge description

```
Help! A cat ate all the functions in this program!
```

## Difficulty level

Easy (but annoying)

## What's going on?

We put each instruction into its own function.
Sometimes we are naughty and wrap multiple functions together.
Just gotta clean up the binary and get the flag!

This challenge is inspired by "Stamp Combinations" in ICPC North American Qualifier 2021.

## Building the challenge

Just run `make` inside `src`.
`gen_incl.py` will generate `selections.bin`, which is the intended answer for getting the flag.
