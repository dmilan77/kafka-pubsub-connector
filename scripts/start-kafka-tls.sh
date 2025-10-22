#!/bin/bash
# Script to start Kafka with TLS/SSL enabled

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}=====================================${NC}"
echo -e "${GREEN}Starting Kafka with TLS/SSL Support${NC}"
echo -e "${GREEN}=====================================${NC}"

# Check if certificates exist
if [ ! -d "kafka-certs" ] || [ ! -f "kafka-certs/kafka.server.keystore.jks" ]; then
    echo -e "${YELLOW}TLS certificates not found. Generating certificates...${NC}"
    ./scripts/generate-kafka-tls-certs.sh
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}Failed to generate certificates. Exiting.${NC}"
        exit 1
    fi
else
    echo -e "${GREEN}✓ TLS certificates found${NC}"
fi

# Create credentials file for Docker
echo -e "${YELLOW}Creating credentials file...${NC}"
echo "kafka-secret" > kafka-certs/kafka-ssl-credentials.txt
chmod 600 kafka-certs/kafka-ssl-credentials.txt
echo -e "${GREEN}✓ Credentials file created${NC}"

# Stop any running containers
echo -e "${YELLOW}Stopping any running Kafka containers...${NC}"
docker-compose -f docker-compose-tls.yml down 2>/dev/null || true

# Start services
echo -e "${YELLOW}Starting Kafka services with TLS...${NC}"
docker-compose -f docker-compose-tls.yml up -d

# Wait for services to be ready
echo -e "${YELLOW}Waiting for services to start...${NC}"
sleep 10

# Check Zookeeper
echo -e "${YELLOW}Checking Zookeeper...${NC}"
if docker ps | grep -q kafka-zookeeper; then
    echo -e "${GREEN}✓ Zookeeper is running${NC}"
else
    echo -e "${RED}✗ Zookeeper failed to start${NC}"
    exit 1
fi

# Check Kafka Broker
echo -e "${YELLOW}Checking Kafka Broker...${NC}"
MAX_WAIT=60
ELAPSED=0
while [ $ELAPSED -lt $MAX_WAIT ]; do
    if docker logs kafka-broker 2>&1 | grep -q "started (kafka.server.KafkaServer)"; then
        echo -e "${GREEN}✓ Kafka Broker is running${NC}"
        break
    fi
    sleep 2
    ELAPSED=$((ELAPSED + 2))
    echo -n "."
done
echo ""

if [ $ELAPSED -ge $MAX_WAIT ]; then
    echo -e "${RED}✗ Kafka Broker failed to start within ${MAX_WAIT} seconds${NC}"
    echo -e "${YELLOW}Checking logs...${NC}"
    docker logs kafka-broker --tail 50
    exit 1
fi

# Check Kafka Connect
echo -e "${YELLOW}Checking Kafka Connect...${NC}"
MAX_WAIT=90
ELAPSED=0
while [ $ELAPSED -lt $MAX_WAIT ]; do
    if curl -s http://localhost:8083/ > /dev/null 2>&1; then
        echo -e "${GREEN}✓ Kafka Connect is running${NC}"
        break
    fi
    sleep 2
    ELAPSED=$((ELAPSED + 2))
    echo -n "."
done
echo ""

if [ $ELAPSED -ge $MAX_WAIT ]; then
    echo -e "${RED}✗ Kafka Connect failed to start within ${MAX_WAIT} seconds${NC}"
    echo -e "${YELLOW}Checking logs...${NC}"
    docker logs kafka-connect --tail 50
    exit 1
fi

# Check Kafka UI
echo -e "${YELLOW}Checking Kafka UI...${NC}"
if docker ps | grep -q kafka-ui; then
    echo -e "${GREEN}✓ Kafka UI is running${NC}"
else
    echo -e "${YELLOW}⚠ Kafka UI may not be running${NC}"
fi

echo ""
echo -e "${GREEN}=====================================${NC}"
echo -e "${GREEN}Kafka Services Started Successfully!${NC}"
echo -e "${GREEN}=====================================${NC}"
echo ""
echo -e "${YELLOW}Service Endpoints:${NC}"
echo -e "  Kafka (PLAINTEXT): ${GREEN}localhost:9092${NC}"
echo -e "  Kafka (SSL/TLS):   ${GREEN}localhost:9093${NC}"
echo -e "  Kafka Connect:     ${GREEN}http://localhost:8083${NC}"
echo -e "  Kafka UI:          ${GREEN}http://localhost:8080${NC}"
echo ""
echo -e "${YELLOW}SSL/TLS Configuration:${NC}"
echo -e "  Keystore:    kafka-certs/kafka.server.keystore.jks"
echo -e "  Truststore:  kafka-certs/kafka.server.truststore.jks"
echo -e "  Password:    kafka-secret"
echo ""
echo -e "${YELLOW}Testing SSL Connection:${NC}"
echo -e "  # Test with openssl"
echo -e "  openssl s_client -connect localhost:9093 -cert kafka-certs/kafka-client-cert-signed -key kafka-certs/ca-key"
echo ""
echo -e "  # Test with kafka-console-producer (SSL)"
echo -e "  docker exec -it kafka-broker kafka-console-producer --bootstrap-server kafka:29093 \\"
echo -e "    --topic test-topic \\"
echo -e "    --producer.config /etc/kafka/secrets/client-ssl.properties"
echo ""
echo -e "${YELLOW}View logs:${NC}"
echo -e "  docker logs -f kafka-broker      # Kafka broker logs"
echo -e "  docker logs -f kafka-connect     # Kafka Connect logs"
echo ""
echo -e "${YELLOW}Stop services:${NC}"
echo -e "  docker-compose -f docker-compose-tls.yml down"
echo ""
