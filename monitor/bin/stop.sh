#!/bin/bash
ps aux | grep monitor.sh | grep -v grep | awk '{print$2}' | xargs kill 2>/dev/null
