#!/usr/bin/env bash

set -euo pipefail

dir="$(mktemp -d)"
cd "$dir"

mkdir nix

# shellcheck disable=2016
unshare --pid --mount-proc --mount --fork --user --net --uts --cgroup --map-auto --map-root-user bash -c '

PATH=${PATH//:\/run\/wrappers\/bin/}
mount --rbind /nix ./nix
exec bash
'

cd ..
rm -r "$dir"
