#!/usr/bin/env bash

################################################################################
# Script: enable-emoji-support.sh
# Description:
#   Installs one or more emoji font packages on Arch‑based systems (e.g. Manjaro)
#   and configures fontconfig fallback so that missing glyphs resolve to your
#   chosen emoji fonts. Provides options for dry‑run, verbose output, and
#   custom font lists.
#
# Supported fonts (and their pacman packages):
#   noto      → noto-fonts-emoji
#   joypixels → ttf-joypixels
#   twemoji   → ttf-twemoji
#
# Usage:
#   sudo ./enable-emoji-support.sh [options]
#
# Options:
#   -f, --fonts    Comma-separated list of font keys to install & prioritize
#                  (default: noto)
#   -n, --dry-run  Show what would run without making changes
#   -v, --verbose  Enable verbose logging
#   -h, --help     Show this help message and exit
#
# Examples:
#   sudo ./enable-emoji-support.sh
#   sudo ./enable-emoji-support.sh -f noto,twemoji
#   sudo ./enable-emoji-support.sh --fonts=joypixels --dry-run --verbose
################################################################################

set -euo pipefail

### --- Configuration & Defaults ---
declare -A PACKAGE_MAP=(
  [noto]=noto-fonts-emoji
  [joypixels]=ttf-joypixels
  [twemoji]=ttf-twemoji
)
DEFAULT_FONTS=(noto)

FONTS=("${DEFAULT_FONTS[@]}")
DRY_RUN=false
VERBOSE=false
CONFIG_DIR="/etc/fonts/conf.d"
CONFIG_FILE="01-emoji-fallback.conf"
FULL_PATH="$CONFIG_DIR/$CONFIG_FILE"
TMPFILE="$(mktemp)"
TIMESTAMP="$(date +'%Y%m%d-%H%M%S')"
BACKUP_PATH="$CONFIG_DIR/${CONFIG_FILE%.conf}.conf.bak.$TIMESTAMP"

### --- Helpers ---
log() {
  [[ "$VERBOSE" == true ]] && echo "[INFO] $*"
}
dryrun() {
  if [[ "$DRY_RUN" == true ]]; then
    echo "[DRY-RUN] $*"
  else
    eval "$*"
  fi
}
usage() {
  sed -n '1,30p' "$0" | sed 's/^# \?//'
  exit 0
}

### --- Parse Arguments ---
while [[ $# -gt 0 ]]; do
  case "$1" in
    -f|--fonts)
      shift
      IFS=',' read -r -a FONTS <<< "$1"
      ;;
    -n|--dry-run)   DRY_RUN=true ;;
    -v|--verbose)   VERBOSE=true ;;
    -h|--help)      usage ;;
    *) echo "Unknown option: $1" >&2; usage ;;
  esac
  shift
done

### --- Validate Environment ---
if ! command -v pacman &>/dev/null; then
  echo "[ERROR] pacman not found. This script is for Arch‑based systems." >&2
  exit 1
fi

### --- Validate Fonts ---
for font in "${FONTS[@]}"; do
  if [[ -z "${PACKAGE_MAP[$font]:-}" ]]; then
    echo "[ERROR] Unsupported font key: '$font'" >&2
    echo "Supported keys: ${!PACKAGE_MAP[*]}" >&2
    exit 1
  fi
done

### --- Install Packages ---
for font in "${FONTS[@]}"; do
  pkg="${PACKAGE_MAP[$font]}"
  log "Installing package: $pkg"
  dryrun pacman -S --noconfirm "$pkg"
done

### --- Backup Existing Config ---
if [[ -f "$FULL_PATH" ]]; then
  log "Backing up existing config to $BACKUP_PATH"
  dryrun cp "$FULL_PATH" "$BACKUP_PATH"
fi

### --- Generate fontconfig XML ---
log "Writing fallback config to $FULL_PATH"
{
  echo '<?xml version="1.0"?>'
  echo '<!DOCTYPE fontconfig SYSTEM "fonts.dtd">'
  echo '<fontconfig>'
  for family in sans-serif serif monospace; do
    echo "  <alias>"
    echo "    <family>$family</family>"
    echo "    <prefer>"
    for font in "${FONTS[@]}"; do
      # Map key to human‑readable family name
      case "$font" in
        noto)      fam="Noto Color Emoji" ;;
        joypixels) fam="JoyPixels" ;;
        twemoji)   fam="Twemoji" ;;
      esac
      echo "      <family>$fam</family>"
    done
    echo "    </prefer>"
    echo "  </alias>"
  done
  echo '</fontconfig>'
} > "$TMPFILE"

dryrun mv "$TMPFILE" "$FULL_PATH"
trap 'rm -f "$TMPFILE"' EXIT

### --- Rebuild Cache & Complete ---
log "Rebuilding font cache..."
dryrun fc-cache -fv

echo "✅ Emoji support enabled for: ${FONTS[*]}"
echo "ℹ️  Config file: $FULL_PATH"
echo "🔁 Log out or reboot to apply changes system‑wide."
