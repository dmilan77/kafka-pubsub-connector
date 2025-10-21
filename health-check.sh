#!/bin/bash

# Health check script for Kafka to Pub/Sub Connector

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}=====================================${NC}"
echo -e "${GREEN}Connector Health Check${NC}"
echo -e "${GREEN}=====================================${NC}"
echo ""

# Function to check service
check_service() {
    local name=$1
    local url=$2
    
    if curl -s "$url" > /dev/null 2>&1; then
        echo -e "${GREEN}✓${NC} $name is running"
        return 0
    else
        echo -e "${RED}✗${NC} $name is not running"
        return 1
    fi
}

# Function to check Docker container
check_container() {
    local name=$1
    
    if docker ps --filter "name=$name" --format '{{.Names}}' | grep -q "$name"; then
        echo -e "${GREEN}✓${NC} Container $name is running"
        return 0
    else
        echo -e "${RED}✗${NC} Container $name is not running"
        return 1
    fi
}

# Check Docker containers
echo -e "${YELLOW}Checking Docker containers...${NC}"
check_container "kafka-zookeeper"
check_container "kafka-broker"
check_container "kafka-connect"
check_container "kafka-ui"
echo ""

# Check services
echo -e "${YELLOW}Checking services...${NC}"
check_service "Kafka Connect" "http://localhost:8083/"
check_service "Kafka UI" "http://localhost:8080/"
echo ""

# Check Kafka broker
echo -e "${YELLOW}Checking Kafka broker...${NC}"
if docker exec kafka-broker kafka-broker-api-versions --bootstrap-server localhost:9092 > /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} Kafka broker is responsive"
else
    echo -e "${RED}✗${NC} Kafka broker is not responsive"
fi
echo ""

# Check connector
echo -e "${YELLOW}Checking connector...${NC}"
CONNECTOR_STATUS=$(curl -s http://localhost:8083/connectors/pubsub-sink-connector/status 2>/dev/null)

if [ -n "$CONNECTOR_STATUS" ]; then
    STATE=$(echo "$CONNECTOR_STATUS" | jq -r '.connector.state' 2>/dev/null)
    
    if [ "$STATE" = "RUNNING" ]; then
        echo -e "${GREEN}✓${NC} Connector is RUNNING"
        
        # Check tasks
        TASK_COUNT=$(echo "$CONNECTOR_STATUS" | jq '.tasks | length' 2>/dev/null)
        RUNNING_TASKS=$(echo "$CONNECTOR_STATUS" | jq '[.tasks[] | select(.state=="RUNNING")] | length' 2>/dev/null)
        
        echo -e "  Tasks: $RUNNING_TASKS/$TASK_COUNT running"
        
        # Show task details
        echo "$CONNECTOR_STATUS" | jq -r '.tasks[] | "  Task \(.id): \(.state)"' 2>/dev/null
    else
        echo -e "${RED}✗${NC} Connector state: $STATE"
        echo "$CONNECTOR_STATUS" | jq '.'
    fi
else
    echo -e "${RED}✗${NC} Connector not deployed or not accessible"
fi
echo ""

# List topics
echo -e "${YELLOW}Kafka topics:${NC}"
docker exec kafka-broker kafka-topics --list --bootstrap-server localhost:9092 2>/dev/null | sed 's/^/  /'
echo ""

# Show connector configuration
echo -e "${YELLOW}Connector configuration:${NC}"
if curl -s http://localhost:8083/connectors/pubsub-sink-connector 2>/dev/null | jq -e '.config' > /dev/null 2>&1; then
    curl -s http://localhost:8083/connectors/pubsub-sink-connector | jq '.config' | sed 's/^/  /'
else
    echo -e "  ${RED}Connector configuration not available${NC}"
fi
echo ""

# Summary
echo -e "${GREEN}=====================================${NC}"
echo -e "${GREEN}Health Check Complete${NC}"
echo -e "${GREEN}=====================================${NC}"
echo ""
echo -e "${YELLOW}Useful commands:${NC}"
echo -e "  View logs:         docker logs -f kafka-connect"
echo -e "  Restart connector: curl -X POST http://localhost:8083/connectors/pubsub-sink-connector/restart"
echo -e "  Stop environment:  ./stop-kafka.sh"
