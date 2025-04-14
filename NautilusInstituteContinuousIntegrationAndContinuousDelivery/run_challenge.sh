#!/bin/sh

exec 3<&- 4<&-

exec ./server.py 2>&1