.PHONY: help build test clean start stop deploy-connector test-connector health-check terraform-init terraform-apply terraform-destroy

help: ## Show this help message
	@echo 'Usage: make [target]'
	@echo ''
	@echo 'Available targets:'
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  %-20s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

build: ## Build the connector JAR
	mvn clean package

test: ## Run unit tests
	mvn test

clean: ## Clean build artifacts
	mvn clean
	rm -rf connector-jars/*.jar

start: ## Start local Kafka environment
	./start-kafka.sh

stop: ## Stop local Kafka environment
	./stop-kafka.sh

deploy-connector: ## Deploy the connector to Kafka Connect
	./deploy-connector.sh

test-connector: ## Run connector integration tests
	./test-connector.sh

health-check: ## Check health status of all services
	./health-check.sh

terraform-init: ## Initialize Terraform
	cd terraform && terraform init

terraform-plan: ## Show Terraform execution plan
	cd terraform && terraform plan

terraform-apply: ## Apply Terraform configuration
	cd terraform && terraform apply

terraform-destroy: ## Destroy Terraform resources
	cd terraform && terraform destroy

all: build start deploy-connector ## Build, start Kafka, and deploy connector
