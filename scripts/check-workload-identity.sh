#!/bin/bash
# Health check script for Workload Identity setup

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
║  Workload Identity Health Check                          ║
║  Kafka to Google Pub/Sub Connector                       ║
╚═══════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

ERRORS=0
WARNINGS=0

# Function to check file existence
check_file() {
    local file=$1
    local description=$2
    local required=$3
    
    if [ -f "$file" ]; then
        echo -e "${GREEN}✓${NC} $description: $file"
        return 0
    else
        if [ "$required" = "true" ]; then
            echo -e "${RED}✗${NC} $description: ${RED}NOT FOUND${NC}"
            ((ERRORS++))
        else
            echo -e "${YELLOW}⚠${NC} $description: ${YELLOW}NOT FOUND (optional)${NC}"
            ((WARNINGS++))
        fi
        return 1
    fi
}

# Function to check certificate expiration
check_cert_expiration() {
    local cert_file=$1
    
    if [ ! -f "$cert_file" ]; then
        return 1
    fi
    
    local expiry=$(openssl x509 -in "$cert_file" -noout -enddate | cut -d= -f2)
    local expiry_epoch=$(date -j -f "%b %d %T %Y %Z" "$expiry" +%s 2>/dev/null || date -d "$expiry" +%s 2>/dev/null)
    local now_epoch=$(date +%s)
    local days_left=$(( ($expiry_epoch - $now_epoch) / 86400 ))
    
    if [ $days_left -lt 0 ]; then
        echo -e "  ${RED}Certificate has EXPIRED${NC}"
        ((ERRORS++))
        return 1
    elif [ $days_left -lt 30 ]; then
        echo -e "  ${YELLOW}Certificate expires in $days_left days - RENEWAL RECOMMENDED${NC}"
        ((WARNINGS++))
        return 0
    else
        echo -e "  ${GREEN}Certificate valid for $days_left more days${NC}"
        return 0
    fi
}

# Function to check JWT token age
check_token_age() {
    local token_file=$1
    
    if [ ! -f "$token_file" ]; then
        return 1
    fi
    
    local file_age=$(( $(date +%s) - $(stat -f %m "$token_file" 2>/dev/null || stat -c %Y "$token_file" 2>/dev/null) ))
    local hours_old=$(( $file_age / 3600 ))
    
    if [ $hours_old -gt 1 ]; then
        echo -e "  ${RED}Token is $hours_old hours old - EXPIRED (tokens valid for 1 hour)${NC}"
        echo -e "  ${YELLOW}Run: ./scripts/generate-jwt-token.sh${NC}"
        ((ERRORS++))
        return 1
    elif [ $hours_old -eq 1 ]; then
        echo -e "  ${YELLOW}Token is $hours_old hour old - ABOUT TO EXPIRE${NC}"
        ((WARNINGS++))
        return 0
    else
        local minutes_old=$(( $file_age / 60 ))
        echo -e "  ${GREEN}Token is $minutes_old minutes old (valid)${NC}"
        return 0
    fi
}

echo -e "${BLUE}═══ Certificate Files ═══${NC}"
if check_file "certs/workload-key.pem" "Private key" "true"; then
    # Check permissions
    if [ "$(stat -f %A certs/workload-key.pem 2>/dev/null || stat -c %a certs/workload-key.pem 2>/dev/null)" != "600" ]; then
        echo -e "  ${YELLOW}⚠ Warning: Private key should have 0600 permissions${NC}"
        echo -e "  ${YELLOW}Run: chmod 600 certs/workload-key.pem${NC}"
        ((WARNINGS++))
    fi
fi

if check_file "certs/workload-cert.pem" "Certificate" "true"; then
    check_cert_expiration "certs/workload-cert.pem"
fi

check_file "certs/workload-bundle.pem" "Certificate bundle" "false"
check_file "certs/workload-keystore.p12" "PKCS12 keystore" "false"
check_file "certs/fingerprint.txt" "Certificate fingerprint" "false"

echo -e "\n${BLUE}═══ JWT Token ═══${NC}"
if check_file "certs/token.jwt" "JWT token" "true"; then
    check_token_age "certs/token.jwt"
fi

echo -e "\n${BLUE}═══ Terraform Configuration ═══${NC}"
check_file "terraform/workload-identity.tf" "Workload Identity config" "true"
check_file "terraform/terraform.tfvars" "Terraform variables" "true"

echo -e "\n${BLUE}═══ Terraform State ═══${NC}"
if check_file "terraform/terraform.tfstate" "Terraform state" "false"; then
    echo -e "  ${GREEN}Infrastructure has been deployed${NC}"
    
    # Check if workload-identity-credential.json exists
    if check_file "terraform/workload-identity-credential.json" "Credential config" "true"; then
        echo -e "  ${GREEN}Workload Identity has been configured${NC}"
    fi
else
    echo -e "  ${YELLOW}Infrastructure not yet deployed${NC}"
    echo -e "  ${YELLOW}Run: cd terraform && terraform apply${NC}"
    ((WARNINGS++))
