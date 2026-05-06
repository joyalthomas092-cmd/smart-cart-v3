#!/bin/bash
# SmartCart kiosk launcher — wait for server, then surf fullscreen
URL="http://127.0.0.1:8001"

for _ in $(seq 1 60); do
    curl -sf -o /dev/null "$URL/login" && break
    sleep 0.5
done

exec surf -F "$URL"
