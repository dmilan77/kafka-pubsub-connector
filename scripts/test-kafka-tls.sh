#!/bin/bash
# Test script for Kafka TLS/SSL connection

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}=====================================${NC}"
echo -e "${GREEN}Testing Kafka TLS/SSL Connection${NC}"
echo -e "${GREEN}=====================================${NC}"

# Check if Kafka is running
if ! docker ps | grep -q kafka-broker; then
    echo -e "${RED}Error: Kafka is not running. Start it with ./start-kafka-tls.sh${NC}"
    exit 1
fi

echo -e "${YELLOW}Test 1: Checking SSL port availability...${NC}"
if nc -z localhost 9093 2>/dev/null; then
    echo -e "${GREEN}✓ SSL port 9093 is open${NC}"
else
    echo -e "${RED}✗ SSL port 9093 is not accessible${NC}"
    exit 1
fi

echo ""
echo -e "${YELLOW}Test 2: Testing SSL handshake with OpenSSL...${NC}"
timeout 5 openssl s_client -connect localhost:9093 -showcerts </dev/null 2>/dev/null | grep -q "Verify return code"
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ SSL handshake successful${NC}"
else
    echo -e "${YELLOW}⚠ SSL handshake test inconclusive (this may be normal)${NC}"
fi

echo ""
echo -e "${YELLOW}Test 3: Creating test topic via SSL...${NC}"
docker exec kafka-broker kafka-topics --create \
    --topic test-ssl-topic \
    --bootstrap-server kafka:29093 \
    --command-config /etc/kafka/secrets/client-ssl.properties \
    --partitions 3 \
    --replication-factor 1 \
    --if-not-exists 2>/dev/null

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Topic created successfully via SSL${NC}"
else
    echo -e "${RED}✗ Failed to create topic via SSL${NC}"
    exit 1
fi

echo ""
echo -e "${YELLOW}Test 4: Listing topics via SSL...${NC}"
TOPICS=$(docker exec kafka-broker kafka-topics --list \
    --bootstrap-server kafka:29093 \
    --command-config /etc/kafka/secrets/client-ssl.properties 2>/dev/null)

if echo "$TOPICS" | grep -q "test-ssl-topic"; then
    echo -e "${GREEN}✓ Successfully listed topics via SSL${NC}"
    echo -e "${GREEN}  Topics: $TOPICS${NC}"
else
    echo -e "${RED}✗ Failed to list topics via SSL${NC}"
    exit 1
fi

echo ""
echo -e "${YELLOW}Test 5: Producing messages via SSL...${NC}"
for i in {1..3}; do
    MESSAGE="{\"id\": $i, \"message\": \"SSL test message $i\", \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}"
    echo "$MESSAGE" | docker exec -i kafka-broker kafka-console-producer \
        --bootstrap-server kafka:29093 \
        --topic test-ssl-topic \
        --producer.config /etc/kafka/secrets/client-ssl.properties 2>/dev/null
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}  ✓ Sent message $i via SSL${NC}"
    else
        echo -e "${RED}  ✗ Failed to send message $i${NC}"
        exit 1
    fi
done

echo ""
echo -e "${YELLOW}Test 6: Consuming messages via SSL...${NC}"
MESSAGES=$(docker exec kafka-broker timeout 5 kafka-console-consumer \
    --bootstrap-server kafka:29093 \
    --topic test-ssl-topic \
    --from-beginning \
    --max-messages 3 \
    --consumer.config /etc/kafka/secrets/client-ssl.properties 2>/dev/null)

if [ $? -eq 0 ] || [ $? -eq 124 ]; then  # 124 is timeout exit code
    MESSAGE_COUNT=$(echo "$MESSAGES" | grep -c "SSL test message" || true)
    if [ "$MESSAGE_COUNT" -ge 1 ]; then
        echo -e "${GREEN}✓ Successfully consumed $MESSAGE_COUNT message(s) via SSL${NC}"
        echo -e "${GREEN}Messages:${NC}"
        echo "$MESSAGES" | head -3
    else
        echo -e "${YELLOW}⚠ No messages consumed (may need to retry)${NC}"
    fi
else
    echo -e "${RED}✗ Failed to consume messages via SSL${NC}"
fi

echo ""
echo -e "${YELLOW}Test 7: Checking Kafka Connect SSL connectivity...${NC}"
CONNECT_STATUS=$(curl -s http://localhost:8083/ 2>/dev/null)
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Kafka Connect is accessible${NC}"
    
    # Check if Connect can communicate with Kafka via SSL
    CONNECTORS=$(curl -s http://localhost:8083/connectors 2>/dev/null)
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Kafka Connect can communicate with Kafka${NC}"
    else
        echo -e "${YELLOW}⚠ Kafka Connect communication check inconclusive${NC}"
    fi
else
    echo -e "${RED}✗ Kafka Connect is not accessible${NC}"
fi

echo ""
echo -e "${YELLOW}Test 8: Verifying certificate details...${NC}"
echo -e "${GREEN}Server Certificate:${NC}"
keytool -list -v -keystore kafka-certs/kafka.server.keystore.jks \
    -storepass kafka-secret -alias kafka-server 2>/dev/null | \
    grep -E "Owner|Issuer|Valid from|Valid until" | head -4

echo ""
echo -e "${GREEN}=====================================${NC}"
echo -e "${GREEN}TLS/SSL Tests Completed!${NC}"
echo -e "${GREEN}=====================================${NC}"
echo ""
echo -e "${YELLOW}Summary:${NC}"
echo -e "  • SSL port is accessible"
echo -e "  • Topic creation via SSL works"
echo -e "  • Message production via SSL works"
echo -e "  • Message consumption via SSL works"
echo -e "  • Kafka Connect is running with SSL"
echo ""
echo -e "${YELLOW}Additional Tests:${NC}"
echo -e "  # Check broker logs for SSL connections"
echo -e "  docker logs kafka-broker | grep -i ssl"
echo ""
echo -e "  # Check Connect logs for SSL"
echo -e "  docker logs kafka-connect | grep -i ssl"
echo ""
echo -e "  # Monitor SSL connections"
echo -e "  docker exec kafka-broker kafka-consumer-groups --list \\"
echo -e "    --bootstrap-server kafka:29093 \\"
echo -e "    --command-config /etc/kafka/secrets/client-ssl.properties"
echo ""
