package com.example.kafka.connect.pubsub;

import org.apache.kafka.common.config.ConfigException;
import org.junit.jupiter.api.Test;

import java.util.HashMap;
import java.util.Map;

import static org.junit.jupiter.api.Assertions.*;

class PubSubSinkConnectorConfigTest {

    @Test
    void testValidConfiguration() {
        Map<String, String> props = new HashMap<>();
        props.put(PubSubSinkConnectorConfig.GCP_PROJECT_ID, "test-project");
        props.put(PubSubSinkConnectorConfig.PUBSUB_TOPIC, "test-topic");
        props.put(PubSubSinkConnectorConfig.GCP_CREDENTIALS_FILE_PATH, "/path/to/credentials.json");

        PubSubSinkConnectorConfig config = new PubSubSinkConnectorConfig(props);

        assertEquals("test-project", config.getGcpProjectId());
        assertEquals("test-topic", config.getPubSubTopic());
        assertEquals("/path/to/credentials.json", config.getGcpCredentialsFilePath());
    }

    @Test
    void testDefaultValues() {
        Map<String, String> props = new HashMap<>();
        props.put(PubSubSinkConnectorConfig.GCP_PROJECT_ID, "test-project");
        props.put(PubSubSinkConnectorConfig.PUBSUB_TOPIC, "test-topic");

        PubSubSinkConnectorConfig config = new PubSubSinkConnectorConfig(props);

        assertEquals("", config.getGcpCredentialsFilePath());
        assertEquals("", config.getPubSubMessageBodyName());
        assertEquals("key", config.getPubSubOrderingKeySource());
        assertEquals(100, config.getPubSubBatchSize());
        assertEquals(30000L, config.getPubSubPublishTimeoutMs());
    }

    @Test
    void testMissingRequiredConfig() {
        Map<String, String> props = new HashMap<>();
        props.put(PubSubSinkConnectorConfig.GCP_PROJECT_ID, "test-project");
        // Missing PUBSUB_TOPIC

        assertThrows(ConfigException.class, () -> {
            new PubSubSinkConnectorConfig(props);
        });
    }

    @Test
    void testCustomBatchSize() {
        Map<String, String> props = new HashMap<>();
        props.put(PubSubSinkConnectorConfig.GCP_PROJECT_ID, "test-project");
        props.put(PubSubSinkConnectorConfig.PUBSUB_TOPIC, "test-topic");
        props.put(PubSubSinkConnectorConfig.PUBSUB_BATCH_SIZE, "250");

        PubSubSinkConnectorConfig config = new PubSubSinkConnectorConfig(props);

        assertEquals(250, config.getPubSubBatchSize());
    }

    @Test
    void testCustomTimeout() {
        Map<String, String> props = new HashMap<>();
        props.put(PubSubSinkConnectorConfig.GCP_PROJECT_ID, "test-project");
        props.put(PubSubSinkConnectorConfig.PUBSUB_TOPIC, "test-topic");
        props.put(PubSubSinkConnectorConfig.PUBSUB_PUBLISH_TIMEOUT_MS, "60000");

        PubSubSinkConnectorConfig config = new PubSubSinkConnectorConfig(props);

        assertEquals(60000L, config.getPubSubPublishTimeoutMs());
    }

    @Test
    void testOrderingKeySourceOptions() {
        Map<String, String> props = new HashMap<>();
        props.put(PubSubSinkConnectorConfig.GCP_PROJECT_ID, "test-project");
        props.put(PubSubSinkConnectorConfig.PUBSUB_TOPIC, "test-topic");

        // Test with "partition"
        props.put(PubSubSinkConnectorConfig.PUBSUB_ORDERING_KEY_SOURCE, "partition");
        PubSubSinkConnectorConfig config1 = new PubSubSinkConnectorConfig(props);
        assertEquals("partition", config1.getPubSubOrderingKeySource());

        // Test with custom field name
        props.put(PubSubSinkConnectorConfig.PUBSUB_ORDERING_KEY_SOURCE, "userId");
        PubSubSinkConnectorConfig config2 = new PubSubSinkConnectorConfig(props);
        assertEquals("userId", config2.getPubSubOrderingKeySource());
    }
}
