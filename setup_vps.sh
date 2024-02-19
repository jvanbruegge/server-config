#!/usr/bin/env bash

set -euo pipefail

if [ -z "$SERVER_ADDRESS" ]; then
    echo "You must define SERVER_ADDRESS e.g. with export SERVER_ADDRESS=192.168.56.10" >&2
    exit 1
fi

export SSH_COMMAND="ssh -p $SERVER_PORT root@$SERVER_ADDRESS"

echo "Trying to connect to server"
if ! $SSH_COMMAND "echo 'SSH connection to server succeeded'"; then
    echo "SSH connection to the server failed"
    exit 1
fi

$SSH_COMMAND 'curl https://raw.githubusercontent.com/elitak/nixos-infect/9c5b46d78eb0b108e8ed48a1497be968f7754722/nixos-infect | NIX_CHANNEL=nixos-23.11 bash -x'

echo 'Waiting for server reboot'
sleep 10
