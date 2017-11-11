#!/bin/bash
echo "Setting hostname from /etc/hosts"
[ -f /etc/hostname ] && HOSTNAME="$(/bin/whereami)"
