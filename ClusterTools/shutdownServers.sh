#!/bin/bash

# where the server list sits
LAN_LIST="hosts.txt"

# Function to check if the server responds to ping
function testServer() {
    if ping -c1 $ip>/dev/null 2>&1; then
	return 0
    else
	return 1
    fi
}

# get a list of IPs for the servers
function getServers() {
    cat $LAN_LIST  | egrep -v '^(#|\s*$)'  | perl -ple 's/\s+/ /g;' | cut -d' ' -f 2
}

# go over all servers
for ip in $(getServers); do
    # check if the server is alive
    if ! testServer $ip; then # if its not then its already down
	echo "Shutting down $ip: already down"
	continue; # to next server
    fi

    # check if I can log in to the server with no password
    if ! ssh -p 24 -o "NumberOfPasswordPrompts 0" root@$ip '/bin/true' >/dev/null 2>&1; then
	# if I can't, try to do a key exchange (this will require an interactive password prompt)
	cat $HOME/.ssh/id_dsa.pub | ssh -p 24 root@$ip 'mkdir -p .ssh; cat >> .ssh/authorized_keys'
	# check if I can now log in to the server with no password
	if ! ssh -p 24 -o "NumberOfPasswordPrompts 0" root@$ip '/bin/true' >/dev/null 2>&1; then
	    # if I still can't then something is broken
	    echo "Failed to complete key exchange with $ip - skipping this server"
	    #continue;
	fi
    fi

    # start to shutdown the server
    echo -n "Shutting down $(ssh root@$ip hostname)"

    # halt the remote server
    ssh root@$ip halt
    count=0
    # wait until its down or 30 seconds have passed
    while testServer $ip; do
	sleep 1; echo -n "."
	count=$(( $count + 1 )) # count up to 30
	if [ "$count" -gt 30 ]; then # if the server did not shutdown in 30 seconds, something is broken
	    echo -n "Server did not shutdown properly!"
	    break;
	fi
    done
    echo ""
    done
