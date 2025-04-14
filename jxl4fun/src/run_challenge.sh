#!/bin/sh

# close any extra FDs from xinetd
exec 3<&- 4<&-

exec ./server.py 2>&1