fi

echo -e "\n${BLUE}═══ Connector Configuration ═══${NC}"
check_file "config/connector-config-workload-identity.json" "JSON config example" "false"
check_file "config/connector-config-workload-identity.properties" "Properties config example" "false"
check_file "config/connector-config.json" "Active connector config" "false"

echo -e "\n${BLUE}═══ Scripts ═══${NC}"
for script in scripts/generate-certificates.sh scripts/generate-jwt-token.sh scripts/setup-workload-identity.sh; do
    if check_file "$script" "$(basename $script)" "true"; then
        if [ ! -x "$script" ]; then
            echo -e "  ${YELLOW}⚠ Warning: Script is not executable${NC}"
            echo -e "  ${YELLOW}Run: chmod +x $script${NC}"
            ((WARNINGS++))
        fi
    fi
done

echo -e "\n${BLUE}═══ Documentation ═══${NC}"
check_file "WORKLOAD_IDENTITY_SETUP.md" "Setup guide" "true"
check_file "MIGRATION_GUIDE.md" "Migration guide" "true"
check_file "IMPLEMENTATION_SUMMARY.md" "Implementation summary" "true"

echo -e "\n${BLUE}═══ Build Status ═══${NC}"
if [ -f "pom.xml" ]; then
    echo -e "${GREEN}✓${NC} Maven project found"
    if [ -d "target/classes" ]; then
        echo -e "${GREEN}✓${NC} Project has been compiled"
    else
        echo -e "${YELLOW}⚠${NC} Project not yet compiled"
        echo -e "  ${YELLOW}Run: mvn clean compile${NC}"
        ((WARNINGS++))
    fi
else
    echo -e "${RED}✗${NC} pom.xml not found"
    ((ERRORS++))
fi

# Check for sensitive files in git
echo -e "\n${BLUE}═══ Security Check ═══${NC}"
if [ -f ".gitignore" ]; then
    echo -e "${GREEN}✓${NC} .gitignore exists"
    
    # Check if certs directory is ignored
    if grep -q "^certs/" .gitignore; then
        echo -e "${GREEN}✓${NC} Certificates directory is gitignored"
    else
        echo -e "${RED}✗${NC} Certificates directory NOT in .gitignore"
        echo -e "  ${RED}Add 'certs/' to .gitignore to prevent committing secrets!${NC}"
        ((ERRORS++))
    fi
    
    # Check if *.pem is ignored
    if grep -q "^\*\.pem" .gitignore; then
        echo -e "${GREEN}✓${NC} PEM files are gitignored"
    else
        echo -e "${YELLOW}⚠${NC} PEM files might not be gitignored"
        ((WARNINGS++))
    fi
else
    echo -e "${RED}✗${NC} .gitignore not found"
    ((ERRORS++))
fi

# Check if in a git repository
if git rev-parse --git-dir > /dev/null 2>&1; then
    # Check if any sensitive files are tracked
    if git ls-files | grep -E '(\.pem|\.jwt|\.p12|service-account-key\.json)' > /dev/null 2>&1; then
        echo -e "${RED}✗${NC} Sensitive files found in git repository!"
        echo -e "  ${RED}Files found:${NC}"
        git ls-files | grep -E '(\.pem|\.jwt|\.p12|service-account-key\.json)' | while read file; do
            echo -e "    ${RED}- $file${NC}"
        done
        echo -e "  ${YELLOW}Remove with: git rm --cached <file>${NC}"
        ((ERRORS++))
    else
        echo -e "${GREEN}✓${NC} No sensitive files tracked in git"
    fi
fi

# Summary
echo -e "\n${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}                        SUMMARY                            ${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"

if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo -e "\n${GREEN}✓ All checks passed! Your setup is complete.${NC}\n"
    exit 0
elif [ $ERRORS -eq 0 ]; then
    echo -e "\n${YELLOW}⚠ $WARNINGS warning(s) found. Review the issues above.${NC}\n"
    exit 0
else
    echo -e "\n${RED}✗ $ERRORS error(s) and $WARNINGS warning(s) found.${NC}"
    echo -e "${RED}Please resolve the errors before proceeding.${NC}\n"
    
    if [ ! -f "certs/workload-cert.pem" ] || [ ! -f "certs/workload-key.pem" ]; then
        echo -e "${YELLOW}To generate certificates:${NC}"
        echo -e "  ${GREEN}./scripts/generate-certificates.sh${NC}\n"
    fi
    
    if [ ! -f "terraform/terraform.tfstate" ]; then
        echo -e "${YELLOW}To deploy infrastructure:${NC}"
        echo -e "  ${GREEN}cd terraform && terraform init && terraform apply${NC}\n"
    fi
    
    if [ ! -f "certs/token.jwt" ]; then
        echo -e "${YELLOW}To generate JWT token:${NC}"
        echo -e "  ${GREEN}./scripts/generate-jwt-token.sh${NC}\n"
    fi
    
    exit 1
fi
