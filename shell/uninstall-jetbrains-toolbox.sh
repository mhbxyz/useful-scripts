#!/usr/bin/env sh

echo "=== JetBrains Toolbox Uninstaller for Linux ==="
echo "Starting uninstallation process..."

# Define paths (space-separated strings instead of arrays)
TOOLBOX_DIRS="$HOME/.local/share/JetBrains/Toolbox \
$HOME/.config/JetBrains/Toolbox \
$HOME/.cache/JetBrains/Toolbox \
$HOME/.toolbox"

IDE_DIR="$HOME/.local/share/JetBrains/Toolbox/apps"
CONFIG_DIR="$HOME/.config/JetBrains"
CACHE_DIR="$HOME/.cache/JetBrains"

echo ""
echo "-> Removing JetBrains Toolbox directories..."

for dir in $TOOLBOX_DIRS; do
    if [ -d "$dir" ]; then
        rm -rf "$dir"
        echo "Deleted: $dir"
    else
        echo "Not found: $dir (already removed)"
    fi
done

# Prompt to remove installed IDEs
echo ""
printf "Do you want to remove all IDEs installed via JetBrains Toolbox? (y/N): "
read remove_ides
case "$remove_ides" in
    y|Y)
        if [ -d "$IDE_DIR" ]; then
            rm -rf "$IDE_DIR"
            echo "Deleted IDE installations at: $IDE_DIR"
        else
            echo "No IDE installations found at: $IDE_DIR"
        fi
        ;;
    *)
        echo "Skipping IDE removal."
        ;;
esac

# Prompt to remove configs
echo ""
printf "Do you want to remove ALL JetBrains user configs (this will affect all JetBrains IDEs)? (y/N): "
read remove_configs
case "$remove_configs" in
    y|Y)
        if [ -d "$CONFIG_DIR" ]; then
            rm -rf "$CONFIG_DIR"
            echo "Deleted configs at: $CONFIG_DIR"
        else
            echo "No configs found at: $CONFIG_DIR"
        fi

        if [ -d "$CACHE_DIR" ]; then
            rm -rf "$CACHE_DIR"
            echo "Deleted caches at: $CACHE_DIR"
        else
            echo "No caches found at: $CACHE_DIR"
        fi
        ;;
    *)
        echo "Skipping JetBrains config and cache removal."
        ;;
esac

echo ""
echo "✅ Uninstallation complete."
