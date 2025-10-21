#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=====================================${NC}"
echo -e "${GREEN}Starting Local Kafka Environment${NC}"
echo -e "${GREEN}=====================================${NC}"

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo -e "${RED}Error: Docker is not running. Please start Docker first.${NC}"
    exit 1
fi

# Create connector-jars directory if it doesn't exist
if [ ! -d "connector-jars" ]; then
    echo -e "${YELLOW}Creating connector-jars directory...${NC}"
    mkdir -p connector-jars
fi

# Build the connector if pom.xml exists
if [ -f "pom.xml" ]; then
    echo -e "${YELLOW}Building Kafka Pub/Sub Connector...${NC}"
    mvn clean package -DskipTests
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Connector built successfully!${NC}"
        
        # Copy the jar with dependencies to connector-jars directory
        echo -e "${YELLOW}Copying connector JAR to connector-jars...${NC}"
        cp target/*-jar-with-dependencies.jar connector-jars/
    else
        echo -e "${RED}Failed to build connector. Continuing without it...${NC}"
    fi
fi

# Start Docker Compose
echo -e "${YELLOW}Starting Docker containers...${NC}"
docker-compose up -d

# Wait for services to be ready
echo -e "${YELLOW}Waiting for services to start...${NC}"
sleep 10

# Check if Kafka is ready
echo -e "${YELLOW}Checking Kafka broker status...${NC}"
for i in {1..30}; do
    if docker exec kafka-broker kafka-broker-api-versions --bootstrap-server localhost:9092 > /dev/null 2>&1; then
        echo -e "${GREEN}Kafka broker is ready!${NC}"
        break
    fi
    echo "Waiting for Kafka broker... ($i/30)"
    sleep 2
done

# Check if Kafka Connect is ready
echo -e "${YELLOW}Checking Kafka Connect status...${NC}"
for i in {1..30}; do
    if curl -s http://localhost:8083/ > /dev/null 2>&1; then
        echo -e "${GREEN}Kafka Connect is ready!${NC}"
        break
    fi
    echo "Waiting for Kafka Connect... ($i/30)"
    sleep 2
done

# Create test topic
echo -e "${YELLOW}Creating test topic 'test-topic'...${NC}"
docker exec kafka-broker kafka-topics --create \
    --topic test-topic \
    --bootstrap-server localhost:9092 \
    --replication-factor 1 \
    --partitions 3 \
    --if-not-exists

echo -e "${GREEN}=====================================${NC}"
echo -e "${GREEN}Kafka Environment Started!${NC}"
echo -e "${GREEN}=====================================${NC}"
echo ""
echo -e "${YELLOW}Services:${NC}"
echo -e "  Kafka Broker:    localhost:9092"
echo -e "  Kafka Connect:   http://localhost:8083"
echo -e "  Kafka UI:        http://localhost:8080"
echo -e "  Zookeeper:       localhost:2181"
echo ""
echo -e "${YELLOW}Useful Commands:${NC}"
echo -e "  List topics:           docker exec kafka-broker kafka-topics --list --bootstrap-server localhost:9092"
echo -e "  Produce messages:      docker exec -it kafka-broker kafka-console-producer --topic test-topic --bootstrap-server localhost:9092"
echo -e "  Consume messages:      docker exec -it kafka-broker kafka-console-consumer --topic test-topic --from-beginning --bootstrap-server localhost:9092"
echo -e "  List connectors:       curl http://localhost:8083/connectors"
echo -e "  Stop environment:      docker-compose down"
echo ""
echo -e "${GREEN}To deploy the Pub/Sub connector, see config/connector-config.json${NC}"
