#!/bin/bash
# Script to generate TLS certificates for Kafka brokers and clients

set -e

CERT_DIR="kafka-certs"
DAYS_VALID=365
KEYSTORE_PASSWORD="kafka-secret"
TRUSTSTORE_PASSWORD="kafka-secret"
KEY_PASSWORD="kafka-secret"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Kafka TLS Certificate Generation ===${NC}"

# Create certificate directory
mkdir -p $CERT_DIR

# Step 1: Generate CA (Certificate Authority)
echo -e "\n${YELLOW}Step 1: Generating Certificate Authority (CA)...${NC}"
openssl req -new -x509 -keyout $CERT_DIR/ca-key -out $CERT_DIR/ca-cert -days 3650 -nodes \
  -subj "/C=US/ST=California/L=San Francisco/O=Kafka/OU=Security/CN=KafkaCA"

echo -e "${GREEN}✓ CA certificate generated: $CERT_DIR/ca-cert${NC}"
echo -e "${GREEN}✓ CA private key generated: $CERT_DIR/ca-key${NC}"

# Step 2: Create Kafka broker keystore and certificate
echo -e "\n${YELLOW}Step 2: Creating Kafka broker keystore...${NC}"
keytool -keystore $CERT_DIR/kafka.server.keystore.jks -alias kafka-server -validity $DAYS_VALID \
  -genkey -keyalg RSA -ext SAN=DNS:kafka,DNS:localhost,IP:127.0.0.1 \
  -storepass $KEYSTORE_PASSWORD -keypass $KEY_PASSWORD -noprompt \
  -dname "CN=kafka, OU=Engineering, O=Kafka, L=San Francisco, ST=California, C=US"

echo -e "${GREEN}✓ Kafka broker keystore created: $CERT_DIR/kafka.server.keystore.jks${NC}"

# Step 3: Create certificate signing request (CSR) for broker
echo -e "\n${YELLOW}Step 3: Creating certificate signing request for broker...${NC}"
keytool -keystore $CERT_DIR/kafka.server.keystore.jks -alias kafka-server \
  -certreq -file $CERT_DIR/kafka-server-cert-request -storepass $KEYSTORE_PASSWORD

echo -e "${GREEN}✓ CSR created: $CERT_DIR/kafka-server-cert-request${NC}"

# Step 4: Sign the broker certificate with CA
echo -e "\n${YELLOW}Step 4: Signing broker certificate with CA...${NC}"
openssl x509 -req -CA $CERT_DIR/ca-cert -CAkey $CERT_DIR/ca-key \
  -in $CERT_DIR/kafka-server-cert-request -out $CERT_DIR/kafka-server-cert-signed \
  -days $DAYS_VALID -CAcreateserial -extensions SAN \
  -extfile <(cat <<EOF
[SAN]
subjectAltName=DNS:kafka,DNS:localhost,IP:127.0.0.1
EOF
)

echo -e "${GREEN}✓ Signed certificate created: $CERT_DIR/kafka-server-cert-signed${NC}"

# Step 5: Import CA certificate into broker keystore
echo -e "\n${YELLOW}Step 5: Importing CA certificate into broker keystore...${NC}"
keytool -keystore $CERT_DIR/kafka.server.keystore.jks -alias CARoot \
  -import -file $CERT_DIR/ca-cert -storepass $KEYSTORE_PASSWORD -noprompt

echo -e "${GREEN}✓ CA certificate imported into keystore${NC}"

# Step 6: Import signed certificate into broker keystore
echo -e "\n${YELLOW}Step 6: Importing signed certificate into broker keystore...${NC}"
keytool -keystore $CERT_DIR/kafka.server.keystore.jks -alias kafka-server \
  -import -file $CERT_DIR/kafka-server-cert-signed -storepass $KEYSTORE_PASSWORD -noprompt

echo -e "${GREEN}✓ Signed certificate imported into keystore${NC}"

# Step 7: Create broker truststore and import CA certificate
echo -e "\n${YELLOW}Step 7: Creating broker truststore...${NC}"
keytool -keystore $CERT_DIR/kafka.server.truststore.jks -alias CARoot \
  -import -file $CERT_DIR/ca-cert -storepass $TRUSTSTORE_PASSWORD -noprompt

echo -e "${GREEN}✓ Broker truststore created: $CERT_DIR/kafka.server.truststore.jks${NC}"

# Step 8: Create client keystore (for Connect worker)
echo -e "\n${YELLOW}Step 8: Creating Kafka Connect client keystore...${NC}"
keytool -keystore $CERT_DIR/kafka.client.keystore.jks -alias kafka-client -validity $DAYS_VALID \
  -genkey -keyalg RSA -ext SAN=DNS:kafka-connect,DNS:localhost \
  -storepass $KEYSTORE_PASSWORD -keypass $KEY_PASSWORD -noprompt \
  -dname "CN=kafka-connect, OU=Engineering, O=Kafka, L=San Francisco, ST=California, C=US"

