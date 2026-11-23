#!/usr/bin/env bash
# Installs each bot's SOUL.md and the squad's skills into its Orca home.
# Create the bots in Orca first (Bots → + → New bot); this only fills homes that exist.
#
#   scripts/install.sh [bot ...]     # default: every bot in bots/
#   e.g. scripts/install.sh chartbeard   or   scripts/install.sh "Chartbeard [SPEC]"
#
# A bot is found by the name in its bot.json, with or without its code:
# "ShipItFinn" and "ShipItFinn [DEV]" both match bots/shipitfinn.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
homes="${ORCA_BOTS_DIR:-$HOME/.orca/bots}"

# Orca keeps a deleted bot's folder on disk, so only folders of bots Orca still lists count.
orca_cli="${ORCA_CLI_COMMAND:-orca}"
if registered="$("$orca_cli" bot list --json 2>/dev/null)"; then
  registered="$(printf '%s' "$registered" | grep -o '"id": *"[^"]*"' | sed 's/.*"\([^"]*\)"$/\1/')"
else
  registered=""
  echo "warning: could not ask Orca which bots exist; a deleted bot's old folder may be picked" >&2
fi

# Prints the home folder of the Orca bot whose name, without " [CODE]", is $1 (any case).
find_home() {
  local want name dir id
  want="$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')"
  for dir in "$homes"/*/; do
    [ -f "$dir/bot.json" ] || continue
    if [ -n "$registered" ]; then
      id="$(sed -n 's/^[[:space:]]*"id":[[:space:]]*"\(.*\)",*[[:space:]]*$/\1/p' "$dir/bot.json" | head -1)"
      printf '%s\n' "$registered" | grep -qxF "$id" || continue
    fi
    name="$(sed -n 's/^[[:space:]]*"name":[[:space:]]*"\(.*\)",*[[:space:]]*$/\1/p' "$dir/bot.json" | head -1)"
    name="$(printf '%s' "${name%% \[*}" | tr '[:upper:]' '[:lower:]')"
    if [ "$name" = "$want" ]; then
      printf '%s\n' "${dir%/}"
      return
    fi
  done
}

if [ $# -eq 0 ]; then
  set -- $(ls "$root/bots")
fi

for bot in "$@"; do
  bot="${bot%% \[*}"   # "Chartbeard [SPEC]" -> "Chartbeard"
  bot="$(printf '%s' "$bot" | tr '[:upper:]' '[:lower:]')"
  src="$root/bots/$bot"
  [ -f "$src/SOUL.md" ] || { echo "unknown bot: $bot" >&2; exit 1; }
  dst="$(find_home "$bot")"
  if [ -z "$dst" ]; then
    echo "skip $bot: create it in Orca first (no bot named $bot in $homes)"
    continue
  fi
  # Keep the soul the bot had before the first install; later installs must not replace that copy.
  if [ -f "$dst/SOUL.md" ] && [ ! -f "$dst/SOUL.md.bak" ]; then
    cp "$dst/SOUL.md" "$dst/SOUL.md.bak"
  fi
  cp "$src/SOUL.md" "$dst/SOUL.md"
  mkdir -p "$dst/skills"
  rm -rf "$dst/skills/kds-pipeline"
  cp -R "$root/skills/kds-pipeline" "$dst/skills/"
  echo "installed $bot"
done
