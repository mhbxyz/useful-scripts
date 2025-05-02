#!/bin/sh

# Script to generate an ssh key
# Author: Manoah Bernier

KEY_TYPE="ed25519"
KEY_NAME="id_key"
EMAIL=""
COMMENT=""
ADD_TO_AGENT=false
COPY_TO_CLIPBOARD=true
SSH_HOST=""
SSH_ALIAS=""

show_help() {
  prog=$(basename "$0")
  printf "%s – Generate an SSH key and optionally configure SSH\n\n" "$prog"
  printf "Usage:\n"
  printf "  %s -e email [options]\n\n" "$prog"
  printf "Options:\n"
  printf "  -e  Email associated with the key (required)\n"
  printf "  -n  Key name (default: id_key)\n"
  printf "  -t  Key type: ed25519 or rsa (default: ed25519)\n"
  printf "  -m  Comment to add to key (optional)\n"
  printf "  -p  Add to ssh-agent (true/false, default: false)\n"
  printf "  -c  Copy public key to clipboard (true/false, default: true)\n"
  printf "  -h  Host for ~/.ssh/config (e.g., github.com)\n"
  printf "  -a  Host alias (default: same as host)\n\n"
  printf "Example:\n"
  printf "  %s -e user@example.com -n id_github -h github.com -a github\n\n" "$prog"
  printf "Notes:\n"
  printf "  This script will create ~/.ssh/config if needed.\n"
  printf "  Backup your SSH config manually if modifying an existing one.\n"
  exit 0
}

# If called with "help" or "-h" or "--help" → show help
if [ $# -eq 1 ]; then
  case "$1" in
    help|-h|--help)
      show_help
      ;;
  esac
fi

while getopts ":e:n:t:m:p:c:h:a:" opt; do
  case "$opt" in
    e) EMAIL="$OPTARG" ;;
    n) KEY_NAME="$OPTARG" ;;
    t) KEY_TYPE="$OPTARG" ;;
    m) COMMENT="$OPTARG" ;;
    p) ADD_TO_AGENT="$OPTARG" ;;
    c) COPY_TO_CLIPBOARD="$OPTARG" ;;
    h) SSH_HOST="$OPTARG" ;;
    a) SSH_ALIAS="$OPTARG" ;;
    *) show_help ;;
  esac
done

if [ -z "$EMAIL" ]; then
  show_help
fi

SSH_DIR="$HOME/.ssh"
KEY_PATH="$SSH_DIR/$KEY_NAME"
FULL_COMMENT="$EMAIL"
if [ -n "$COMMENT" ]; then
  FULL_COMMENT="$EMAIL ($COMMENT)"
fi

mkdir -p "$SSH_DIR"
chmod 700 "$SSH_DIR"

# Generate key
printf "🔐 Generating %s key at %s...\n" "$KEY_TYPE" "$KEY_PATH"
if [ "$KEY_TYPE" = "rsa" ]; then
  ssh-keygen -t rsa -b 4096 -C "$FULL_COMMENT" -f "$KEY_PATH"
else
  ssh-keygen -t "$KEY_TYPE" -C "$FULL_COMMENT" -f "$KEY_PATH"
fi

# Add to SSH agent
if [ "$ADD_TO_AGENT" = "true" ]; then
  if ssh-add "$KEY_PATH"; then
    printf "🔁 Key added to existing SSH agent.\n"
  else
    printf "⚠️  Could not add key to agent.\n"
    printf "You may need to run: eval \$(ssh-agent) && ssh-add %s\n" "$KEY_PATH"
  fi
fi

# Copy to clipboard
if [ "$COPY_TO_CLIPBOARD" = "true" ]; then
  printf "📋 Copying public key to clipboard...\n"
  if command -v pbcopy >/dev/null 2>&1; then
    pbcopy < "$KEY_PATH.pub"
  elif command -v xclip >/dev/null 2>&1; then
    xclip -sel clip < "$KEY_PATH.pub"
  elif command -v clip >/dev/null 2>&1; then
    clip < "$KEY_PATH.pub"
  else
    printf "⚠️ Clipboard tool not found.\n"
  fi
fi

# Add SSH config block
if [ -n "$SSH_HOST" ]; then
  if [ -z "$SSH_ALIAS" ]; then
    SSH_ALIAS="$SSH_HOST"
  fi
  printf "🧩 Adding SSH config block for host: %s\n" "$SSH_ALIAS"

  CONFIG_TMP=$(mktemp)
  {
    printf "\n"
    printf "Host %s\n" "$SSH_ALIAS"
    printf "  HostName %s\n" "$SSH_HOST"
    printf "  User git\n"
    printf "  IdentityFile %s\n" "$KEY_PATH"
    printf "  IdentitiesOnly yes\n"
  } > "$CONFIG_TMP"

  CONFIG_FILE="$SSH_DIR/config"
  if [ ! -f "$CONFIG_FILE" ]; then
    touch "$CONFIG_FILE"
    chmod 600 "$CONFIG_FILE"
  fi

  if ! grep -q "Host $SSH_ALIAS" "$CONFIG_FILE" 2>/dev/null; then
    cat "$CONFIG_TMP" >> "$CONFIG_FILE"
    printf "✅ SSH config updated with alias '%s'\n" "$SSH_ALIAS"
  else
    printf "⚠️ SSH config already contains a block for '%s'. Skipped.\n" "$SSH_ALIAS"
  fi
  rm "$CONFIG_TMP"
fi

printf "\n✅ Key generation complete.\n"
printf "🔑 Private key: %s\n" "$KEY_PATH"
printf "📝 Comment: %s\n" "$FULL_COMMENT"
printf "📎 Public key:\n"
cat "$KEY_PATH.pub"