echo -e "${GREEN}✓ Client keystore created: $CERT_DIR/kafka.client.keystore.jks${NC}"

# Step 9: Create CSR for client
echo -e "\n${YELLOW}Step 9: Creating certificate signing request for client...${NC}"
keytool -keystore $CERT_DIR/kafka.client.keystore.jks -alias kafka-client \
  -certreq -file $CERT_DIR/kafka-client-cert-request -storepass $KEYSTORE_PASSWORD

echo -e "${GREEN}✓ Client CSR created: $CERT_DIR/kafka-client-cert-request${NC}"

# Step 10: Sign client certificate
echo -e "\n${YELLOW}Step 10: Signing client certificate with CA...${NC}"
openssl x509 -req -CA $CERT_DIR/ca-cert -CAkey $CERT_DIR/ca-key \
  -in $CERT_DIR/kafka-client-cert-request -out $CERT_DIR/kafka-client-cert-signed \
  -days $DAYS_VALID -CAcreateserial -extensions SAN \
  -extfile <(cat <<EOF
[SAN]
subjectAltName=DNS:kafka-connect,DNS:localhost
EOF
)

echo -e "${GREEN}✓ Signed client certificate created: $CERT_DIR/kafka-client-cert-signed${NC}"

# Step 11: Import CA into client keystore
echo -e "\n${YELLOW}Step 11: Importing CA certificate into client keystore...${NC}"
keytool -keystore $CERT_DIR/kafka.client.keystore.jks -alias CARoot \
  -import -file $CERT_DIR/ca-cert -storepass $KEYSTORE_PASSWORD -noprompt

echo -e "${GREEN}✓ CA certificate imported into client keystore${NC}"

# Step 12: Import signed client certificate
echo -e "\n${YELLOW}Step 12: Importing signed certificate into client keystore...${NC}"
keytool -keystore $CERT_DIR/kafka.client.keystore.jks -alias kafka-client \
  -import -file $CERT_DIR/kafka-client-cert-signed -storepass $KEYSTORE_PASSWORD -noprompt

echo -e "${GREEN}✓ Signed client certificate imported${NC}"

# Step 13: Create client truststore
echo -e "\n${YELLOW}Step 13: Creating client truststore...${NC}"
keytool -keystore $CERT_DIR/kafka.client.truststore.jks -alias CARoot \
  -import -file $CERT_DIR/ca-cert -storepass $TRUSTSTORE_PASSWORD -noprompt

echo -e "${GREEN}✓ Client truststore created: $CERT_DIR/kafka.client.truststore.jks${NC}"

# Step 14: Create credential properties file
echo -e "\n${YELLOW}Step 14: Creating credential properties file...${NC}"
cat > $CERT_DIR/kafka-ssl-credentials.properties <<EOF
# Kafka SSL/TLS Configuration
# Keystore and Truststore Passwords

# Broker Configuration
ssl.keystore.password=$KEYSTORE_PASSWORD
ssl.key.password=$KEY_PASSWORD
ssl.truststore.password=$TRUSTSTORE_PASSWORD

# Client Configuration
ssl.endpoint.identification.algorithm=
EOF

echo -e "${GREEN}✓ Credentials file created: $CERT_DIR/kafka-ssl-credentials.properties${NC}"

# Step 15: Create server.properties snippet
echo -e "\n${YELLOW}Step 15: Creating server configuration snippet...${NC}"
cat > $CERT_DIR/server-ssl.properties <<EOF
# SSL/TLS Configuration for Kafka Broker
# Add these properties to your server.properties or use as environment variables

# Listeners
listeners=PLAINTEXT://kafka:29092,SSL://kafka:29093
advertised.listeners=PLAINTEXT://kafka:29092,SSL://kafka:29093

# SSL Configuration
ssl.keystore.location=/etc/kafka/secrets/kafka.server.keystore.jks
ssl.keystore.password=$KEYSTORE_PASSWORD
ssl.key.password=$KEY_PASSWORD
ssl.truststore.location=/etc/kafka/secrets/kafka.server.truststore.jks
ssl.truststore.password=$TRUSTSTORE_PASSWORD

# Client Authentication (optional - set to 'required' for mutual TLS)
ssl.client.auth=required

# SSL Protocol
ssl.enabled.protocols=TLSv1.2,TLSv1.3
ssl.protocol=TLSv1.3

