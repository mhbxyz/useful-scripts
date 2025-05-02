#!/bin/sh

################################################################################
# Script: enable-emoji-support.sh
# Description:
#   Installs emoji font packages on Arch-based systems (e.g. Manjaro) and
#   configures fontconfig fallback.
################################################################################

set -eu

DEFAULT_FONTS="noto"
FONTS="$DEFAULT_FONTS"
DRY_RUN=false
VERBOSE=false
CONFIG_DIR="/etc/fonts/conf.d"
CONFIG_FILE="01-emoji-fallback.conf"
FULL_PATH="$CONFIG_DIR/$CONFIG_FILE"
TMPFILE="$(mktemp)"
TIMESTAMP="$(date +'%Y%m%d-%H%M%S')"
BACKUP_PATH="$CONFIG_DIR/${CONFIG_FILE%.conf}.conf.bak.$TIMESTAMP"

# --- Helpers ---
log() {
  if [ "$VERBOSE" = true ]; then
    printf "[INFO] %s\n" "$*"
  fi
}
dryrun() {
  if [ "$DRY_RUN" = true ]; then
    printf "[DRY-RUN] %s\n" "$*"
  else
    eval "$*"
  fi
}
show_help() {
  cat <<EOF
enable-emoji-support.sh – Install and configure emoji fonts on Arch-based systems

Usage:
  sudo ./enable-emoji-support.sh [options]

Options:
  -f, --fonts     Comma-separated list of fonts to install and prioritize
                  (default: noto)
                  Supported: noto, joypixels, twemoji
  -n, --dry-run   Show commands without executing them
  -v, --verbose   Enable verbose logging
  -h, --help      Show this help message and exit

Examples:
  sudo ./enable-emoji-support.sh
  sudo ./enable-emoji-support.sh -f noto,twemoji
  sudo ./enable-emoji-support.sh --fonts=joypixels --dry-run --verbose

Description:
  This script installs emoji fonts and configures fontconfig fallback so missing
  glyphs resolve to your selected emoji fonts.

Notes:
  - Requires 'pacman' (for Arch-based systems like Manjaro).
  - May require logout or reboot to apply changes.
EOF
  exit 0
}

# --- Parse Arguments ---
while [ $# -gt 0 ]; do
  case "$1" in
    -f|--fonts)
      shift
      FONTS="$1"
      ;;
    -n|--dry-run)
      DRY_RUN=true
      ;;
    -v|--verbose)
      VERBOSE=true
      ;;
    -h|--help)
      show_help
      ;;
    *)
      printf "Unknown option: %s\n" "$1" >&2
      show_help
      ;;
  esac
  shift
done

# --- Validate Environment ---
if ! command -v pacman >/dev/null 2>&1; then
  printf "[ERROR] pacman not found. This script is for Arch-based systems.\n" >&2
  exit 1
fi

# --- Validate Fonts ---
SUPPORTED_FONTS="noto joypixels twemoji"
for font in $(echo "$FONTS" | tr ',' ' '); do
  found=false
  for supported in $SUPPORTED_FONTS; do
    if [ "$font" = "$supported" ]; then
      found=true
      break
    fi
  done
  if [ "$found" != true ]; then
    printf "[ERROR] Unsupported font key: '%s'\n" "$font" >&2
    printf "Supported keys: %s\n" "$SUPPORTED_FONTS" >&2
    exit 1
  fi
done

# --- Install Packages ---
for font in $(echo "$FONTS" | tr ',' ' '); do
  case "$font" in
    noto) pkg="noto-fonts-emoji" ;;
    joypixels) pkg="ttf-joypixels" ;;
    twemoji) pkg="ttf-twemoji" ;;
  esac
  log "Installing package: $pkg"
  dryrun "pacman -S --noconfirm $pkg"
done

# --- Backup Existing Config ---
if [ -f "$FULL_PATH" ]; then
  log "Backing up existing config to $BACKUP_PATH"
  dryrun "cp '$FULL_PATH' '$BACKUP_PATH'"
fi

# --- Generate fontconfig XML ---
log "Writing fallback config to $FULL_PATH"

{
  printf '<?xml version="1.0"?>\n'
  printf '<!DOCTYPE fontconfig SYSTEM "fonts.dtd">\n'
  printf '<fontconfig>\n'
  for family in sans-serif serif monospace; do
    printf "  <alias>\n"
    printf "    <family>%s</family>\n" "$family"
    printf "    <prefer>\n"
    for font in $(echo "$FONTS" | tr ',' ' '); do
      case "$font" in
        noto) fam="Noto Color Emoji" ;;
        joypixels) fam="JoyPixels" ;;
        twemoji) fam="Twemoji" ;;
      esac
      printf "      <family>%s</family>\n" "$fam"
    done
    printf "    </prefer>\n"
    printf "  </alias>\n"
  done
  printf '</fontconfig>\n'
} > "$TMPFILE"

dryrun "mv '$TMPFILE' '$FULL_PATH'"
trap 'rm -f "$TMPFILE"' EXIT

# --- Rebuild Cache ---
log "Rebuilding font cache..."
dryrun "fc-cache -fv"

printf "✅ Emoji support enabled for: %s\n" "$FONTS"
printf "ℹ️  Config file: %s\n" "$FULL_PATH"
printf "🔁 Log out or reboot to apply changes system-wide.\n"
