# Enable required APIs
resource "google_project_service" "pubsub" {
  service            = "pubsub.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "iam" {
  service            = "iam.googleapis.com"
  disable_on_destroy = false
}

# Create Pub/Sub Topic
resource "google_pubsub_topic" "kafka_topic" {
  name = var.pubsub_topic_name

  message_retention_duration = var.message_retention_duration

  depends_on = [google_project_service.pubsub]
}

# Create Pub/Sub Subscription
resource "google_pubsub_subscription" "kafka_subscription" {
  name  = var.pubsub_subscription_name
  topic = google_pubsub_topic.kafka_topic.name

  # Acknowledge deadline
  ack_deadline_seconds = 20

  # Message retention
  message_retention_duration = var.message_retention_duration

  # Retry policy
  retry_policy {
    minimum_backoff = "10s"
    maximum_backoff = "600s"
  }

  # Enable message ordering if specified
  enable_message_ordering = var.enable_message_ordering

  # Dead letter policy (optional)
  # Uncomment and configure if needed
  # dead_letter_policy {
  #   dead_letter_topic     = google_pubsub_topic.dead_letter_topic.id
  #   max_delivery_attempts = 5
  # }

  expiration_policy {
    ttl = "" # Never expire
  }
}

# Service Account for Kafka Connector
resource "google_service_account" "kafka_connector" {
  account_id   = var.service_account_name
  display_name = "Kafka to Pub/Sub Connector Service Account"
  description  = "Service account used by Kafka Connect to publish messages to Pub/Sub"

  depends_on = [google_project_service.iam]
}

# Grant Pub/Sub Publisher role to service account
resource "google_pubsub_topic_iam_member" "publisher" {
  topic  = google_pubsub_topic.kafka_topic.name
  role   = "roles/pubsub.publisher"
  member = "serviceAccount:${google_service_account.kafka_connector.email}"
}

# Grant Pub/Sub Viewer role to service account (for topic validation)
resource "google_project_iam_member" "pubsub_viewer" {
  project = var.project_id
  role    = "roles/pubsub.viewer"
  member  = "serviceAccount:${google_service_account.kafka_connector.email}"
}

# Create service account key (always created, but file only saved when not using Workload Identity)
resource "google_service_account_key" "kafka_connector_key" {
  service_account_id = google_service_account.kafka_connector.name
}

# Save the service account key to a file (only if not using Workload Identity)
resource "local_file" "service_account_key" {
  count           = var.use_workload_identity ? 0 : 1
  content         = base64decode(google_service_account_key.kafka_connector_key.private_key)
  filename        = "${path.module}/service-account-key.json"
  file_permission = "0600"
}
