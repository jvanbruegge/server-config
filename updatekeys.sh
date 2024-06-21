#!/usr/bin/env bash

set -euo pipefail

export SSH_COMMAND="ssh -p $SERVER_PORT root@$SERVER_ADDRESS"

if [ -n "$AGE_KEY" ]; then
  age_key=$($SSH_COMMAND 'nix-shell -p ssh-to-age --run "cat /etc/ssh/ssh_host_ed25519_key.pub | ssh-to-age"')
  sed -i "s/&${AGE_KEY}.*$/\&${AGE_KEY} ${age_key}/" .sops.yaml
  for f in ./secrets/*; do
    sops updatekeys -y "$f" || true
  done
  for f in ./tunnel/*; do
    sops updatekeys -y "$f" || true
  done
fi
