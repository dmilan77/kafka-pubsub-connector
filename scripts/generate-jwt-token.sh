#!/bin/bash
# Script to generate JWT token for X.509 certificate-based authentication

set -e

CERT_DIR="certs"
PRIVATE_KEY="$CERT_DIR/workload-key.pem"
CERTIFICATE="$CERT_DIR/workload-cert.pem"
OUTPUT_FILE="$CERT_DIR/token.jwt"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== JWT Token Generation for X.509 Authentication ===${NC}"

# Check if certificate and key exist
if [ ! -f "$PRIVATE_KEY" ]; then
    echo -e "${RED}Error: Private key not found at $PRIVATE_KEY${NC}"
    echo -e "${YELLOW}Run ./scripts/generate-certificates.sh first${NC}"
    exit 1
fi

if [ ! -f "$CERTIFICATE" ]; then
    echo -e "${RED}Error: Certificate not found at $CERTIFICATE${NC}"
    echo -e "${YELLOW}Run ./scripts/generate-certificates.sh first${NC}"
    exit 1
fi

# Extract certificate subject (CN)
echo -e "\n${YELLOW}Step 1: Extracting certificate subject...${NC}"
CERT_CN=$(openssl x509 -in $CERTIFICATE -noout -subject -nameopt multiline | grep "commonName" | awk '{print $NF}')
if [ -z "$CERT_CN" ]; then
    echo -e "${RED}Error: Could not extract CN from certificate${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Certificate CN: $CERT_CN${NC}"

# Get Workload Identity audience from Terraform
echo -e "\n${YELLOW}Step 2: Retrieving Workload Identity configuration from Terraform...${NC}"
cd terraform 2>/dev/null || cd ../terraform 2>/dev/null || true
if [ -f "terraform.tfstate" ]; then
    AUDIENCE=$(terraform output -raw workload_identity_audience 2>/dev/null || echo "")
    if [ -z "$AUDIENCE" ]; then
        echo -e "${RED}Error: Could not get Workload Identity audience from Terraform${NC}"
        echo -e "${YELLOW}Make sure Terraform has been applied with Workload Identity enabled${NC}"
        exit 1
    fi
    echo -e "${GREEN}✓ Audience: $AUDIENCE${NC}"
    cd - > /dev/null
else
    echo -e "${RED}Error: terraform.tfstate not found${NC}"
    echo -e "${YELLOW}Run 'terraform apply' first${NC}"
    exit 1
fi

# Get current timestamp
CURRENT_TIME=$(date +%s)
EXPIRATION_TIME=$((CURRENT_TIME + 3600)) # Token valid for 1 hour

# Create JWT header
echo -e "\n${YELLOW}Step 3: Creating JWT header...${NC}"
HEADER=$(echo -n '{"alg":"RS256","typ":"JWT"}' | base64 | tr -d '=' | tr '/+' '_-' | tr -d '\n')
echo -e "${GREEN}✓ JWT header created${NC}"

# Create JWT payload with issuer matching the OIDC provider
ISSUER="https://kafka-connector.example.com"
echo -e "\n${YELLOW}Step 4: Creating JWT payload...${NC}"
PAYLOAD=$(cat <<EOF | base64 | tr -d '=' | tr '/+' '_-' | tr -d '\n'
{
  "iss": "$ISSUER",
  "sub": "$CERT_CN",
  "aud": "$AUDIENCE",
  "iat": $CURRENT_TIME,
  "exp": $EXPIRATION_TIME
}
EOF
)
echo -e "${GREEN}✓ JWT payload created${NC}"
echo -e "${YELLOW}  Token will expire in 1 hour${NC}"

# Create signature
echo -e "\n${YELLOW}Step 5: Signing JWT with private key...${NC}"
UNSIGNED_TOKEN="${HEADER}.${PAYLOAD}"
SIGNATURE=$(echo -n "$UNSIGNED_TOKEN" | openssl dgst -sha256 -sign $PRIVATE_KEY | base64 | tr -d '=' | tr '/+' '_-' | tr -d '\n')
echo -e "${GREEN}✓ JWT signed successfully${NC}"

# Create final JWT
JWT="${UNSIGNED_TOKEN}.${SIGNATURE}"

# Save to file
echo -e "\n${YELLOW}Step 6: Saving JWT token...${NC}"
echo -n "$JWT" > $OUTPUT_FILE
chmod 600 $OUTPUT_FILE
echo -e "${GREEN}✓ JWT token saved to: $OUTPUT_FILE${NC}"

# Display token info
echo -e "\n${GREEN}=== Token Generation Complete ===${NC}"
echo -e "\n${YELLOW}Token Details:${NC}"
echo -e "  Issuer: $ISSUER"
echo -e "  Subject: $CERT_CN"
echo -e "  Audience: $AUDIENCE"
echo -e "  Issued: $(date -r $CURRENT_TIME '+%Y-%m-%d %H:%M:%S')"
echo -e "  Expires: $(date -r $EXPIRATION_TIME '+%Y-%m-%d %H:%M:%S')"
echo -e "  File: $OUTPUT_FILE"

echo -e "\n${YELLOW}Token regeneration:${NC}"
echo -e "  This token expires in 1 hour."
echo -e "  Set up a cron job to regenerate it periodically:"
echo -e "  ${GREEN}*/30 * * * * /path/to/generate-jwt-token.sh > /dev/null 2>&1${NC}"

echo ""
