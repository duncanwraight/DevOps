#!/bin/bash

TXT_RED='\033[0;31m'
NC='\033[0m'

timeNow=$(date)
ip=$(ifconfig eth0 | grep "inet addr" | cut -d ':' -f 2 | cut -d ' ' -f 1)

echo
echo "===================================================="
echo -e "[IP: ${TXT_RED}${ip}${NC}]  [Date: ${TXT_RED}${timeNow}${NC}]"
echo "===================================================="