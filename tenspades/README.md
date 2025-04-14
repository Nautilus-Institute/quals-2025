# tenspades

"10 of Spades" implement an rng that, 
given a seed, 
generates the same sequence as our black box

it's expected to work using gatekeeper

by
[vito@nautilus.institute](mailto:vito@nautilus.institute)

## solving

`docker compose run --rm solver` is interactive

## implementation

- [x] accept team seed from env
- [x] make lcg from team seed
- [x] make challenge seed from random_device
- [x] give challenge seed to players
- [x] shuffle deck
- [x] get sequence from players
- [x] compare sequence to our deck
- [x] give players our sequence, or the flag
- [x] figure out how to even make a solver

## hacking on it

i just hacked on this on macos with the clang++ from xcode,
it's c++23 and no external deps

should build clean in docker

