#!/bin/sh

# Script to view and edit the ssh config
# Author: Manoah Bernier

SSH_CONFIG="$HOME/.ssh/config"
BACKUP_FILE="$HOME/.ssh/config.bak"
EDITOR="${EDITOR:-nano}"

# Ensure config file exists
if [ ! -f "$SSH_CONFIG" ]; then
  mkdir -p "$(dirname "$SSH_CONFIG")"
  touch "$SSH_CONFIG"
fi

show_help() {
  prog=$(basename "$0")
  cat <<EOF
$prog – View and edit your SSH config

Usage:
  $prog add <host> <hostname> <user> [identity_file]   Add a new SSH host entry
  $prog remove <host>                                  Remove an existing host entry
  $prog list                                           List all defined host aliases
  $prog show <host>                                    Show configuration details for a host
  $prog edit <host>                                    Edit a host entry using \$EDITOR (default: $EDITOR)
  $prog backup                                         Create a backup of your SSH config
  $prog help                                           Show this help message

Description:
  This script lets you manage your ~/.ssh/config file by adding, removing,
  listing, showing, editing, or backing up SSH host entries.

Examples:
  $prog add myserver example.com user ~/.ssh/id_rsa
  $prog remove myserver
  $prog list
  $prog show myserver
  $prog edit myserver
  $prog backup

Notes:
  - The SSH config will be automatically created if missing.
  - A backup is saved as ~/.ssh/config.bak during remove/edit.
EOF
  exit 0
}

add_host() {
  host="$1"
  hostname="$2"
  user="$3"
  identity_file="$4"

  if grep -q "^Host[[:space:]]\+$host\$" "$SSH_CONFIG"; then
    printf "Host '%s' already exists in config.\n" "$host"
    return 1
  fi

  {
    printf "\n"
    printf "Host %s\n" "$host"
    printf "    HostName %s\n" "$hostname"
    printf "    User %s\n" "$user"
    if [ -n "$identity_file" ]; then
      printf "    IdentityFile %s\n" "$identity_file"
    fi
  } >> "$SSH_CONFIG"

  printf "Added host '%s'.\n" "$host"
}

remove_host() {
  host="$1"
  if ! grep -q "^Host[[:space:]]\+$host\$" "$SSH_CONFIG"; then
    printf "Host '%s' not found.\n" "$host"
    return 1
  fi

  tmpfile=$(mktemp)
  awk -v h="$host" '
    BEGIN { skip=0 }
    /^Host / {
      if ($2 == h) { skip=1; next }
      if (skip) { skip=0 }
    }
    skip==0 { print }
  ' "$SSH_CONFIG" > "$tmpfile"

  cp "$SSH_CONFIG" "$SSH_CONFIG.bak"
  mv "$tmpfile" "$SSH_CONFIG"

  printf "Removed host '%s'. Backup saved to %s.bak\n" "$host" "$SSH_CONFIG"
}

list_hosts() {
  awk '/^Host / {print $2}' "$SSH_CONFIG"
}

show_host() {
  host="$1"
  awk -v h="$host" '
    BEGIN { p=0 }
    /^Host / {
      if ($2 == h) { print; p=1; next }
      if (p==1) { exit }
    }
    p==1 { print }
  ' "$SSH_CONFIG"
}

edit_host() {
  host="$1"
  if ! grep -q "^Host[[:space:]]\+$host\$" "$SSH_CONFIG"; then
    printf "Host '%s' not found.\n" "$host"
    return 1
  fi

  temp_file=$(mktemp)

  # extract block
  awk -v h="$host" '
    BEGIN { p=0 }
    /^Host / {
      if ($2 == h) { print; p=1; next }
      if (p==1) { exit }
    }
    p==1 { print }
  ' "$SSH_CONFIG" > "$temp_file"

  $EDITOR "$temp_file"

  # remove old block
  tmpfile=$(mktemp)
  awk -v h="$host" '
    BEGIN { skip=0 }
    /^Host / {
      if ($2 == h) { skip=1; next }
      if (skip) { skip=0 }
    }
    skip==0 { print }
  ' "$SSH_CONFIG" > "$tmpfile"

  cp "$SSH_CONFIG" "$SSH_CONFIG.bak"
  mv "$tmpfile" "$SSH_CONFIG"

  # append edited block
  printf "\n" >> "$SSH_CONFIG"
  cat "$temp_file" >> "$SSH_CONFIG"

  rm "$temp_file"

  printf "Host '%s' updated.\n" "$host"
  printf "Backup saved to %s.bak\n" "$SSH_CONFIG"
}

backup_config() {
  cp "$SSH_CONFIG" "$BACKUP_FILE"
  printf "Backup saved to %s\n" "$BACKUP_FILE"
}

if [ $# -lt 1 ]; then
  show_help
fi

cmd="$1"
shift

case "$cmd" in
  add)
    [ $# -ge 3 ] || { show_help; exit 1; }
    add_host "$1" "$2" "$3" "${4:-}"
    ;;
  remove)
    [ $# -eq 1 ] || { show_help; exit 1; }
    remove_host "$1"
    ;;
  list)
    list_hosts
    ;;
  show)
    [ $# -eq 1 ] || { show_help; exit 1; }
    show_host "$1"
    ;;
  edit)
    [ $# -eq 1 ] || { show_help; exit 1; }
    edit_host "$1"
    ;;
  backup)
    backup_config
    ;;
  help|-h|--help)
    show_help
    ;;
  *)
    printf "Unknown command: %s\n\n" "$cmd"
    show_help
    ;;
esac
