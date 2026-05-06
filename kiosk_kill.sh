#!/bin/bash
# Ctrl+Alt+Q handler: kill surf cleanly, then open lxterminal so the
# user isn't stranded on a black screen (the kiosk has no desktop/panel).
pkill -x surf 2>/dev/null
sleep 0.2
exec lxterminal -t "SmartCart debug — Ctrl+Alt+S to relaunch, Ctrl+Alt+Q again to kill"
