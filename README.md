# Kafka to Google Cloud Pub/Sub Connector

A Kafka Connect sink connector that publishes messages from Apache Kafka to Google Cloud Pub/Sub with support for both Service Account Keys and X.509 certificate-based Workload Identity Federation.

## Features

- **Dual Authentication Support**:
  - Service Account Key authentication (traditional)
  - X.509 mTLS Workload Identity Federation (enhanced security)
- Real-time message streaming from Kafka to Pub/Sub
- Configurable batch size and timeout settings
- Ordering key support for message sequencing
- Automatic retry and error handling
- Docker Compose setup for local development

## Prerequisites

- Java 11 or higher
- Maven 3.6+
- Docker and Docker Compose
- Google Cloud Project with Pub/Sub API enabled
- gcloud CLI configured

## Quick Start

### 1. Start Kafka Environment

```bash
./start-kafka.sh
```

This starts Zookeeper, Kafka, Kafka Connect, and Kafka UI (http://localhost:8080).

### 2. Deploy Infrastructure (Terraform)

```bash
cd terraform
terraform init
terraform apply
```

This creates:
- Google Pub/Sub topic and subscription
- Service account with appropriate permissions
- X.509 Workload Identity Pool and Provider
- Service account key (for traditional auth)

### 3. Build the Connector

```bash
mvn clean package
cp target/kafka-pubsub-connector-1.0.0.jar connector-jars/
```

### 4. Deploy Connector

**Option A: Service Account Key (Traditional)**
```bash
./deploy-connector.sh
```

**Option B: X.509 mTLS Workload Identity**
```bash
curl -X POST http://localhost:8083/connectors \
  -H "Content-Type: application/json" \
  -d @config/connector-config-x509.json
```

### 5. Send Test Messages

```bash
./test-connector.sh
```

Or manually:
```bash
echo '{"message": "Hello from Kafka!", "timestamp": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"}' | \
  docker exec -i kafka-broker kafka-console-producer \
  --bootstrap-server localhost:9092 \
  --topic test-topic
```

### 6. Verify Messages in Pub/Sub

```bash
gcloud pubsub subscriptions pull kafka-to-gcp-sub \
  --limit=5 \
  --auto-ack \
  --project=service-projects-02
```

## Testing

### Test X.509 mTLS Authentication

Run the standalone test program:

```bash
cd test-pubsub
mvn exec:java -Dexec.mainClass="PubSubX509Test" \
  -Dexec.args="../certs/workload-identity-gcloud-config-local.json service-projects-02 kafka-to-gcp"
```

### Health Check

```bash
./health-check.sh
```

Checks connector status, task status, and recent logs.

## Scripts

| Script | Purpose |
|--------|---------|
| `start-kafka.sh` | Start all Kafka services (Zookeeper, Kafka, Connect, UI) |
| `stop-kafka.sh` | Stop all Kafka services |
| `deploy-connector.sh` | Deploy connector with service account key |
| `test-connector.sh` | Send test messages to Kafka |
| `health-check.sh` | Check connector and service health |
| `setup.sh` | Initial environment setup |

## Configuration

### Service Account Key Authentication

Edit `config/connector-config.json`:
```json
{
  "gcp.credentials.file.path": "/etc/kafka-connect/credentials/service-account-key.json"
}
```

### X.509 mTLS Workload Identity

Edit `config/connector-config-x509.json`:
```json
{
  "gcp.credentials.file.path": "/etc/kafka-connect/certs/workload-identity-docker-config.json"
}
```

## Architecture

```
┌─────────┐      ┌──────────────┐      ┌─────────────┐
│  Kafka  │ ───> │ Kafka Connect│ ───> │  Pub/Sub    │
│  Topic  │      │  Connector   │      │   Topic     │
└─────────┘      └──────────────┘      └─────────────┘
                        │
                        ├─ Service Account Key (traditional)
                        └─ X.509 mTLS Workload Identity (enhanced)
```

## Troubleshooting

**Connector fails to start:**
```bash
# Check logs
docker logs kafka-connect

# Check connector status
curl http://localhost:8083/connectors/pubsub-sink-connector/status
```

**Messages not appearing in Pub/Sub:**
```bash
# Check connector tasks
curl http://localhost:8083/connectors/pubsub-sink-connector/status | python3 -m json.tool

# Verify Pub/Sub permissions
gcloud pubsub topics get-iam-policy kafka-to-gcp --project=service-projects-02
```

**X.509 certificate issues:**
```bash
# Verify certificate
openssl x509 -in certs/workload-cert.pem -text -noout

# Check provider
gcloud iam workload-identity-pools providers list \
  --workload-identity-pool=kafka-connector-pool \
  --location=global \
  --project=service-projects-02
```

## Cleanup

```bash
# Stop services
./stop-kafka.sh

# Destroy infrastructure
cd terraform
terraform destroy

# Remove Docker volumes
docker-compose down -v
```


