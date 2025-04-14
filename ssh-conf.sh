#!/bin/bash

# Script to view and edit the ssh config
# Author: Manoah Bernier

SSH_CONFIG="$HOME/.ssh/config"
BACKUP_FILE="$HOME/.ssh/config.bak"
EDITOR="${EDITOR:-nano}"

add_host() {
  local host="$1"
  local hostname="$2"
  local user="$3"
  local identity_file="$4"

  if grep -qE "^Host\s+$host\$" "$SSH_CONFIG"; then
    echo "Host '$host' already exists in config."
    return 1
  fi

  {
    echo ""
    echo "Host $host"
    echo "    HostName $hostname"
    echo "    User $user"
    [ -n "$identity_file" ] && echo "    IdentityFile $identity_file"
  } >> "$SSH_CONFIG"

  echo "Added host '$host'."
}

remove_host() {
  local host="$1"
  if ! grep -qE "^Host\s+$host\$" "$SSH_CONFIG"; then
    echo "Host '$host' not found."
    return 1
  fi

  # Remove lines from "Host <host>" to the next "Host" or EOF
  sed -i.bak "/^Host $host\$/,/^Host /{ /^Host $host\$/d; /^Host /!d }" "$SSH_CONFIG"
  echo "Removed host '$host'. Backup saved to $SSH_CONFIG.bak"
}

list_hosts() {
  grep "^Host " "$SSH_CONFIG" | awk '{print $2}'
}

show_host() {
  local host="$1"
  awk "/^Host $host\$/{p=1; next} /^Host /{p=0} p" "$SSH_CONFIG" | sed "1iHost $host"
}

edit_host() {
  local host="$1"
  if ! grep -qE "^Host\s+$host\$" "$SSH_CONFIG"; then
    echo "Host '$host' not found."
    return 1
  fi

  local temp_file
  temp_file=$(mktemp)

  # Extract existing host block
  awk "/^Host $host\$/{p=1; print; next} /^Host /{p=0} p" "$SSH_CONFIG" > "$temp_file"

  # Open in editor
  $EDITOR "$temp_file"

  # Replace old block with new block
  sed -i.bak "/^Host $host\$/,/^Host /{ /^Host $host\$/d; /^Host /!d }" "$SSH_CONFIG"
  echo "" >> "$SSH_CONFIG"
  cat "$temp_file" >> "$SSH_CONFIG"

  echo "Host '$host' updated."
  echo "Backup saved to $SSH_CONFIG.bak"
  rm "$temp_file"
}

backup_config() {
  cp "$SSH_CONFIG" "$BACKUP_FILE"
  echo "Backup saved to $BACKUP_FILE"
}

usage() {
  prog=$(basename "$0")
  echo "Usage:"
  echo "  $prog add <host> <hostname> <user> [identity_file]   Add a new SSH host entry"
  echo "  $prog remove <host>                                  Remove an existing host entry"
  echo "  $prog list                                           List all defined host aliases"
  echo "  $prog show <host>                                    Show configuration details for a host"
  echo "  $prog edit <host>                                    Edit a host entry using \$EDITOR (default: $(echo "$EDITOR"))"
  echo "  $prog backup                                         Create a backup of your SSH config"
}


case "$1" in
  add)
    [ $# -ge 4 ] || { usage; exit 1; }
    add_host "$2" "$3" "$4" "$5"
    ;;
  remove)
    [ $# -eq 2 ] || { usage; exit 1; }
    remove_host "$2"
    ;;
  list)
    list_hosts
    ;;
  show)
    [ $# -eq 2 ] || { usage; exit 1; }
    show_host "$2"
    ;;
  edit)
    [ $# -eq 2 ] || { usage; exit 1; }
    edit_host "$2"
    ;;
  backup)
    backup_config
    ;;
  *)
    usage
    ;;
esac
