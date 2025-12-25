#!/bin/bash

# Wrapper script to run the containerized backup
# This script should be run from the borgbackup directory

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

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

# Rebuild the image if needed (in case backup.sh was updated)
echo -e "${YELLOW}Building/updating Docker image...${NC}"
docker compose build

# Run the backup
echo -e "${GREEN}Running backup script...${NC}"
sudo docker compose run --rm borgbackup /usr/sbin/backup.sh

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
