#!/bin/sh

# fix-pacman-gpg.sh - Fix pacman GPGME errors on Arch/Manjaro

trap 'echo "\nInterrupted. Exiting."; exit 1' INT

PROGNAME=$(basename "$0")

show_help() {
  echo "Usage: $PROGNAME [OPTIONS]

Fix pacman GPGME errors by clearing package metadata and reinitializing
the pacman keyring.

Options:
  --manjaro           Also populate Manjaro keyring (default: Arch Linux only)
  --refresh-keys      Refresh all GPG keys from Ubuntu keyserver (can be slow)
  --update-mirrors    Update system mirror list (can be slow)
  -h, --help          Show this help message and exit

Examples:
  $PROGNAME
  $PROGNAME --manjaro
  $PROGNAME --manjaro --refresh-keys --update-mirrors
"
}

# === Parse arguments first
DISTRO="arch"
REFRESH_KEYS=0
UPDATE_MIRRORS=0

for arg in "$@"; do
  case "$arg" in
    --manjaro)
      DISTRO="manjaro"
      ;;
    --refresh-keys)
      REFRESH_KEYS=1
      ;;
    --update-mirrors)
      UPDATE_MIRRORS=1
      ;;
    -h|--help)
      show_help
      exit 0
      ;;
    *)
      echo "Unknown option: $arg"
      show_help
      exit 1
      ;;
  esac
done

# === Ensure root privileges
if [ "$(id -u)" -ne 0 ]; then
  echo "==> This script must run as root. Relaunching with sudo..."
  exec sudo "$0" "$@"
fi

# === Optional: Update mirror list
if [ "$UPDATE_MIRRORS" -eq 1 ]; then
  echo "==> Updating mirror list..."
  if [ "$DISTRO" = "manjaro" ] && command -v pacman-mirrors >/dev/null 2>&1; then
    echo "Using pacman-mirrors for Manjaro..."
    pacman-mirrors --fasttrack
    pacman -Syy
  elif command -v reflector >/dev/null 2>&1; then
    echo "Using reflector for Arch..."
    reflector --latest 20 --protocol https --sort rate --save /etc/pacman.d/mirrorlist
  elif command -v rankmirrors >/dev/null 2>&1; then
    echo "Using rankmirrors (fallback)..."
    rankmirrors -n 6 /etc/pacman.d/mirrorlist > /etc/pacman.d/mirrorlist.new
    mv /etc/pacman.d/mirrorlist.new /etc/pacman.d/mirrorlist
  else
    echo "WARNING: Could not update mirror list — no suitable tool found."
  fi
fi

# === Clean up package metadata and keys
echo "==> Removing old package databases and signatures..."
rm -f /var/lib/pacman/sync/*.db /var/lib/pacman/sync/*.db.sig

echo "==> Removing old GPG keyring..."
rm -rf /etc/pacman.d/gnupg

echo "==> Initializing new GPG keyring..."
pacman-key --init

echo "==> Populating Arch Linux keyring..."
pacman-key --populate archlinux

if [ "$DISTRO" = "manjaro" ]; then
  echo "==> Populating Manjaro keyring..."
  pacman-key --populate manjaro
fi

if [ "$REFRESH_KEYS" -eq 1 ]; then
  echo "==> Refreshing GPG keys from Ubuntu keyserver (this may take a while)..."
  pacman-key --keyserver hkps://keyserver.ubuntu.com --refresh-keys
fi

echo "==> Synchronizing package databases..."
pacman -Sy

echo "==> Done. If pacman still fails, retry with --refresh-keys."
