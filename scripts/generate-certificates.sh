#!/bin/bash
# Script to generate X.509 certificates for Workload Identity Federation

set -e

CERT_DIR="certs"
DAYS_VALID=365

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== X.509 Certificate Generation for Workload Identity Federation ===${NC}"

# Create certificate directory
mkdir -p $CERT_DIR

# Generate CA certificate
echo -e "\n${YELLOW}Step 1: Generating CA certificate...${NC}"
openssl req -new -x509 -days 3650 \
  -keyout $CERT_DIR/ca-key.pem \
  -out $CERT_DIR/ca-cert.pem \
  -nodes \
  -subj "/C=US/ST=California/L=San Francisco/O=Kafka PubSub Connector/OU=Certificate Authority/CN=kafka-connector-ca"
chmod 600 $CERT_DIR/ca-key.pem
echo -e "${GREEN}✓ CA certificate generated: $CERT_DIR/ca-cert.pem${NC}"
echo -e "${GREEN}✓ CA private key generated: $CERT_DIR/ca-key.pem${NC}"

# Generate workload private key
echo -e "\n${YELLOW}Step 2: Generating workload RSA private key...${NC}"
openssl genrsa -out $CERT_DIR/workload-key.pem 2048
chmod 600 $CERT_DIR/workload-key.pem
echo -e "${GREEN}✓ Private key generated: $CERT_DIR/workload-key.pem${NC}"

# Create OpenSSL configuration file for the certificate
echo -e "\n${YELLOW}Step 3: Creating OpenSSL configuration...${NC}"
cat > $CERT_DIR/cert-config.cnf <<EOF
[req]
default_bits = 2048
prompt = no
default_md = sha256
distinguished_name = dn
x509_extensions = v3_req

[dn]
C=US
ST=California
L=San Francisco
O=Kafka PubSub Connector
OU=Engineering
CN=kafka-connector-workload
emailAddress=admin@example.com

[v3_req]
subjectAltName = @alt_names
keyUsage = digitalSignature, keyEncipherment
extendedKeyUsage = clientAuth

[alt_names]
DNS.1 = kafka-connector
DNS.2 = localhost
URI.1 = spiffe://kafka-connector/workload
EOF
echo -e "${GREEN}✓ OpenSSL configuration created${NC}"

# Generate CSR for workload certificate
echo -e "\n${YELLOW}Step 4: Generating certificate signing request...${NC}"
openssl req -new \
  -key $CERT_DIR/workload-key.pem \
  -out $CERT_DIR/workload.csr \
  -config $CERT_DIR/cert-config.cnf
echo -e "${GREEN}✓ CSR generated: $CERT_DIR/workload.csr${NC}"

# Sign workload certificate with CA
echo -e "\n${YELLOW}Step 5: Signing workload certificate with CA...${NC}"
openssl x509 -req \
  -in $CERT_DIR/workload.csr \
  -CA $CERT_DIR/ca-cert.pem \
  -CAkey $CERT_DIR/ca-key.pem \
  -CAcreateserial \
  -out $CERT_DIR/workload-cert.pem \
  -days $DAYS_VALID \
  -extfile $CERT_DIR/cert-config.cnf \
  -extensions v3_req

echo -e "${GREEN}✓ Certificate generated: $CERT_DIR/workload-cert.pem${NC}"
echo -e "${GREEN}  Valid for: $DAYS_VALID days${NC}"
echo -e "${GREEN}  Signed by CA: kafka-connector-ca${NC}"

# Display certificate information
echo -e "\n${YELLOW}Step 6: Certificate Details:${NC}"
openssl x509 -in $CERT_DIR/workload-cert.pem -noout -subject -issuer -dates -fingerprint -sha256

# Extract certificate fingerprint for Workload Identity
echo -e "\n${YELLOW}Step 7: Extracting certificate fingerprint...${NC}"
FINGERPRINT=$(openssl x509 -in $CERT_DIR/workload-cert.pem -noout -fingerprint -sha256 | cut -d'=' -f2 | tr -d ':' | tr '[:upper:]' '[:lower:]')
echo $FINGERPRINT > $CERT_DIR/fingerprint.txt
echo -e "${GREEN}✓ Certificate SHA-256 fingerprint: $FINGERPRINT${NC}"
echo -e "${GREEN}✓ Saved to: $CERT_DIR/fingerprint.txt${NC}"

