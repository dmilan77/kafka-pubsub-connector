#!/bin/bash

# Build and run the X.509 mTLS Pub/Sub test program

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "==================================="
echo "Building X.509 mTLS Test Program"
echo "==================================="
echo

# Build the project
mvn clean package -DskipTests

echo
echo "==================================="
echo "Running Test"
echo "==================================="
echo

# Run the test
java -jar target/pubsub-x509-test.jar \
    ../certs/workload-identity-gcloud-config.json \
    service-projects-02 \
    kafka-to-gcp

echo
echo "Test complete."
