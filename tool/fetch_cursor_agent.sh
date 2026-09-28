#!/usr/bin/env bash
# Download a pinned Cursor CLI package into third_party/cursor-agent/.
# The tree is gitignored. Linux CMake copies it into the AppImage at
# data/cursor-agent/ when present.
#
# Usage: tool/fetch_cursor_agent.sh [os] [arch]
#   os:   linux | darwin   (default linux)
#   arch: x64 | arm64      (default x64)
set -euo pipefail

VERSION="2026.09.02-c22c1a3"
OS="${1:-linux}"
ARCH="${2:-x64}"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="$ROOT/third_party/cursor-agent"
URL="https://downloads.cursor.com/lab/${VERSION}/${OS}/${ARCH}/agent-cli-package.tar.gz"

if [[ -f "$DEST/VERSION" && -f "$DEST/cursor-agent" ]]; then
  current="$(tr -d '[:space:]' < "$DEST/VERSION")"
  if [[ "$current" == "$VERSION" ]]; then
    echo "cursor-agent ${VERSION} already present at ${DEST}"
    exit 0
  fi
fi

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

echo "Downloading ${URL}"
curl -fL --retry 3 --retry-delay 2 "$URL" | tar -xzf - -C "$tmpdir" --strip-components=1

if [[ ! -f "$tmpdir/cursor-agent" ]]; then
  echo "Package did not contain cursor-agent" >&2
  find "$tmpdir" -maxdepth 2 -type f -print >&2
  exit 1
fi

rm -rf "$DEST"
mkdir -p "$(dirname "$DEST")"
mv "$tmpdir" "$DEST"
trap - EXIT
printf '%s\n' "$VERSION" > "$DEST/VERSION"
chmod +x "$DEST/cursor-agent"
echo "Installed cursor-agent ${VERSION} at ${DEST}"
