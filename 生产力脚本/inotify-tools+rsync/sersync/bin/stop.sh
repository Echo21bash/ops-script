#!/bin/bash
ps aux | grep -E 'inotify.sh|sersync.sh|inotifywait' | awk '{print$2}' | xargs kill -9 2>/dev/null