# Create PEM bundle (if needed)
echo -e "\n${YELLOW}Step 8: Creating certificate bundle...${NC}"
cat $CERT_DIR/workload-cert.pem $CERT_DIR/workload-key.pem > $CERT_DIR/workload-bundle.pem
chmod 600 $CERT_DIR/workload-bundle.pem
echo -e "${GREEN}✓ Certificate bundle created: $CERT_DIR/workload-bundle.pem${NC}"

# Create PKCS12 format (optional, for Java KeyStore)
echo -e "\n${YELLOW}Step 9: Creating PKCS12 keystore...${NC}"
openssl pkcs12 -export \
  -in $CERT_DIR/workload-cert.pem \
  -inkey $CERT_DIR/workload-key.pem \
  -out $CERT_DIR/workload-keystore.p12 \
  -name "kafka-connector-workload" \
  -passout pass:changeit

chmod 600 $CERT_DIR/workload-keystore.p12
echo -e "${GREEN}✓ PKCS12 keystore created: $CERT_DIR/workload-keystore.p12${NC}"
echo -e "${YELLOW}  Default password: changeit${NC}"

# Create X.509 mTLS credential configuration file template
echo -e "\n${YELLOW}Step 10: Creating X.509 mTLS credential configuration template...${NC}"
cat > $CERT_DIR/credential-config.json <<EOF
{
  "universe_domain": "googleapis.com",
  "type": "external_account",
  "audience": "//iam.googleapis.com/projects/PROJECT_NUMBER/locations/global/workloadIdentityPools/POOL_ID/providers/PROVIDER_ID",
  "subject_token_type": "urn:ietf:params:oauth:token-type:mtls",
  "token_url": "https://sts.mtls.googleapis.com/v1/token",
  "credential_source": {
    "certificate": {
      "certificate_config_location": "$(pwd)/$CERT_DIR/certificate_config.json",
      "trust_chain_path": "$(pwd)/$CERT_DIR/ca-cert.pem"
    }
  }
}
EOF
echo -e "${GREEN}✓ X.509 mTLS credential configuration template created: $CERT_DIR/credential-config.json${NC}"
echo -e "${YELLOW}  You'll need to update this file with your actual GCP values${NC}"

# Create certificate configuration file
echo -e "\n${YELLOW}Step 11: Creating certificate configuration files...${NC}"
cat > $CERT_DIR/certificate_config.json <<EOF
{
  "cert_configs": {
    "workload": {
      "cert_path": "$(pwd)/$CERT_DIR/workload-cert.pem",
      "key_path": "$(pwd)/$CERT_DIR/workload-key.pem"
    }
  }
}
EOF
echo -e "${GREEN}✓ Local certificate configuration created: $CERT_DIR/certificate_config.json${NC}"

# Create Docker-specific certificate configuration
cat > $CERT_DIR/certificate_config_docker.json <<EOF
{
  "cert_configs": {
    "workload": {
      "cert_path": "/etc/kafka-connect/certs/workload-cert.pem",
      "key_path": "/etc/kafka-connect/certs/workload-key.pem"
    }
  }
}
EOF
echo -e "${GREEN}✓ Docker certificate configuration created: $CERT_DIR/certificate_config_docker.json${NC}"

# Generate gcloud-based credential configurations
echo -e "\n${YELLOW}Step 12: Generating gcloud credential configurations...${NC}"

