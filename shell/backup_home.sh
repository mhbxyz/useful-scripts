#!/bin/sh

# POSIX-compliant backup script with per-file progress, file compression, file integrity verification and file exclusion
# Author: Manoah Bernier

SOURCE_DIR="$HOME"
BACKUP_SUBDIR="backups"
CURRENT_USER=$(id -un)

MOUNT_BASES="/run/media/$CURRENT_USER /media/$CURRENT_USER /media /mnt"

DEFAULT_EXCLUDES=".cache .local node_modules __pycache__ .venv .npm .gradle .m2 .cargo .rustup .lmstudio Downloads Videos Games"

EXCLUDES=""
ADD_EXCLUDES=""
EXCLUDES_MODE="none"
EXCLUDE_FILE=""
COMPRESS="gzip"
KEEP_PARTIAL=0
VERIFY=0
DRYRUN=0
SCRIPT_NAME=$(basename "$0")

# Color codes
RESET="\033[0m"
GREEN="\033[1;32m"
RED="\033[1;31m"
YELLOW="\033[1;33m"
BLUE="\033[1;34m"

print_usage() {
    code="$1"
    [ -z "$code" ] && code=0
    printf "Usage:\n"
    printf "  %s --list\n" "$SCRIPT_NAME"
    printf "  %s [OPTIONS]\n\n" "$SCRIPT_NAME"
    printf "Options:\n"
    printf "  --list               List mounted drives\n"
    printf "  --default-excludes   Use default exclude directories (e.g., .cache, .local, etc.)\n"
    printf "  --add-excludes \"A B\" Add additional exclude directories on top of defaults\n"
    printf "  --excludes \"A B\"     Replace all excludes with specified directories\n"
    printf "  --exclude-file FILE  Specify a file containing exclude patterns (one per line)\n"
    printf "  --compress TYPE      Set compression: gzip (default), xz, zstd, none\n"
    printf "  --keep-partial       Keep partial backup file if interrupted\n"
    printf "  --verify             Verify archive integrity after backup completes\n"
    printf "  --dry-run            Perform dry-run listing without creating archive\n"
    printf "  -h, --help           Show this help message\n\n"
    printf "Example:\n"
    printf "  %s --default-excludes --add-excludes \"Downloads Videos\" --compress zstd --verify\n\n" "$SCRIPT_NAME"
    printf "This will back up your home directory, excluding default directories plus Downloads and Videos,\n"
    printf "compress using zstd, and verify the resulting archive.\n"
    exit "$code"
}

list_drives() {
    for base in $MOUNT_BASES; do
        [ -d "$base" ] && find "$base" -mindepth 1 -maxdepth 1 -type d -exec basename {} \;
    done
}

if ! command -v stdbuf >/dev/null 2>&1; then
    printf "${RED}❌ Error: 'stdbuf' is required but not installed. Please install coreutils.${RESET}\n"
    exit 1
fi

while [ $# -gt 0 ]; do
    case "$1" in
        --list)
            AVAILABLE_DRIVES=$(list_drives)
            [ -z "$AVAILABLE_DRIVES" ] && { printf "${RED}❌ Error: No mounted drives.${RESET}\n"; exit 1; }
            printf "${BLUE}💾 Mounted drives:${RESET}\n"
            printf "%s\n" "$AVAILABLE_DRIVES"
            exit 0
            ;;
        --default-excludes)
            [ "$EXCLUDES_MODE" != "manual" ] && EXCLUDES="$DEFAULT_EXCLUDES" && EXCLUDES_MODE="default"
            ;;
        --add-excludes)
            shift; [ -n "$1" ] && ADD_EXCLUDES="$ADD_EXCLUDES $1" || { printf "${RED}❌ Missing arg for --add-excludes${RESET}\n"; exit 1; }
            ;;
        --excludes)
            shift; [ -n "$1" ] && EXCLUDES="$1" && EXCLUDES_MODE="manual" || { printf "${RED}❌ Missing arg for --excludes${RESET}\n"; exit 1; }
            ;;
        --exclude-file)
            shift; [ -n "$1" ] && EXCLUDE_FILE="$1" || { printf "${RED}❌ Missing arg for --exclude-file${RESET}\n"; exit 1; }
            ;;
        --compress)
            shift; case "$1" in
                gzip|xz|zstd|none) COMPRESS="$1";;
                *) printf "${RED}❌ Invalid compression: $1${RESET}\n"; exit 1;;
            esac
            ;;
        --keep-partial) KEEP_PARTIAL=1 ;;
        --verify) VERIFY=1 ;;
        --dry-run) DRYRUN=1 ;;
        -h|--help) print_usage 0 ;;
        *) printf "${RED}❌ Unknown option: $1${RESET}\n"; print_usage 1 ;;
    esac
    shift
done

AVAILABLE_DRIVES=$(list_drives)
[ -z "$AVAILABLE_DRIVES" ] && { printf "${RED}❌ No mounted drives.${RESET}\n"; exit 1; }

printf "${BLUE}💾 Available drives:${RESET}\n"
printf "%s\n" "$AVAILABLE_DRIVES" | nl
printf "Enter drive number: "
read selection

DRIVE_NAME=$(echo "$AVAILABLE_DRIVES" | sed -n "${selection}p")
[ -z "$DRIVE_NAME" ] && { printf "${RED}❌ Invalid selection.${RESET}\n"; exit 1; }

for base in $MOUNT_BASES; do
    [ -d "$base/$DRIVE_NAME" ] && DEST_PATH="$base/$DRIVE_NAME" && break
done
[ -z "$DEST_PATH" ] && { printf "${RED}❌ Drive path not found.${RESET}\n"; exit 1; }

