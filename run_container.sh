#!/usr/bin/env bash

set -euo pipefail

dir="$(mktemp -d)"
cd "$dir"

mkdir nix

# shellcheck disable=2016
unshare --pid --mount --fork --user --net --uts --cgroup --map-auto --map-root-user bash -c '
# See https://github.com/NixOS/nixpkgs/issues/42117#issuecomment-974194691
PATH=$(echo "$PATH" | sed -e "s/\/run\/wrappers\/bin://g")

mount --bind ./ ./
mount --rbind /nix ./nix
mkdir old_root proc
pivot_root $(pwd) $(pwd)/old_root

PATH=/nix/store/q6my4sv2vnddq5iyh12xfjvrnjrlq8cs-coreutils-full-9.1/bin:/nix/store/6wnx8cj5v6lzc8ih9v0dkr0cakwbf6dl-util-linux-2.38.1-bin/bin

mount -t proc proc /proc
umount -l /old_root
rm -d old_root

exec /nix/store/x40p83k9mk03kklpfahqppp6kz85yx99-bash-interactive-5.1-p16/bin/bash
'

cd ..
rm -r "$dir"
