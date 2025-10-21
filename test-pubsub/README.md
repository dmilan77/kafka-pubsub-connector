# X.509 mTLS Pub/Sub Test

This is a standalone test program to verify X.509 mTLS authentication with Google Pub/Sub.

## Purpose

Test whether the X.509 mTLS credential configuration (`workload-identity-gcloud-config.json`) can successfully authenticate and publish messages to Google Pub/Sub.

## Prerequisites

- Java 11 or later
- Maven 3.6 or later
- X.509 certificates generated in `../certs/`
- Workload Identity credential configuration file

## Quick Start

1. Build and run the test:
   ```bash
   chmod +x run-test.sh
   ./run-test.sh
   ```

2. Or build and run manually:
   ```bash
   # Build
   mvn clean package -DskipTests
   
   # Run
   java -jar target/pubsub-x509-test.jar \
       ../certs/workload-identity-gcloud-config.json \
       service-projects-02 \
       kafka-to-gcp
   ```

## What It Tests

1. **Credential Loading**: Loads the X.509 mTLS credential configuration
2. **Publisher Creation**: Creates a Pub/Sub publisher with the credentials
3. **Message Publishing**: Publishes a test message to verify end-to-end connectivity

## Expected Outcomes

### Success
If X.509 mTLS is fully supported:
```
✓ Credentials loaded successfully
✓ Publisher created successfully
✓ Message published successfully!
=== TEST PASSED ===
```

### Failure (Current State)
If X.509 mTLS is not yet supported:
```
✗ TEST FAILED
Error: Missing credential source file location or URL

[DIAGNOSIS]
The credential configuration uses 'certificate' format which is not yet
supported by the Google Auth Java library.
```

## Dependencies

- `google-cloud-pubsub`: 1.133.0
- `google-auth-library-oauth2-http`: 1.29.0

## Files

- `PubSubX509Test.java` - Main test program
- `pom.xml` - Maven build configuration
- `run-test.sh` - Build and run script
- `README.md` - This file