BACKUP_DIR="$DEST_PATH/$BACKUP_SUBDIR"
[ ! -d "$BACKUP_DIR" ] && mkdir -p "$BACKUP_DIR"

EXT=""; COMP_CMD=""
case "$COMPRESS" in
    gzip) COMP_CMD="gzip"; EXT=".gz";;
    xz)   COMP_CMD="xz"; EXT=".xz";;
    zstd) COMP_CMD="zstd"; EXT=".zst";;
    none) COMP_CMD="cat"; EXT="";;
esac

BACKUP_FILENAME="home_backup_$(date +%Y%m%d_%H%M%S).tar$EXT"

if [ "$EXCLUDES_MODE" = "manual" ]; then
    FINAL_EXCLUDES="$EXCLUDES"
elif [ "$EXCLUDES_MODE" = "default" ]; then
    FINAL_EXCLUDES="$EXCLUDES $ADD_EXCLUDES"
else
    FINAL_EXCLUDES="$ADD_EXCLUDES"
fi

EXCLUDE_PARAMS=""
printf "${BLUE}📂 Excluding:${RESET}\n"
[ -n "$FINAL_EXCLUDES" ] && for ex in $FINAL_EXCLUDES; do
    printf "  - %s\n" "$ex"
    EXCLUDE_PARAMS="$EXCLUDE_PARAMS --exclude=$ex"
done
[ -n "$EXCLUDE_FILE" ] && { printf "  - from file: %s\n" "$EXCLUDE_FILE"; EXCLUDE_PARAMS="$EXCLUDE_PARAMS --exclude-from=$EXCLUDE_FILE"; }

printf "${BLUE}📝 Counting files...${RESET}\n"
TOTAL_FILES=$(tar -cf - $EXCLUDE_PARAMS -C "$SOURCE_DIR" . | tar -tvf - | wc -l)
[ "$TOTAL_FILES" -eq 0 ] && { printf "${YELLOW}⚠️ Nothing to backup.${RESET}\n"; exit 1; }

TOTAL_SIZE=$(tar -cf - $EXCLUDE_PARAMS -C "$SOURCE_DIR" . | tar -tvf - | awk '{s+=$3} END {print s}')
AVAIL=$(df --output=avail "$DEST_PATH" | tail -1)
AVAIL_BYTES=$((AVAIL * 1024))
HR_SIZE=$(numfmt --to=iec $TOTAL_SIZE)
HR_AVAIL=$(numfmt --to=iec $AVAIL_BYTES)

printf "Estimated backup size: ${GREEN}%s${RESET}\n" "$HR_SIZE"
printf "Available space: ${GREEN}%s${RESET}\n" "$HR_AVAIL"

[ "$AVAIL_BYTES" -lt "$TOTAL_SIZE" ] && printf "${YELLOW}⚠️ Warning: Available space may be insufficient.${RESET}\n"

[ "$DRYRUN" -eq 1 ] && {
    printf "${BLUE}📝 Dry run list:${RESET}\n"
    tar -cvf /dev/null $EXCLUDE_PARAMS -C "$SOURCE_DIR" .
    exit 0
}

PIPE="/tmp/backup_pipe_$$"
mkfifo "$PIPE"

$COMP_CMD < "$PIPE" > "$BACKUP_DIR/$BACKUP_FILENAME" &
COMP_PID=$!

cleanup() {
    printf "\n${RED}🚨 Interrupt received. Cleaning up...${RESET}\n"
    [ -n "$COMP_PID" ] && kill "$COMP_PID" 2>/dev/null
    rm -f "$PIPE"
    [ "$KEEP_PARTIAL" -eq 0 ] && [ -f "$BACKUP_DIR/$BACKUP_FILENAME" ] && rm -f "$BACKUP_DIR/$BACKUP_FILENAME" && printf "${YELLOW}⚠️ Deleted incomplete archive.${RESET}\n"
    exit 1
}
trap cleanup INT TERM HUP

printf "${BLUE}📦 Starting backup...${RESET}\n"
count=0
spinner="/-\|"
i=0
cols=$(tput cols 2>/dev/null || echo 80)
prefix_len=30
max_fname=$((cols - prefix_len))
[ "$max_fname" -lt 10 ] && max_fname=10

stdbuf -eL tar -cvf "$PIPE" $EXCLUDE_PARAMS -C "$SOURCE_DIR" . 2>&1 |
while read -r filename; do
    count=$((count + 1))
    percent=$((count * 100 / TOTAL_FILES))
    [ "$percent" -gt 100 ] && percent=100
    c=$(printf "%s" "$spinner" | cut -c $(((i % 4) + 1)))
    i=$((i + 1))

    display_name="$filename"
    fname_len=${#display_name}
    if [ "$fname_len" -gt "$max_fname" ]; then
        display_name="...${display_name: -$max_fname}"
    fi

    printf "\r\033[K${GREEN}[%c] [%d/%d] [%d%%]${RESET}  %s" "$c" "$count" "$TOTAL_FILES" "$percent" "$display_name"
done

printf "\n"
wait "$COMP_PID"
result=$?

rm -f "$PIPE"
trap - INT TERM HUP

if [ "$result" -eq 0 ]; then
    printf "${GREEN}🎉 Backup completed: %s${RESET}\n" "$BACKUP_DIR/$BACKUP_FILENAME"
    if [ "$VERIFY" -eq 1 ]; then
        printf "${BLUE}🕵️ Verifying archive...${RESET}\n"
        if tar -tf "$BACKUP_DIR/$BACKUP_FILENAME" >/dev/null; then
            printf "${GREEN}✅ Verification OK${RESET}\n"
        else
            printf "${RED}❌ Verification failed${RESET}\n"
        fi
    fi
else
    printf "${RED}❌ Backup failed.${RESET}\n"
    exit 1
fi
