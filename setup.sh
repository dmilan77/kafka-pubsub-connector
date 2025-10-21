#!/bin/bash

# Quick setup script for development

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}Kafka to Pub/Sub Connector - Quick Setup${NC}"
echo ""

# Check prerequisites
echo -e "${YELLOW}Checking prerequisites...${NC}"

command -v java >/dev/null 2>&1 || { echo "Java is required but not installed. Aborting." >&2; exit 1; }
command -v mvn >/dev/null 2>&1 || { echo "Maven is required but not installed. Aborting." >&2; exit 1; }
command -v docker >/dev/null 2>&1 || { echo "Docker is required but not installed. Aborting." >&2; exit 1; }
command -v docker-compose >/dev/null 2>&1 || { echo "Docker Compose is required but not installed. Aborting." >&2; exit 1; }

echo -e "${GREEN}✓ All prerequisites met${NC}"
echo ""

# Build project
echo -e "${YELLOW}Building project...${NC}"
mvn clean package -DskipTests

echo -e "${GREEN}✓ Build successful${NC}"
echo ""

# Create necessary directories
mkdir -p connector-jars
mkdir -p config

# Copy example configuration
if [ ! -f "config/connector-config.json" ]; then
    echo -e "${YELLOW}Creating example configuration...${NC}"
    cp config/connector-config.example.json config/connector-config.json
    echo -e "${GREEN}✓ Configuration created at config/connector-config.json${NC}"
    echo -e "${YELLOW}⚠️  Please edit this file with your GCP project details${NC}"
fi

echo ""
echo -e "${GREEN}Setup complete!${NC}"
echo ""
echo -e "Next steps:"
echo -e "1. Edit ${YELLOW}terraform/terraform.tfvars${NC} with your GCP project ID"
echo -e "2. Run: ${YELLOW}cd terraform && terraform init && terraform apply${NC}"
echo -e "3. Edit ${YELLOW}config/connector-config.json${NC} with your settings"
echo -e "4. Run: ${YELLOW}./start-kafka.sh${NC}"
echo -e "5. Run: ${YELLOW}./deploy-connector.sh${NC}"
echo ""
echo -e "See ${YELLOW}GETTING_STARTED.md${NC} for detailed instructions"
