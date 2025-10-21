#!/bin/bash

# Test script for Kafka to Pub/Sub Connector

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}=====================================${NC}"
echo -e "${GREEN}Testing Kafka to Pub/Sub Connector${NC}"
echo -e "${GREEN}=====================================${NC}"

# Check if Kafka is running
if ! docker ps | grep -q kafka-broker; then
    echo -e "${RED}Error: Kafka is not running. Start it with ./start-kafka.sh${NC}"
    exit 1
fi

# Check if connector is deployed
if ! curl -s http://localhost:8083/connectors | grep -q "pubsub-sink-connector"; then
    echo -e "${RED}Error: Connector is not deployed. Deploy it with ./deploy-connector.sh${NC}"
    exit 1
fi

echo -e "${YELLOW}Producing test messages to Kafka...${NC}"

# Produce 5 test messages
for i in {1..5}; do
    MESSAGE="{\"id\": $i, \"message\": \"Test message $i\", \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}"
    echo "$MESSAGE" | docker exec -i kafka-broker kafka-console-producer \
        --topic test-topic \
        --bootstrap-server localhost:9092
    echo -e "  Sent: $MESSAGE"
    sleep 1
done

echo -e "${GREEN}Test messages sent!${NC}"
echo ""
echo -e "${YELLOW}Checking connector status...${NC}"
curl -s http://localhost:8083/connectors/pubsub-sink-connector/status | jq '.'

echo ""
echo -e "${GREEN}Test completed!${NC}"
echo -e "${YELLOW}To verify messages in Pub/Sub, run:${NC}"
echo -e "  gcloud pubsub subscriptions pull kafka-messages-sub --limit=10 --auto-ack --project=YOUR_PROJECT_ID"
