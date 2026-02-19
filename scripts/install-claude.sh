#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SOURCE_DIR="$REPO_ROOT/skills"
TARGET_DIR="$HOME/.claude/skills"
TARGET_LINK="$TARGET_DIR/osxskills"

if [[ ! -d "$SOURCE_DIR" ]]; then
  echo "ERROR: skills directory not found at $SOURCE_DIR" >&2
  exit 1
fi

mkdir -p "$TARGET_DIR"

if [[ -e "$TARGET_LINK" && ! -L "$TARGET_LINK" ]]; then
  echo "ERROR: $TARGET_LINK exists and is not a symlink. Move/remove it first." >&2
  exit 1
fi

ln -sfn "$SOURCE_DIR" "$TARGET_LINK"

echo "Installed OSXSkills for Claude."
echo "Symlink: $TARGET_LINK -> $SOURCE_DIR"
