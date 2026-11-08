#!/usr/bin/env bash
# Builds <name>_<version>.zip (name and version from info.json) with one
# top-level folder inside, the form Factorio's mods folder expects.
# Packages the committed HEAD; --dirty packages the working copy instead
# (tracked files as on disk plus staged new files, no untracked files), for
# local testing. Files marked export-ignore in .gitattributes are left out.
# usage: tools/package.sh [--dirty] [output-dir]
set -euo pipefail
unset CDPATH

usage="usage: tools/package.sh [--dirty] [output-dir]"
dirty=0
have_out=0
out=
while (( $# > 0 )); do
  case $1 in
    --dirty)
      dirty=1
      ;;
    -*)
      echo "$usage" >&2
      exit 2
      ;;
    *)
      if (( have_out == 1 )); then
        echo "$usage" >&2
        exit 2
      fi
      out=$1
      have_out=1
      ;;
  esac
  shift
done
out="${out:-.}"

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# The repo must be checked out at its top level and have a commit.
ok=0
if git -C "$root" rev-parse --verify --quiet 'HEAD^{commit}' >/dev/null 2>&1; then
  if cdup="$(git -C "$root" rev-parse --show-cdup 2>/dev/null)"; then
    if [[ -z "$cdup" ]]; then
      ok=1
    fi
  fi
fi
if (( ok == 0 )); then
  msg="$(LC_ALL=C LANGUAGE=C git -C "$root" rev-parse --git-dir 2>&1 >/dev/null || true)"
  if [[ "$msg" == *"dubious ownership"* ]]; then
    echo "error: git refuses a repository containing $root (dubious ownership); run 'git -C $root status' for git's safe.directory hint" >&2
  else
    echo "error: $root is not the top of a git checkout with a commit" >&2
  fi
  exit 1
fi

# Choose what to package: HEAD, or a snapshot of the working copy.
rev=HEAD
where="at HEAD"
if (( dirty == 1 )); then
  # Refresh the stat cache so a touched but unchanged file does not make
  # 'git stash create' fail; a held index.lock makes this fail silently.
  git -C "$root" update-index -q --refresh >/dev/null 2>&1 || true
  if ! snap="$(git -C "$root" stash create)"; then
    echo "error: cannot snapshot the working copy; git stash create failed (unmerged or intent-to-add entries, or a leftover .git/index.lock?)" >&2
    exit 1
  fi
  if [[ -n "$snap" ]]; then
    rev="$snap"
    where="in the working copy"
    echo "note: packaging the working copy, including uncommitted changes" >&2
  else
    echo "note: no uncommitted changes to tracked files; packaging HEAD ($(git -C "$root" rev-parse --short HEAD))" >&2
  fi
  untracked="$(git -C "$root" ls-files --others --exclude-standard | grep -c . || true)"
  if [[ "$untracked" != "0" ]]; then
    echo "warning: $untracked untracked file(s) not packaged unless you git add them (export-ignored paths are never packaged)" >&2
  fi
fi

fail() {
  echo "error: info.json $where: $1" >&2
  exit 1
}

if ! git -C "$root" cat-file -e "$rev:info.json" 2>/dev/null; then
  fail "missing"
fi
if ! json="$(git -C "$root" show "$rev:info.json")"; then
  fail "cannot be read"
fi

# Exactly one line per key; "factorio_version" cannot match because the key's
# opening quote is part of the pattern.
for key in name version; do
  count="$(printf '%s\n' "$json" | grep -cE '^[[:space:]]*"'"$key"'"[[:space:]]*:' || true)"
  if [[ "$count" != "1" ]]; then
    fail "\"$key\" found on $count lines, expected exactly 1"
  fi
done
name="$(printf '%s\n' "$json" | sed -n 's/^[[:space:]]*"name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*$/\1/p')"
version="$(printf '%s\n' "$json" | sed -n 's/^[[:space:]]*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*$/\1/p')"

if ! [[ "$name" =~ ^[A-Za-z0-9_-]+$ ]] || (( ${#name} > 100 )); then
  fail "\"name\" must be 1 to 100 characters of letters, digits, '-' and '_'"
fi
three='^([^.]*)\.([^.]*)\.([^.]*)$'
num='^(0|[1-9][0-9]{0,4})$'
if ! [[ "$version" =~ $three ]]; then
  fail "\"version\" must look like number.number.number"
fi
for part in "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}" "${BASH_REMATCH[3]}"; do
  if ! [[ "$part" =~ $num ]]; then
    fail "\"version\" parts must be numbers without leading zeros"
  fi
  if ! (( 10#$part <= 65535 )); then
    fail "\"version\" parts must be 65535 or less"
  fi
done

if ! mkdir -p -- "$out" 2>/dev/null || ! outabs="$(cd "$out" 2>/dev/null && pwd)"; then
  echo "error: cannot create output directory $out" >&2
  exit 1
fi
out="$outabs"

if (( dirty == 0 )); then
  if [[ -n "$(git -C "$root" status --porcelain --untracked-files=no 2>/dev/null || true)" ]]; then
    echo "warning: uncommitted changes are not included; packaging HEAD ($(git -C "$root" rev-parse --short HEAD)); use --dirty to include them" >&2
  fi
fi

base="${name}_${version}"
zip="$out/$base.zip"
if ! rm -f -- "$zip"; then
  echo "error: cannot remove old $zip" >&2
  exit 1
fi
# Neutralise the builder's git settings so the same commit gives the same files.
if ! TZ=UTC GIT_ATTR_NOSYSTEM=1 git -C "$root" -c core.autocrlf=false -c core.eol=lf -c core.attributesFile=/dev/null archive --format=zip --prefix="$base/" -o "$zip" "$rev"; then
  rm -f -- "$zip"
  echo "error: git archive failed" >&2
  exit 1
fi
printf '%s\n' "$zip"
