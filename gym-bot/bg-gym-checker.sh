#!/usr/bin/sh
kill $(pidof -x -o $$ $0) # kill previous instances
while :; do
    TMP=$(python dms-spider.py)
    notify-send "$TMP" -t 20000
    sleep 60m;
done
