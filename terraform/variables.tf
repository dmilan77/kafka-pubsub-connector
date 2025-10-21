variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP Region"
  type        = string
  default     = "us-central1"
}

variable "pubsub_topic_name" {
  description = "Name of the Pub/Sub topic"
  type        = string
  default     = "kafka-to-gcp"
}

variable "pubsub_subscription_name" {
  description = "Name of the Pub/Sub subscription"
  type        = string
  default     = "kafka-to-gcp-sub"
}

variable "service_account_name" {
  description = "Name of the service account for Kafka connector"
  type        = string
  default     = "kafka-pubsub-connector"
}

variable "enable_message_ordering" {
  description = "Enable message ordering for Pub/Sub topic"
  type        = bool
  default     = true
}

variable "message_retention_duration" {
  description = "Message retention duration in seconds"
  type        = string
  default     = "604800s" # 7 days
}

# Workload Identity Federation Variables
variable "workload_identity_pool_id" {
  description = "ID for the Workload Identity Pool"
  type        = string
  default     = "kafka-connector-pool"
}

variable "workload_identity_provider_id" {
  description = "ID for the Workload Identity Provider"
  type        = string
  default     = "x509-provider"
}

variable "x509_certificate_path" {
  description = "Path to the X.509 certificate PEM file"
  type        = string
  default     = "../certs/workload-cert.pem"
}

variable "certificate_subject" {
  description = "Subject from the X.509 certificate (CN value)"
  type        = string
  default     = "CN=kafka-connector-workload,OU=Engineering,O=Kafka PubSub Connector,L=San Francisco,ST=California,C=US"
}

variable "workload_subject_name" {
  description = "Subject name extracted from the certificate CN for workload identity binding"
  type        = string
  default     = "kafka-connector-workload"
}

variable "jwt_token_file_path" {
  description = "Path to the JWT token file for authentication"
  type        = string
  default     = "../certs/token.jwt"
}

variable "use_workload_identity" {
  description = "Whether to use Workload Identity Federation (true) or service account keys (false)"
  type        = bool
  default     = true
}
