# holographic

harder tenspades

it's expected to work using gatekeeper

by
[vito@nautilus.institute](mailto:vito@nautilus.institute)

## deployment needs

It expects the flag in the first one of:

* `FLAG` env
* file, either `FLAG_FILE` env or `/flag`
* the hardcoded "no flag configured! contact orga"

It basically needs a seed from gatekeeper in `SEED` env.
Otherwise it's very easy because it defaults to 1337.
This version complains though.

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
- [ ] different rng?
- [ ] smaller deck, more shufflin'

## hacking on it

i just hacked on this on macos with the clang++ from xcode,
it's c++23 and no external deps

should build clean in docker

