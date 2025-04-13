# EchoID

This is an audio fingerprinting service like [Shazam](https://www.shazam.com/), but implemented as a CLI in [Crystal](https://crystal-lang.org/).

I loosely followed the concepts in [the original research paper](https://www.ee.columbia.edu/~dpwe/papers/Wang03-shazam.pdf) from 2003 to implement the service.

Players will be given a small number of fingerprints for a song in the database that they must match with in order to get the flag.

The challenge can be built with `build.sh`, which will also run `create_db.sh`, which will require a WAV file named `song.wav`. This has not been provided here, but I used a ~15s sample of [Vikas' Union Dixie Eurobeat Remix](https://www.youtube.com/watch?v=g73sUvX3Kg4) because:

1. Eurobeat has a lot of spectral content
2. It's not on streaming platforms
3. It would be exceptionally hard to guess
4. Everyone needs a reminder that the Confederates lost

