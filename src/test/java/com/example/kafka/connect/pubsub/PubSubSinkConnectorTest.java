package com.example.kafka.connect.pubsub;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.util.HashMap;
import java.util.List;
import java.util.Map;

import static org.junit.jupiter.api.Assertions.*;

class PubSubSinkConnectorTest {

    private PubSubSinkConnector connector;
    private Map<String, String> props;

    @BeforeEach
    void setUp() {
        connector = new PubSubSinkConnector();
        props = new HashMap<>();
        props.put(PubSubSinkConnectorConfig.GCP_PROJECT_ID, "test-project");
        props.put(PubSubSinkConnectorConfig.PUBSUB_TOPIC, "test-topic");
    }

    @Test
    void testVersion() {
        assertNotNull(connector.version());
        assertEquals("1.0.0", connector.version());
    }

    @Test
    void testTaskClass() {
        assertEquals(PubSubSinkTask.class, connector.taskClass());
    }

    @Test
    void testStart() {
        assertDoesNotThrow(() -> connector.start(props));
    }

    @Test
    void testTaskConfigs() {
        connector.start(props);
        
        int maxTasks = 3;
        List<Map<String, String>> taskConfigs = connector.taskConfigs(maxTasks);
        
        assertEquals(maxTasks, taskConfigs.size());
        
        // Each task should have the same configuration
        for (Map<String, String> config : taskConfigs) {
            assertEquals("test-project", config.get(PubSubSinkConnectorConfig.GCP_PROJECT_ID));
            assertEquals("test-topic", config.get(PubSubSinkConnectorConfig.PUBSUB_TOPIC));
        }
    }

    @Test
    void testStop() {
        connector.start(props);
        assertDoesNotThrow(() -> connector.stop());
    }

    @Test
    void testConfigDef() {
        assertNotNull(connector.config());
        assertNotNull(connector.config().configKeys());
        
        // Verify required keys are present
        assertTrue(connector.config().configKeys().containsKey(PubSubSinkConnectorConfig.GCP_PROJECT_ID));
        assertTrue(connector.config().configKeys().containsKey(PubSubSinkConnectorConfig.PUBSUB_TOPIC));
    }
}