# Security Protocol Mapping
listener.security.protocol.map=PLAINTEXT:PLAINTEXT,SSL:SSL

# Inter-broker communication
inter.broker.listener.name=SSL
security.inter.broker.protocol=SSL
EOF

echo -e "${GREEN}✓ Server configuration snippet created: $CERT_DIR/server-ssl.properties${NC}"

# Step 16: Create client.properties
echo -e "\n${YELLOW}Step 16: Creating client configuration file...${NC}"
cat > $CERT_DIR/client-ssl.properties <<EOF
# SSL/TLS Configuration for Kafka Clients

# Security Protocol
security.protocol=SSL

# SSL Configuration
ssl.truststore.location=/etc/kafka/secrets/kafka.client.truststore.jks
ssl.truststore.password=$TRUSTSTORE_PASSWORD
ssl.keystore.location=/etc/kafka/secrets/kafka.client.keystore.jks
ssl.keystore.password=$KEYSTORE_PASSWORD
ssl.key.password=$KEY_PASSWORD

# SSL Protocol
ssl.enabled.protocols=TLSv1.2,TLSv1.3
ssl.protocol=TLSv1.3

# Endpoint Identification (disable for localhost/development)
ssl.endpoint.identification.algorithm=
EOF

echo -e "${GREEN}✓ Client configuration created: $CERT_DIR/client-ssl.properties${NC}"

# Step 17: Verify certificates
echo -e "\n${YELLOW}Step 17: Verifying certificates...${NC}"
echo -e "\n${YELLOW}Broker Keystore Contents:${NC}"
keytool -list -v -keystore $CERT_DIR/kafka.server.keystore.jks -storepass $KEYSTORE_PASSWORD | grep -E "Alias|Owner|Issuer|Valid"

echo -e "\n${YELLOW}Client Keystore Contents:${NC}"
keytool -list -v -keystore $CERT_DIR/kafka.client.keystore.jks -storepass $KEYSTORE_PASSWORD | grep -E "Alias|Owner|Issuer|Valid"

# Summary
echo -e "\n${GREEN}=== Kafka TLS Certificate Generation Complete ===${NC}"
echo -e "\n${YELLOW}Generated Files:${NC}"
echo -e "  ${GREEN}Certificate Authority:${NC}"
echo -e "    • $CERT_DIR/ca-cert                             - CA certificate"
echo -e "    • $CERT_DIR/ca-key                              - CA private key"
echo -e ""
echo -e "  ${GREEN}Kafka Broker:${NC}"
echo -e "    • $CERT_DIR/kafka.server.keystore.jks           - Broker keystore (private key + cert)"
echo -e "    • $CERT_DIR/kafka.server.truststore.jks         - Broker truststore (CA cert)"
echo -e "    • $CERT_DIR/kafka-server-cert-signed            - Signed broker certificate"
echo -e ""
echo -e "  ${GREEN}Kafka Client (Connect):${NC}"
echo -e "    • $CERT_DIR/kafka.client.keystore.jks           - Client keystore (private key + cert)"
echo -e "    • $CERT_DIR/kafka.client.truststore.jks         - Client truststore (CA cert)"
echo -e "    • $CERT_DIR/kafka-client-cert-signed            - Signed client certificate"
echo -e ""
echo -e "  ${GREEN}Configuration:${NC}"
echo -e "    • $CERT_DIR/kafka-ssl-credentials.properties    - SSL passwords"
echo -e "    • $CERT_DIR/server-ssl.properties               - Broker SSL config snippet"
echo -e "    • $CERT_DIR/client-ssl.properties               - Client SSL config"
echo -e ""
echo -e "${YELLOW}Passwords:${NC}"
echo -e "  Keystore Password: ${GREEN}$KEYSTORE_PASSWORD${NC}"
echo -e "  Truststore Password: ${GREEN}$TRUSTSTORE_PASSWORD${NC}"
echo -e "  Key Password: ${GREEN}$KEY_PASSWORD${NC}"
echo -e ""
echo -e "${YELLOW}Next Steps:${NC}"
echo -e "  1. Review the configuration files in $CERT_DIR/"
echo -e "  2. Update docker-compose.yml to mount the certificates"
echo -e "  3. Configure Kafka broker environment variables for SSL"
echo -e "  4. Configure Kafka Connect to use SSL"
echo -e "  5. Test the SSL connection"
echo -e ""
echo -e "${RED}Security Reminder:${NC}"
echo -e "  • Keep $CERT_DIR/*.jks files secure!"
echo -e "  • Keep $CERT_DIR/ca-key secure!"
echo -e "  • Add $CERT_DIR/ to .gitignore"
echo -e "  • Change default passwords in production!"
echo ""
