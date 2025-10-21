# Workload Identity Federation Configuration with OIDC/JWT (Alternative)

# Enable required APIs
resource "google_project_service" "iamcredentials" {
  service            = "iamcredentials.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "sts" {
  service            = "sts.googleapis.com"
  disable_on_destroy = false
}

# Create Workload Identity Pool
resource "google_iam_workload_identity_pool" "kafka_connector_pool" {
  project                  = var.project_id
  workload_identity_pool_id = var.workload_identity_pool_id
  display_name             = "Kafka Connector Pool"
  description              = "Workload Identity Pool for Kafka to PubSub Connector"
  disabled                 = false
}

# Create X.509 Workload Identity Provider  
# Note: This uses X.509 mTLS certificates for authentication
resource "google_iam_workload_identity_pool_provider" "x509_provider" {
  provider = google-beta
  
  workload_identity_pool_id          = google_iam_workload_identity_pool.kafka_connector_pool.workload_identity_pool_id
  workload_identity_pool_provider_id = "x509-mtls-provider"
  
  display_name = "X.509 Certificate Provider"
  description  = "X.509 mTLS authentication for Kafka Connector"

  # Attribute mapping from X.509 certificate to Google Cloud identity
  # Using only the Common Name (CN) from the certificate's Distinguished Name
  attribute_mapping = {
    "google.subject" = "assertion.subject.dn.cn"
  }

  # X.509 configuration
  x509 {
    trust_store {
      trust_anchors {
        pem_certificate = chomp(file("../certs/ca-cert.pem"))
      }
    }
  }
}

# Grant Service Account Token Creator role to the workload identity
resource "google_service_account_iam_member" "workload_identity_user" {
  service_account_id = google_service_account.kafka_connector.name
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = "principal://iam.googleapis.com/${google_iam_workload_identity_pool.kafka_connector_pool.name}/subject/${var.workload_subject_name}"
}

# Allow the workload identity to impersonate the service account
resource "google_service_account_iam_member" "workload_identity_impersonation" {
  service_account_id = google_service_account.kafka_connector.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principal://iam.googleapis.com/${google_iam_workload_identity_pool.kafka_connector_pool.name}/subject/${var.workload_subject_name}"
}

# Create credential configuration file
resource "local_file" "credential_config" {
  content = jsonencode({
    type                = "external_account"
    audience           = "//iam.googleapis.com/${google_iam_workload_identity_pool.kafka_connector_pool.name}/providers/${google_iam_workload_identity_pool_provider.x509_provider.workload_identity_pool_provider_id}"
    subject_token_type = "urn:ietf:params:oauth:token-type:mtls"
    token_url          = "https://sts.mtls.googleapis.com/v1/token"
    credential_source = {
      certificate = {
        certificate_config_location = var.jwt_token_file_path
      }
    }
    service_account_impersonation_url = "https://iamcredentials.mtls.googleapis.com/v1/projects/-/serviceAccounts/${google_service_account.kafka_connector.email}:generateAccessToken"
  })
  filename        = "${path.module}/workload-identity-credential.json"
  file_permission = "0600"
}

# Output for debugging and verification
resource "local_file" "workload_identity_info" {
  content = <<-EOT
    Workload Identity Federation Configuration
    ==========================================
    
    Pool Name: ${google_iam_workload_identity_pool.kafka_connector_pool.name}
    Pool ID: ${google_iam_workload_identity_pool.kafka_connector_pool.workload_identity_pool_id}
    
    Provider Name: ${google_iam_workload_identity_pool_provider.x509_provider.name}
    Provider ID: ${google_iam_workload_identity_pool_provider.x509_provider.workload_identity_pool_provider_id}
    
    Service Account: ${google_service_account.kafka_connector.email}
    
    Audience: //iam.googleapis.com/${google_iam_workload_identity_pool.kafka_connector_pool.name}/providers/${google_iam_workload_identity_pool_provider.x509_provider.workload_identity_pool_provider_id}
    
    Credential Configuration File: ${path.module}/workload-identity-credential.json
    
    To authenticate:
    1. Use your X.509 certificate and private key
    2. Certificate subject CN will be mapped to: ${var.workload_subject_name}
    3. Use the credential configuration file with Google Cloud client libraries
    
    Principal Identifier:
    principal://iam.googleapis.com/${google_iam_workload_identity_pool.kafka_connector_pool.name}/subject/${var.workload_subject_name}
    
    Note: This configuration uses X.509 mTLS certificates for direct authentication.
    The certificate's Common Name (CN) is used as the subject identifier.
  EOT
  
  filename        = "${path.module}/workload-identity-setup.txt"
  file_permission = "0644"
}
