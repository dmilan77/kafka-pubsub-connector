#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Accept config file as parameter, default to connector-config.json
CONFIG_FILE="${1:-config/connector-config.json}"

if [ ! -f "$CONFIG_FILE" ]; then
    echo -e "${RED}Error: Configuration file not found at $CONFIG_FILE${NC}"
    echo -e "${YELLOW}Please create the configuration file first. See config/connector-config.example.json${NC}"
    exit 1
fi

# Extract connector name from config file
CONNECTOR_NAME=$(jq -r '.name' "$CONFIG_FILE")
if [ -z "$CONNECTOR_NAME" ] || [ "$CONNECTOR_NAME" = "null" ]; then
    echo -e "${RED}Error: Could not extract connector name from $CONFIG_FILE${NC}"
    exit 1
fi

echo -e "${YELLOW}Deploying Pub/Sub Sink Connector...${NC}"

# Check if Kafka Connect is running
if ! curl -s http://localhost:8083/ > /dev/null 2>&1; then
    echo -e "${RED}Error: Kafka Connect is not running. Start it with ./start-kafka.sh first.${NC}"
    exit 1
fi

# Deploy the connector
RESPONSE=$(curl -s -X POST -H "Content-Type: application/json" \
    --data @"$CONFIG_FILE" \
    http://localhost:8083/connectors)

if echo "$RESPONSE" | grep -q "error_code"; then
    echo -e "${RED}Failed to deploy connector:${NC}"
    echo "$RESPONSE" | jq '.'
    exit 1
else
    echo -e "${GREEN}Connector deployed successfully!${NC}"
    echo "$RESPONSE" | jq '.'
fi

# Check connector status
sleep 2
echo -e "\n${YELLOW}Connector Status:${NC}"
curl -s "http://localhost:8083/connectors/${CONNECTOR_NAME}/status" | jq '.'

echo -e "\n${GREEN}Connector is running!${NC}"
echo -e "${YELLOW}You can now produce messages to the Kafka topic and they will be sent to Pub/Sub.${NC}"
