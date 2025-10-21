package com.example.kafka.connect.pubsub;

import org.apache.kafka.common.config.ConfigDef;
import org.apache.kafka.common.config.ConfigException;
import org.apache.kafka.connect.connector.Task;
import org.apache.kafka.connect.sink.SinkConnector;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;

/**
 * Kafka Connect Sink Connector for Google Cloud Pub/Sub
 */
public class PubSubSinkConnector extends SinkConnector {
    
    private static final Logger log = LoggerFactory.getLogger(PubSubSinkConnector.class);
    
    private Map<String, String> configProps;
    
    @Override
    public String version() {
        return "1.0.0";
    }

    @Override
    public void start(Map<String, String> props) {
        log.info("Starting PubSubSinkConnector");
        this.configProps = props;
        
        try {
            new PubSubSinkConnectorConfig(props);
        } catch (ConfigException e) {
            log.error("Invalid configuration", e);
            throw e;
        }
        
        log.info("PubSubSinkConnector started successfully");
    }

    @Override
    public Class<? extends Task> taskClass() {
        return PubSubSinkTask.class;
    }

    @Override
    public List<Map<String, String>> taskConfigs(int maxTasks) {
        log.info("Creating {} task configurations", maxTasks);
        List<Map<String, String>> configs = new ArrayList<>(maxTasks);
        
        for (int i = 0; i < maxTasks; i++) {
            configs.add(configProps);
        }
        
        return configs;
    }

    @Override
    public void stop() {
        log.info("Stopping PubSubSinkConnector");
    }

    @Override
    public ConfigDef config() {
        return PubSubSinkConnectorConfig.CONFIG_DEF;
    }
}
