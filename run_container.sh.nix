{ inPath, app, stdenv, lib }:
let
  path = lib.strings.concatMapStringsSep ":" (n: "${n}/bin") inPath;
in
''
#!${stdenv.shell}

set -euo pipefail

dir="$(mktemp -d)"
cd "$dir"

mkdir nix

# TODO add --net
# shellcheck disable=2016
unshare --pid --mount --fork --user  --uts --cgroup --map-auto --map-root-user ${stdenv.shell} -c '

# See https://github.com/NixOS/nixpkgs/issues/42117#issuecomment-974194691
PATH=$(echo "$PATH" | sed -e "s/\/run\/wrappers\/bin://g")

mount --bind ./ ./
mount --rbind /nix ./nix
mkdir old_root proc
pivot_root $(pwd) $(pwd)/old_root

PATH=${path}

mount -t proc proc /proc
umount -l /old_root
rm -d old_root

exec ${app}
'

cd ..
rm -r "$dir"
''
