#!/bin/sh
set -eu

DRY_RUN=false
VERBOSE=false

show_help() {
  cat <<EOF
fix-manjaro-gpg.sh – Fix Manjaro GPG keyring issues & fully update system

Usage:
  sudo ./fix-manjaro-gpg.sh [options]

Options:
  -h, --help      Show this help message and exit
  -n, --dry-run   Print commands instead of executing them
  -v, --verbose   Enable verbose output

Description:
  This script resolves common pacman keyring issues (e.g., "GPGME error") by:
    1. Refreshing Manjaro mirrors
    2. Cleaning corrupted pacman database files
    3. Re-initializing pacman keyring
    4. Populating Arch & Manjaro keyrings
    5. Refreshing keys from keyservers
    6. Reinstalling keyring packages
    7. Performing a full system upgrade

Notes:
  - Requires 'pacman-mirrors' and 'pacman-key' utilities.
  - Must be run as root (use 'sudo').

Example:
  sudo ./fix-manjaro-gpg.sh --verbose
  sudo ./fix-manjaro-gpg.sh --dry-run
EOF
  exit 0
}

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

# --- Parse Arguments ---
while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help)
      show_help
      ;;
    -n|--dry-run)
      DRY_RUN=true
      ;;
    -v|--verbose)
      VERBOSE=true
      ;;
    *)
      printf "Unknown option: %s\n" "$1" >&2
      show_help
      ;;
  esac
  shift
done

# --- Ensure running as root ---
if [ "$(id -u)" -ne 0 ]; then
  printf "ERROR: This script must be run as root.\n" >&2
  printf "Usage: sudo %s\n" "$0" >&2
  exit 1
fi

printf "\n👉 1. Refreshing Manjaro mirror list...\n"
log "Running: pacman-mirrors --fasttrack"
dryrun "pacman-mirrors --fasttrack"
printf "   ✅ Mirrors updated.\n"

printf "\n👉 2. Cleaning up old database files...\n"
log "Removing /var/lib/pacman/sync/*.db and *.db.sig"
dryrun "rm -f /var/lib/pacman/sync/*.db /var/lib/pacman/sync/*.db.sig"
printf "   ✅ Old DB files removed.\n"

printf "\n👉 3. Initializing pacman keyring...\n"
log "Running: pacman-key --init"
dryrun "pacman-key --init"
printf "   ✅ Keyring initialized.\n"

printf "\n👉 4. Populating Arch Linux & Manjaro keyrings...\n"
log "Running: pacman-key --populate archlinux manjaro"
dryrun "pacman-key --populate archlinux manjaro"
printf "   ✅ Keyrings populated.\n"

printf "\n👉 5. Refreshing pacman keys from keyservers (this may take a while)...\n"
log "Running: pacman-key --refresh-keys"
dryrun "pacman-key --refresh-keys"
printf "   ✅ Keys refreshed.\n"

printf "\n👉 6. Re-installing keyring packages to ensure integrity...\n"
log "Running: pacman -Sy --noconfirm archlinux-keyring manjaro-keyring"
dryrun "pacman -Sy --noconfirm archlinux-keyring manjaro-keyring"
printf "   ✅ Keyring packages re-installed.\n"

printf "\n👉 7. Performing full system upgrade...\n"
log "Running: pacman -Syu --noconfirm"
dryrun "pacman -Syu --noconfirm"
printf "   🎉 System successfully updated!\n"

printf "\nAll done! Your Manjaro system is now fully up-to-date with a healthy keyring.\n"
