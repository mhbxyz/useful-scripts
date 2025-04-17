#!/usr/bin/env bash
set -euo pipefail

# -----------------------------------------------------------------------------
# Manjaro “GPGME error” Fix & Full System Update
# -----------------------------------------------------------------------------
# This script:
#   1. Fasttracks the best Manjaro mirrors
#   2. Cleans out any corrupted pacman DB files
#   3. Re-initializes & populates the Arch + Manjaro keyrings
#   4. Refreshes keys from keyservers
#   5. Re-installs keyring packages
#   6. Performs a full system upgrade
# -----------------------------------------------------------------------------

# Ensure we’re running as root
if [ "$(id -u)" -ne 0 ]; then
  echo "ERROR: This script must be run as root." >&2
  echo "Usage: sudo $0" >&2
  exit 1
fi

echo
echo "👉 1. Refreshing Manjaro mirror list..."
pacman-mirrors --fasttrack
echo "   ✅ Mirrors updated."

echo
echo "👉 2. Cleaning up old database files..."
rm -f /var/lib/pacman/sync/*.db{,.sig}
echo "   ✅ Old DB files removed."

echo
echo "👉 3. Initializing pacman keyring..."
pacman-key --init
echo "   ✅ Keyring initialized."

echo
echo "👉 4. Populating Arch Linux & Manjaro keyrings..."
pacman-key --populate archlinux manjaro
echo "   ✅ Keyrings populated."

echo
echo "👉 5. Refreshing pacman keys from keyservers (this may take a while)..."
pacman-key --refresh-keys
echo "   ✅ Keys refreshed."

echo
echo "👉 6. Re-installing keyring packages to ensure integrity..."
pacman -Sy --noconfirm archlinux-keyring manjaro-keyring
echo "   ✅ Keyring packages re-installed."

echo
echo "👉 7. Performing full system upgrade..."
pacman -Syu --noconfirm
echo "   🎉 System successfully updated!"

echo
echo "All done! Your Manjaro system is now fully up‑to‑date with a healthy keyring."
