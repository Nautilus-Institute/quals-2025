# SevenElBee

Part of the "Erratic Decks" collection.

This web application generates 52 cards from a
<https://en.wikipedia.org/wiki/Linear_congruential_generator>
with fixed parameters.
The cards work like Balatro's
[Erratic Deck](https://balatrogame.fandom.com/wiki/Erratic_Deck):
repeats are allowed and not all cards will be featured.

Given these cards, 
players are expected to determine the next five cards
that will be drawn,
one-by-one.
After the fifth correct pick, players should get the flag.

## Running It

It should run clean with a
`docker compose up -d web`
or 
`docker compose up -d web-prod`
.
It does not need a database.

Once it's up, visit `http://localhost:4002/` .
The ticket I've been using for dev is
`ticket{22weatherdeckweatherdeckweatherdeck143032:fvhGh-7jS1MsxxF4YlB74MPdWSKZl0clNAmCKO8HgkcA6jN9}`
.

## Solver

The solver
(in `./solver/`)
implements the same RNG as `chall_rng.ex`
and the same deck work as `erratic_deck.ex`
.

It should run clean with
`docker compose run --rm solver`,
it's a stdio app.

It supports pasting the cards right from the browser.
If all the cards are doubled 
(I think it's pasting the alt text from the card images?)
it'll un-double them for you.
Make sure the image for the first card is selected!
Type `ZZ` after pasting.

It first does an initial sweep for the seeds based on the first few cards
(see the `initial_sweep` const),
then checks the whole deck pasted in.

Once it's done that, it'll fart out 60 cards, 
including however many you gave it.
Click 'em in the browser to win.

## Deck Images

Deck images from
<https://invent.kde.org/games/libkdegames/-/tree/master/src/carddecks/svg-standard>
, original copyright follows:

Original Pixmaps:
    Copyright (C) 1997 John Fitzgibbon
    Copyright (C) 1997 Jochen Tuchbreiter <whynot@mabi.de>
    Copyright (C) 1998 Markus F.X.J. Oberhumer <markus.oberhumer@jk.uni-linz.ac.at>

Conversion to SVG:
    Copyright (C) 2009 Parker Coates <parker.coates@kdemail.net>

This cardset is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2 of
the License, or (at your option) any later version.



# Original Readme Follows

To start your Phoenix server:

  * Run `mix setup` to install and setup dependencies
  * Start Phoenix endpoint with `mix phx.server` or inside IEx with `iex -S mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

Ready to run in production? Please [check our deployment guides](https://hexdocs.pm/phoenix/deployment.html).

