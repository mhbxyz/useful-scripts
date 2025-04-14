#!/bin/bash

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

usage() {
    echo "Usage: $(basename "$0") -e email [-n key_name] [-t key_type] [-m comment] [-p true|false] [-c true|false] [-h host] [-a alias]"
    echo "  -e  Email associated with the key (required)"
    echo "  -n  Key name (default: id_key)"
    echo "  -t  Key type: ed25519 or rsa (default: ed25519)"
    echo "  -m  Comment to add to key (optional)"
    echo "  -p  Add to ssh-agent (true/false, default: false)"
    echo "  -c  Copy public key to clipboard (true/false, default: true)"
    echo "  -h  Host for ~/.ssh/config (e.g., github.com)"
    echo "  -a  Host alias (optional, default: same as host)"
    exit 1
}

while getopts ":e:n:t:m:p:c:h:a:" opt; do
  case ${opt} in
    e ) EMAIL="$OPTARG" ;;
    n ) KEY_NAME="$OPTARG" ;;
    t ) KEY_TYPE="$OPTARG" ;;
    m ) COMMENT="$OPTARG" ;;
    p ) ADD_TO_AGENT="$OPTARG" ;;
    c ) COPY_TO_CLIPBOARD="$OPTARG" ;;
    h ) SSH_HOST="$OPTARG" ;;
    a ) SSH_ALIAS="$OPTARG" ;;
    \? ) usage ;;
  esac
done

if [ -z "$EMAIL" ]; then
    usage
fi

SSH_DIR="$HOME/.ssh"
KEY_PATH="$SSH_DIR/$KEY_NAME"
FULL_COMMENT="$EMAIL"
[ -n "$COMMENT" ] && FULL_COMMENT="$EMAIL ($COMMENT)"

mkdir -p "$SSH_DIR"
chmod 700 "$SSH_DIR"

# Generate key
echo "🔐 Generating $KEY_TYPE key at $KEY_PATH..."
if [ "$KEY_TYPE" = "rsa" ]; then
    ssh-keygen -t rsa -b 4096 -C "$FULL_COMMENT" -f "$KEY_PATH"
else
    ssh-keygen -t "$KEY_TYPE" -C "$FULL_COMMENT" -f "$KEY_PATH"
fi

# Add to SSH agent
if [ "$ADD_TO_AGENT" = true ]; then
    if ssh-add "$KEY_PATH"; then
        echo "🔁 Key added to existing SSH agent."
    else
        echo "⚠️  Could not add key to agent. You may need to run: eval \$(ssh-agent) && ssh-add $KEY_PATH"
    fi
fi

# Copy to clipboard
if [ "$COPY_TO_CLIPBOARD" = true ]; then
    echo "📋 Copying public key to clipboard..."
    if command -v pbcopy &> /dev/null; then
        pbcopy < "$KEY_PATH.pub"
    elif command -v xclip &> /dev/null; then
        xclip -sel clip < "$KEY_PATH.pub"
    elif command -v clip &> /dev/null; then
        clip < "$KEY_PATH.pub"
    else
        echo "⚠️ Clipboard tool not found."
    fi
fi

# Add SSH config block
if [ -n "$SSH_HOST" ]; then
    SSH_ALIAS="${SSH_ALIAS:-$SSH_HOST}"
    echo "🧩 Adding SSH config block for host: $SSH_ALIAS"

    CONFIG_BLOCK="\nHost $SSH_ALIAS
  HostName $SSH_HOST
  User git
  IdentityFile $KEY_PATH
  IdentitiesOnly yes\n"

    # Prevent duplicates
    if ! grep -q "Host $SSH_ALIAS" "$SSH_DIR/config" 2>/dev/null; then
        echo -e "$CONFIG_BLOCK" >> "$SSH_DIR/config"
        chmod 600 "$SSH_DIR/config"
        echo "✅ SSH config updated with alias '$SSH_ALIAS'"
    else
        echo "⚠️ SSH config already contains a block for '$SSH_ALIAS'. Skipped."
    fi
fi

echo -e "\n✅ Key generation complete."
echo "🔑 Private key: $KEY_PATH"
echo "📝 Comment: $FULL_COMMENT"
echo "📎 Public key: $(cat "$KEY_PATH.pub")"
