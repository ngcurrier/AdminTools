#!/bin/bash
echo -n "Enter iDRAC user name: "
read DRACUSER
echo

echo -n "Enter iDRAC user password (password will not be displayed): "
read -s DRACPASS
echo

for IP in 192.168.1.52 192.168.1.54 192.168.1.56
do
    sshpass -p "$DRACPASS" ssh "$DRACUSER"@$IP racadm serveraction powerup
    #sshpass -p "$DRACPASS" ssh "$DRACUSER"@$IP racadm serveraction powerdown
done    
