package com.example.kafka.connect.pubsub;

import org.apache.kafka.common.config.AbstractConfig;
import org.apache.kafka.common.config.ConfigDef;
import org.apache.kafka.common.config.ConfigDef.Importance;
import org.apache.kafka.common.config.ConfigDef.Type;

import java.util.Map;

/**
 * Configuration for the Pub/Sub Sink Connector
 */
public class PubSubSinkConnectorConfig extends AbstractConfig {

    // Configuration Keys
    public static final String GCP_PROJECT_ID = "gcp.project.id";
    public static final String GCP_PROJECT_ID_DOC = "Google Cloud Project ID";
    
    public static final String PUBSUB_TOPIC = "pubsub.topic";
    public static final String PUBSUB_TOPIC_DOC = "Google Cloud Pub/Sub topic name";
    
    public static final String GCP_CREDENTIALS_FILE_PATH = "gcp.credentials.file.path";
    public static final String GCP_CREDENTIALS_FILE_PATH_DOC = "Path to GCP service account credentials JSON file (deprecated - use workload identity instead)";
    public static final String GCP_CREDENTIALS_FILE_PATH_DEFAULT = "";
    
    public static final String GCP_WORKLOAD_IDENTITY_ENABLED = "gcp.workload.identity.enabled";
    public static final String GCP_WORKLOAD_IDENTITY_ENABLED_DOC = "Enable Workload Identity Federation with X.509 certificates";
    public static final boolean GCP_WORKLOAD_IDENTITY_ENABLED_DEFAULT = true;
    
    public static final String GCP_WORKLOAD_CREDENTIAL_CONFIG = "gcp.workload.credential.config";
    public static final String GCP_WORKLOAD_CREDENTIAL_CONFIG_DOC = "Path to Workload Identity credential configuration JSON file";
    public static final String GCP_WORKLOAD_CREDENTIAL_CONFIG_DEFAULT = "";
    
    public static final String PUBSUB_MESSAGE_BODY_NAME = "pubsub.message.body.name";
    public static final String PUBSUB_MESSAGE_BODY_NAME_DOC = "The field name from Kafka record value to use as Pub/Sub message body. If not set, entire value is used.";
    public static final String PUBSUB_MESSAGE_BODY_NAME_DEFAULT = "";
    
    public static final String PUBSUB_ORDERING_KEY_SOURCE = "pubsub.ordering.key.source";
    public static final String PUBSUB_ORDERING_KEY_SOURCE_DOC = "Source for ordering key: 'key' to use Kafka key, 'partition' to use partition number, or field name from value";
    public static final String PUBSUB_ORDERING_KEY_SOURCE_DEFAULT = "key";
    
    public static final String PUBSUB_BATCH_SIZE = "pubsub.batch.size";
    public static final String PUBSUB_BATCH_SIZE_DOC = "Maximum number of messages to batch before publishing to Pub/Sub";
    public static final int PUBSUB_BATCH_SIZE_DEFAULT = 100;
    
    public static final String PUBSUB_PUBLISH_TIMEOUT_MS = "pubsub.publish.timeout.ms";
    public static final String PUBSUB_PUBLISH_TIMEOUT_MS_DOC = "Timeout in milliseconds for publishing to Pub/Sub";
    public static final long PUBSUB_PUBLISH_TIMEOUT_MS_DEFAULT = 30000L;

    public static final ConfigDef CONFIG_DEF = new ConfigDef()
            .define(GCP_PROJECT_ID, 
                    Type.STRING, 
                    Importance.HIGH,
                    GCP_PROJECT_ID_DOC)
            .define(PUBSUB_TOPIC,
                    Type.STRING,
                    Importance.HIGH,
                    PUBSUB_TOPIC_DOC)
            .define(GCP_CREDENTIALS_FILE_PATH,
                    Type.STRING,
                    GCP_CREDENTIALS_FILE_PATH_DEFAULT,
                    Importance.LOW,
                    GCP_CREDENTIALS_FILE_PATH_DOC)
            .define(GCP_WORKLOAD_IDENTITY_ENABLED,
                    Type.BOOLEAN,
                    GCP_WORKLOAD_IDENTITY_ENABLED_DEFAULT,
                    Importance.HIGH,
                    GCP_WORKLOAD_IDENTITY_ENABLED_DOC)
            .define(GCP_WORKLOAD_CREDENTIAL_CONFIG,
                    Type.STRING,
                    GCP_WORKLOAD_CREDENTIAL_CONFIG_DEFAULT,
                    Importance.HIGH,
                    GCP_WORKLOAD_CREDENTIAL_CONFIG_DOC)
            .define(PUBSUB_MESSAGE_BODY_NAME,
                    Type.STRING,
                    PUBSUB_MESSAGE_BODY_NAME_DEFAULT,
                    Importance.MEDIUM,
                    PUBSUB_MESSAGE_BODY_NAME_DOC)
            .define(PUBSUB_ORDERING_KEY_SOURCE,
                    Type.STRING,
                    PUBSUB_ORDERING_KEY_SOURCE_DEFAULT,
                    Importance.MEDIUM,
                    PUBSUB_ORDERING_KEY_SOURCE_DOC)
            .define(PUBSUB_BATCH_SIZE,
                    Type.INT,
                    PUBSUB_BATCH_SIZE_DEFAULT,
                    Importance.LOW,
                    PUBSUB_BATCH_SIZE_DOC)
            .define(PUBSUB_PUBLISH_TIMEOUT_MS,
                    Type.LONG,
                    PUBSUB_PUBLISH_TIMEOUT_MS_DEFAULT,
                    Importance.LOW,
                    PUBSUB_PUBLISH_TIMEOUT_MS_DOC);

    public PubSubSinkConnectorConfig(Map<?, ?> originals) {
        super(CONFIG_DEF, originals);
    }

    public String getGcpProjectId() {
        return getString(GCP_PROJECT_ID);
    }

    public String getPubSubTopic() {
        return getString(PUBSUB_TOPIC);
    }

    public String getGcpCredentialsFilePath() {
        return getString(GCP_CREDENTIALS_FILE_PATH);
    }

    public boolean isWorkloadIdentityEnabled() {
        return getBoolean(GCP_WORKLOAD_IDENTITY_ENABLED);
    }

    public String getWorkloadCredentialConfig() {
        return getString(GCP_WORKLOAD_CREDENTIAL_CONFIG);
    }

    public String getPubSubMessageBodyName() {
        return getString(PUBSUB_MESSAGE_BODY_NAME);
    }

    public String getPubSubOrderingKeySource() {
        return getString(PUBSUB_ORDERING_KEY_SOURCE);
    }

    public int getPubSubBatchSize() {
        return getInt(PUBSUB_BATCH_SIZE);
    }

    public long getPubSubPublishTimeoutMs() {
        return getLong(PUBSUB_PUBLISH_TIMEOUT_MS);
    }
}
