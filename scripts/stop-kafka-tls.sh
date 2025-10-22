#!/bin/bash
# Stop Kafka services running with TLS configuration

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}Stopping Kafka TLS services...${NC}"

docker-compose -f docker-compose-tls.yml down

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Kafka TLS services stopped${NC}"
else
    echo -e "${RED}✗ Failed to stop services${NC}"
    exit 1
fi

echo -e "${YELLOW}Checking for running containers...${NC}"
RUNNING=$(docker ps --format '{{.Names}}' | grep -E 'kafka|zookeeper')

if [ -z "$RUNNING" ]; then
    echo -e "${GREEN}✓ All Kafka services stopped${NC}"
else
    echo -e "${YELLOW}Still running:${NC}"
    echo "$RUNNING"
fi
