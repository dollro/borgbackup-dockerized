#!/bin/bash

# Wrapper script to run the containerized backup
# This script should be run from the borgbackup directory

set -e

# Cleanup on interruption
cleanup() {
    echo -e "\n${YELLOW}Interrupted, stopping container...${NC}"
    sudo docker compose down --remove-orphans 2>/dev/null
    exit 130
}
trap cleanup INT TERM

# Colors for output (respect NO_COLOR standard: https://no-color.org/)
if [ -n "${NO_COLOR}" ]; then
    RED='' GREEN='' YELLOW='' NC=''
else
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    NC='\033[0m'
fi

echo -e "${GREEN}================================================${NC}"
echo -e "${GREEN}Starting Dockerized BorgBackup${NC}"
echo -e "${GREEN}================================================${NC}"

# Check if we're in the right directory
if [ ! -f "docker-compose.yml" ]; then
    echo -e "${RED}Error: docker-compose.yml not found!${NC}"
    echo "Please run this script from the borgbackup directory"
    exit 1
fi

# Check if .env file exists
if [ ! -f ".env" ]; then
    echo -e "${RED}Error: .env file not found!${NC}"
    echo "Please copy .env.example to .env and configure it first"
    exit 1
fi

# Prevent concurrent execution (protects borg repo from corruption)
LOCK_FILE="/tmp/borgbackup.lock"
exec 200>"$LOCK_FILE"
if ! flock -n 200; then
    echo -e "${RED}Error: Another backup is already running${NC}"
    echo "Lock file: $LOCK_FILE"
    exit 1
fi

# Verify Docker daemon is running
if ! docker info >/dev/null 2>&1; then
    echo -e "${RED}Error: Docker daemon is not running${NC}"
    echo "Start Docker with: sudo systemctl start docker"
    exit 1
fi

# Ensure writable directories exist on host (mounted into container for logs/dumps)
mkdir -p /backup/log /backup/dump 2>/dev/null || sudo mkdir -p /backup/log /backup/dump

# Rebuild the image if needed (in case backup.sh was updated)
echo -e "${YELLOW}Building/updating Docker image...${NC}"
if ! docker compose build --quiet; then
    echo -e "${RED}Error: Docker image build failed${NC}"
    exit 1
fi

# Run the backup
echo -e "${GREEN}Running backup script...${NC}"
# Disable pseudo-TTY allocation when not attached to a terminal (e.g. cron),
# otherwise `docker compose run` fails with "the input device is not a TTY".
# Keep the TTY for interactive runs so prompts (e.g. BORG_AUTO_BREAK_LOCK=manual) work.
TTY_FLAG=""
[ -t 1 ] || TTY_FLAG="-T"
sudo docker compose run --rm $TTY_FLAG borgbackup /usr/sbin/backup.sh

# Get exit code
EXIT_CODE=$?

if [ $EXIT_CODE -eq 0 ]; then
    echo -e "${GREEN}================================================${NC}"
    echo -e "${GREEN}Backup completed successfully!${NC}"
    echo -e "${GREEN}================================================${NC}"
elif [ $EXIT_CODE -eq 1 ]; then
    echo -e "${YELLOW}================================================${NC}"
    echo -e "${YELLOW}Backup completed with warnings${NC}"
    echo -e "${YELLOW}================================================${NC}"
else
    echo -e "${RED}================================================${NC}"
    echo -e "${RED}Backup failed with exit code: $EXIT_CODE${NC}"
    echo -e "${RED}================================================${NC}"
fi

exit $EXIT_CODE
