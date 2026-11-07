#!/usr/bin/env bash
# Build Nanobots2_<version>.zip from the files git tracks, with the mod folder inside the zip as Factorio expects.
# Usage: tools/package.sh [output-dir]   (default: current directory)
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
out="$(cd "${1:-.}" && pwd)"
version="$(sed -n 's/.*"version": *"\([^"]*\)".*/\1/p' "$root/info.json")"
name="Nanobots2_${version}"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

mkdir "$tmp/$name"
# Tracked files only, minus things that are not part of the mod.
git -C "$root" ls-files -z \
  | grep -zvE '^(\.pdn/|\.github/|tools/|docs/|\.gitignore$|\.mailmap$|\.luacheckrc$|\.luarc\.json$|stylua\.toml$|CONTRIBUTING\.md$)' \
  | (cd "$root" && xargs -0 -I{} cp --parents {} "$tmp/$name")

(cd "$tmp" && zip -qr "$out/$name.zip" "$name")
echo "$out/$name.zip"