# Check if gcloud is available and configured
if command -v gcloud &> /dev/null; then
  # Get current project
  CURRENT_PROJECT=$(gcloud config get-value project 2>/dev/null)
  
  if [ -n "$CURRENT_PROJECT" ]; then
    # Try to get project number
    PROJECT_NUMBER=$(gcloud projects describe $CURRENT_PROJECT --format="value(projectNumber)" 2>/dev/null)
    
    if [ -n "$PROJECT_NUMBER" ]; then
      echo -e "${GREEN}✓ Detected GCP Project: $CURRENT_PROJECT (Project Number: $PROJECT_NUMBER)${NC}"
      
      # Prompt for configuration details
      read -p "Enter Workload Identity Pool ID [kafka-connector-pool]: " POOL_ID
      POOL_ID=${POOL_ID:-kafka-connector-pool}
      
      read -p "Enter X.509 Provider ID [x509-mtls-provider]: " PROVIDER_ID
      PROVIDER_ID=${PROVIDER_ID:-x509-mtls-provider}
      
      read -p "Enter Service Account Email: " SERVICE_ACCOUNT_EMAIL
      
      if [ -n "$SERVICE_ACCOUNT_EMAIL" ]; then
        echo -e "\n${YELLOW}Creating local credential configuration...${NC}"
        gcloud iam workload-identity-pools create-cred-config \
          projects/$PROJECT_NUMBER/locations/global/workloadIdentityPools/$POOL_ID/providers/$PROVIDER_ID \
          --service-account=$SERVICE_ACCOUNT_EMAIL \
          --credential-source-type=x509 \
          --credential-cert-path=$(pwd)/$CERT_DIR/workload-cert.pem \
          --credential-cert-private-key-path=$(pwd)/$CERT_DIR/workload-key.pem \
          --credential-cert-trust-chain-path=$(pwd)/$CERT_DIR/ca-cert.pem \
          --output-file=$CERT_DIR/workload-identity-gcloud-config-local.json
        
        if [ $? -eq 0 ]; then
          echo -e "${GREEN}✓ Local credential configuration created: $CERT_DIR/workload-identity-gcloud-config-local.json${NC}"
          
          # Update local config to use explicit certificate_config_location and remove impersonation
          echo -e "${YELLOW}Updating local configuration for direct access (no impersonation)...${NC}"
          python3 << PYTHON_EOF
import json

# Read the current config
with open('${CERT_DIR}/workload-identity-gcloud-config-local.json', 'r') as f:
    config = json.load(f)

# Update to use explicit certificate config location instead of default
config['credential_source']['certificate'] = {
    "certificate_config_location": "$(pwd)/${CERT_DIR}/certificate_config.json",
    "trust_chain_path": "$(pwd)/${CERT_DIR}/ca-cert.pem"
}

# Remove service account impersonation for direct access
if 'service_account_impersonation_url' in config:
    del config['service_account_impersonation_url']

# Write back
with open('${CERT_DIR}/workload-identity-gcloud-config-local.json', 'w') as f:
    json.dump(config, f, indent=2)

print("✓ Updated to use direct access (no impersonation)")
PYTHON_EOF
          
          if [ $? -eq 0 ]; then
            echo -e "${GREEN}✓ Local configuration updated with explicit certificate paths${NC}"
          fi
          
          # Create Docker version with absolute paths
          echo -e "\n${YELLOW}Creating Docker credential configuration...${NC}"
          gcloud iam workload-identity-pools create-cred-config \
            projects/$PROJECT_NUMBER/locations/global/workloadIdentityPools/$POOL_ID/providers/$PROVIDER_ID \
            --service-account=$SERVICE_ACCOUNT_EMAIL \
            --credential-source-type=x509 \
            --credential-cert-path=/etc/kafka-connect/certs/workload-cert.pem \
            --credential-cert-private-key-path=/etc/kafka-connect/certs/workload-key.pem \
            --credential-cert-trust-chain-path=/etc/kafka-connect/certs/ca-cert.pem \
            --output-file=$CERT_DIR/workload-identity-docker-config.json
          
          if [ $? -eq 0 ]; then
            echo -e "${GREEN}✓ Docker credential configuration created: $CERT_DIR/workload-identity-docker-config.json${NC}"
            
            # Update Docker config to use explicit certificate_config_location and remove impersonation
            echo -e "${YELLOW}Updating Docker configuration for direct access (no impersonation)...${NC}"
            python3 << PYTHON_EOF
import json

# Read the current config
with open('${CERT_DIR}/workload-identity-docker-config.json', 'r') as f:
    config = json.load(f)

# Update to use explicit certificate config location instead of default
config['credential_source']['certificate'] = {
    "certificate_config_location": "/etc/kafka-connect/certs/certificate_config_docker.json",
    "trust_chain_path": "/etc/kafka-connect/certs/ca-cert.pem"
}

# Remove service account impersonation for direct access
if 'service_account_impersonation_url' in config:
    del config['service_account_impersonation_url']

# Write back
with open('${CERT_DIR}/workload-identity-docker-config.json', 'w') as f:
    json.dump(config, f, indent=2)

