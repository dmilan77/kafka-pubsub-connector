#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Stopping Kafka environment...${NC}"

docker-compose down

echo -e "${GREEN}Kafka environment stopped!${NC}"

# Optional: Clean up volumes
read -p "Do you want to clean up all data volumes? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Removing volumes...${NC}"
    docker-compose down -v
    echo -e "${GREEN}Volumes removed!${NC}"
fi
