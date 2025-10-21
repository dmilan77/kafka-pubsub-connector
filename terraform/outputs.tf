output "pubsub_topic_name" {
  description = "The name of the created Pub/Sub topic"
  value       = google_pubsub_topic.kafka_topic.name
}

output "pubsub_topic_id" {
  description = "The ID of the created Pub/Sub topic"
  value       = google_pubsub_topic.kafka_topic.id
}

output "pubsub_subscription_name" {
  description = "The name of the created Pub/Sub subscription"
  value       = google_pubsub_subscription.kafka_subscription.name
}

output "pubsub_subscription_id" {
  description = "The ID of the created Pub/Sub subscription"
  value       = google_pubsub_subscription.kafka_subscription.id
}

output "service_account_email" {
  description = "Email address of the service account"
  value       = google_service_account.kafka_connector.email
}

output "service_account_key_file" {
  description = "Path to the service account key file"
  value       = var.use_workload_identity ? "N/A - Using Workload Identity" : local_file.service_account_key[0].filename
}

output "project_id" {
  description = "GCP Project ID"
  value       = var.project_id
}

# Workload Identity outputs
output "workload_identity_pool_name" {
  description = "The full name of the Workload Identity Pool"
  value       = var.use_workload_identity ? google_iam_workload_identity_pool.kafka_connector_pool.name : "N/A"
}

output "workload_identity_provider_name" {
  description = "The full name of the Workload Identity Provider"
  value       = var.use_workload_identity ? google_iam_workload_identity_pool_provider.x509_provider.name : "N/A"
}

output "workload_identity_audience" {
  description = "The audience value for Workload Identity Federation"
  value       = var.use_workload_identity ? "//iam.googleapis.com/${google_iam_workload_identity_pool.kafka_connector_pool.name}/providers/${google_iam_workload_identity_pool_provider.x509_provider.workload_identity_pool_provider_id}" : "N/A"
}

output "credential_config_file" {
  description = "Path to the credential configuration file for Workload Identity"
  value       = var.use_workload_identity ? local_file.credential_config.filename : "N/A"
}
