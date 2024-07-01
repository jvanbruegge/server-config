#!/usr/bin/env nix-shell
#!nix-shell -i bash -p curl jq prefetch-npm-deps nix-prefetch-github coreutils crane

set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

old_version=$(jq -r ".version" sources.json || echo -n "0.0.1")
version=$(curl -s "https://api.github.com/repos/immich-app/immich/releases/latest" | jq -r ".tag_name")
version="${version#v}"

echo "Updating to $version"

echo "Fetching container tags"
container_tag="$(crane ls ghcr.io/immich-app/base-server-prod | grep -e '^20[0-9]*$' | tail -n1)"
old_container_tag="$(jq -r ".container_tag" sources.json || echo -n "0")"
echo "Updating geodata to $container_tag"

if [[ "$old_version" == "$version" ]] && [[ "$container_tag" == "$old_container_tag" ]]; then
    echo "Already up to date!"
    exit 0
fi

echo "Fetching src"
src_hash=$(nix-prefetch-github immich-app immich --rev "v${version}" | jq -r .hash)
upstream_src="https://raw.githubusercontent.com/immich-app/immich/v$version"

resource_dir="$(mktemp -d)"
echo "Fetching geodata from container"
crane export "ghcr.io/immich-app/base-server-prod:$container_tag" - \
  | tar -xv -C "$resource_dir" --strip-components=3 usr/src/resources
geodata_hash="$(nix hash path "$resource_dir")"
rm -rf "$resource_dir"

sources_tmp="$(mktemp)"
cat <<EOF > "$sources_tmp"
{
  "version": "$version",
  "hash": "$src_hash",
  "container_tag": "$container_tag",
  "geodata_hash": "$geodata_hash",
  "components": {}
}
EOF

for npm_component in cli server web "open-api/typescript-sdk"; do
    echo "fetching $npm_component"
    hash=$(prefetch-npm-deps <(curl -s "$upstream_src/$npm_component/package-lock.json"))
    echo "$(jq --arg npm_component "$npm_component" \
      --arg hash "$hash" \
      '.components += {($npm_component): {npmDepsHash: $hash}}' \
      "$sources_tmp")" > "$sources_tmp"
done

cp "$sources_tmp" sources.json
