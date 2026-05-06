#!/bin/bash
# Ctrl+Alt+S handler: kill any existing surf, then relaunch.
# Detaches via setsid so surf survives independent of openbox spawn.
pkill -x surf 2>/dev/null
sleep 0.2
setsid /home/raspberrypi/smart-cart-v3/launch_kiosk.sh \
    >> /tmp/smartcart-kiosk.log 2>&1 < /dev/null &
disown