print("✓ Updated to use direct access (no impersonation)")
PYTHON_EOF
            
            if [ $? -eq 0 ]; then
              echo -e "${GREEN}✓ Docker configuration updated with explicit certificate paths${NC}"
            fi
          else
            echo -e "${RED}✗ Failed to create Docker credential configuration${NC}"
          fi
        else
          echo -e "${RED}✗ Failed to create local credential configuration${NC}"
        fi
      else
        echo -e "${YELLOW}⚠ Service account email not provided, skipping gcloud credential config generation${NC}"
      fi
    else
      echo -e "${YELLOW}⚠ Could not determine project number, skipping gcloud credential config generation${NC}"
    fi
  else
    echo -e "${YELLOW}⚠ No active GCP project, skipping gcloud credential config generation${NC}"
  fi
else
  echo -e "${YELLOW}⚠ gcloud CLI not found, skipping gcloud credential config generation${NC}"
  echo -e "${YELLOW}  You can manually run the gcloud command later to create credential configs${NC}"
fi

# Summary
echo -e "\n${GREEN}=== Certificate Generation Complete ===${NC}"
echo -e "\n${YELLOW}Generated Files:${NC}"
echo -e "  1. $CERT_DIR/ca-key.pem                          - CA private key"
echo -e "  2. $CERT_DIR/ca-cert.pem                         - CA certificate (trust anchor)"
echo -e "  3. $CERT_DIR/workload-key.pem                    - Workload private key"
echo -e "  4. $CERT_DIR/workload-cert.pem                   - Workload X.509 certificate (CA-signed)"
echo -e "  5. $CERT_DIR/workload.csr                        - Certificate signing request"
echo -e "  6. $CERT_DIR/workload-bundle.pem                 - Combined cert + key"
echo -e "  7. $CERT_DIR/workload-keystore.p12               - PKCS12 keystore"
echo -e "  8. $CERT_DIR/fingerprint.txt                     - Certificate fingerprint"
echo -e "  9. $CERT_DIR/credential-config.json              - X.509 mTLS credential configuration template"
echo -e " 10. $CERT_DIR/certificate_config.json             - Certificate paths configuration"
echo -e " 11. $CERT_DIR/cert-config.cnf                     - OpenSSL configuration"

# Check if gcloud configs were created
if [ -f "$CERT_DIR/workload-identity-gcloud-config-local.json" ]; then
  echo -e " 12. $CERT_DIR/workload-identity-gcloud-config-local.json  - Local gcloud credential config"
fi
if [ -f "$CERT_DIR/workload-identity-docker-config.json" ]; then
  echo -e " 13. $CERT_DIR/workload-identity-docker-config.json       - Docker gcloud credential config"
fi

echo -e "\n${YELLOW}Next Steps:${NC}"
if [ -f "$CERT_DIR/workload-identity-gcloud-config-local.json" ]; then
  echo -e "  1. ✓ Credential configurations created - ready to test!"
  echo -e "  2. Run 'terraform apply' if you haven't already deployed the X.509 provider"
  echo -e "  3. Test local authentication:"
  echo -e "     cd test-pubsub && mvn exec:java -Dexec.mainClass=\"PubSubX509Test\" \\"
  echo -e "       -Dexec.args=\"../certs/workload-identity-gcloud-config-local.json PROJECT_ID TOPIC_ID\""
  echo -e "  4. Deploy connector with Docker configuration:"
  echo -e "     ./deploy-connector.sh config/connector-config-x509.json"
else
  echo -e "  1. Run 'terraform apply' to create X.509 Workload Identity Pool and Provider"
  echo -e "  2. Generate credential configurations using gcloud:"
  echo -e "     gcloud iam workload-identity-pools create-cred-config \\"
  echo -e "       projects/PROJECT_NUMBER/locations/global/workloadIdentityPools/POOL_ID/providers/PROVIDER_ID \\"
  echo -e "       --service-account=SERVICE_ACCOUNT_EMAIL \\"
  echo -e "       --credential-source-type=x509 \\"
  echo -e "       --credential-source-certificate-path=$CERT_DIR/workload-cert.pem \\"
  echo -e "       --credential-source-certificate-private-key-path=$CERT_DIR/workload-key.pem \\"
  echo -e "       --output-file=$CERT_DIR/workload-identity-gcloud-config-local.json"
  echo -e "  3. Test authentication using the X.509 mTLS credentials"
  echo -e "  4. Configure the connector to use the credential configuration"
fi

echo -e "\n${YELLOW}Security Reminder:${NC}"
echo -e "  ${RED}Keep $CERT_DIR/workload-key.pem and $CERT_DIR/workload-bundle.pem secure!${NC}"
echo -e "  Add $CERT_DIR/ to .gitignore to prevent committing certificates"

echo ""
