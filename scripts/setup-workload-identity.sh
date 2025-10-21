#!/bin/bash
# Quick setup script for Workload Identity Federation

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}"
cat << "EOF"
╔═══════════════════════════════════════════════════════════╗
║  Workload Identity Federation Setup                      ║
║  Kafka to Google Pub/Sub Connector                       ║
╚═══════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

# Check prerequisites
echo -e "${YELLOW}Checking prerequisites...${NC}"

command -v openssl >/dev/null 2>&1 || { echo -e "${RED}Error: openssl is not installed${NC}"; exit 1; }
command -v terraform >/dev/null 2>&1 || { echo -e "${RED}Error: terraform is not installed${NC}"; exit 1; }
command -v gcloud >/dev/null 2>&1 || { echo -e "${RED}Error: gcloud CLI is not installed${NC}"; exit 1; }

echo -e "${GREEN}✓ All prerequisites met${NC}\n"

# Step 1: Generate certificates
echo -e "${BLUE}═══ Step 1: Generate X.509 Certificates ═══${NC}"
if [ ! -f "scripts/generate-certificates.sh" ]; then
    echo -e "${RED}Error: scripts/generate-certificates.sh not found${NC}"
    exit 1
fi

chmod +x scripts/generate-certificates.sh
./scripts/generate-certificates.sh

# Step 2: Check Terraform configuration
echo -e "\n${BLUE}═══ Step 2: Configure Terraform ═══${NC}"
if [ ! -f "terraform/terraform.tfvars" ]; then
    echo -e "${YELLOW}Creating terraform.tfvars from example...${NC}"
    if [ -f "terraform/terraform.tfvars.example" ]; then
        cp terraform/terraform.tfvars.example terraform/terraform.tfvars
        echo -e "${YELLOW}Please edit terraform/terraform.tfvars with your GCP project details${NC}"
        echo -e "${YELLOW}Required: project_id${NC}"
        read -p "Press Enter to continue after editing terraform.tfvars..."
    else
        echo -e "${RED}Error: terraform/terraform.tfvars.example not found${NC}"
        exit 1
    fi
fi

# Step 3: Deploy infrastructure
echo -e "\n${BLUE}═══ Step 3: Deploy Infrastructure with Terraform ═══${NC}"
cd terraform

echo -e "${YELLOW}Initializing Terraform...${NC}"
terraform init

echo -e "\n${YELLOW}Planning Terraform deployment...${NC}"
terraform plan

read -p "Apply this Terraform plan? (yes/no): " CONFIRM
if [ "$CONFIRM" != "yes" ]; then
    echo -e "${RED}Deployment cancelled${NC}"
    exit 1
fi

terraform apply -auto-approve

# Get outputs
echo -e "\n${YELLOW}Extracting Terraform outputs...${NC}"
AUDIENCE=$(terraform output -raw workload_identity_audience 2>/dev/null || echo "")
PROJECT_ID=$(terraform output -raw project_id 2>/dev/null || echo "")
SA_EMAIL=$(terraform output -raw service_account_email 2>/dev/null || echo "")

cd ..

# Step 4: Update JWT generation script
echo -e "\n${BLUE}═══ Step 4: Configure JWT Token Generation ═══${NC}"

if [ -n "$AUDIENCE" ]; then
    echo -e "${GREEN}Workload Identity Audience: $AUDIENCE${NC}"
    
    # Update the JWT generation script with actual audience
    if [ -f "scripts/generate-jwt-token.sh" ]; then
        # Create a personalized version
        sed "s|//iam.googleapis.com/projects/PROJECT_NUMBER/locations/global/workloadIdentityPools/POOL_ID/providers/PROVIDER_ID|$AUDIENCE|g" \
            scripts/generate-jwt-token.sh > scripts/generate-jwt-token-configured.sh
        chmod +x scripts/generate-jwt-token-configured.sh
        echo -e "${GREEN}✓ Created configured JWT generation script${NC}"
    fi
else
    echo -e "${YELLOW}Warning: Could not extract audience from Terraform output${NC}"
fi

# Step 5: Generate initial JWT token
echo -e "\n${BLUE}═══ Step 5: Generate JWT Token ═══${NC}"
if [ -f "scripts/generate-jwt-token-configured.sh" ]; then
    ./scripts/generate-jwt-token-configured.sh
else
    echo -e "${YELLOW}Using default script (you'll need to configure audience manually)${NC}"
    chmod +x scripts/generate-jwt-token.sh
    ./scripts/generate-jwt-token.sh
fi

# Step 6: Summary
echo -e "\n${BLUE}═══ Setup Complete ═══${NC}"
echo -e "\n${GREEN}✓ X.509 certificates generated in: certs/${NC}"
echo -e "${GREEN}✓ Workload Identity Pool and Provider created${NC}"
echo -e "${GREEN}✓ Service Account configured${NC}"
echo -e "${GREEN}✓ JWT token generated${NC}"

echo -e "\n${YELLOW}Important Information:${NC}"
echo -e "  Project ID:        $PROJECT_ID"
echo -e "  Service Account:   $SA_EMAIL"
echo -e "  Audience:          $AUDIENCE"

echo -e "\n${YELLOW}Next Steps:${NC}"
echo -e "  1. Update connector configuration:"
echo -e "     ${GREEN}config/connector-config-workload-identity.json${NC}"
echo -e ""
echo -e "  2. Set credential path in config:"
echo -e "     ${GREEN}gcp.workload.credential.config=$(pwd)/terraform/workload-identity-credential.json${NC}"
echo -e ""
echo -e "  3. Build the connector:"
echo -e "     ${GREEN}mvn clean package${NC}"
echo -e ""
echo -e "  4. Deploy the connector:"
echo -e "     ${GREEN}./deploy-connector.sh${NC}"
echo -e ""
echo -e "  5. Set up JWT token auto-renewal (cron job):"
echo -e "     ${GREEN}*/30 * * * * $(pwd)/scripts/generate-jwt-token-configured.sh > /dev/null 2>&1${NC}"

echo -e "\n${YELLOW}Security Reminders:${NC}"
echo -e "  ${RED}• Add certs/ to .gitignore${NC}"
echo -e "  ${RED}• Keep workload-key.pem secure (chmod 600)${NC}"
echo -e "  ${RED}• Set up certificate rotation before expiry (365 days)${NC}"
echo -e "  ${RED}• Monitor token generation logs${NC}"

echo -e "\n${BLUE}For detailed documentation, see: WORKLOAD_IDENTITY_SETUP.md${NC}\n"
