package com.example.kafka.connect.pubsub;

import com.google.api.core.ApiFuture;
import com.google.api.core.ApiFutureCallback;
import com.google.api.core.ApiFutures;
import com.google.api.gax.core.CredentialsProvider;
import com.google.api.gax.core.FixedCredentialsProvider;
import com.google.api.gax.rpc.ApiException;
import com.google.auth.oauth2.GoogleCredentials;
import com.google.cloud.pubsub.v1.Publisher;
import com.google.common.util.concurrent.MoreExecutors;
import com.google.protobuf.ByteString;
import com.google.pubsub.v1.PubsubMessage;
import com.google.pubsub.v1.TopicName;
import org.apache.kafka.clients.consumer.OffsetAndMetadata;
import org.apache.kafka.common.TopicPartition;
import org.apache.kafka.connect.data.Struct;
import org.apache.kafka.connect.errors.ConnectException;
import org.apache.kafka.connect.errors.RetriableException;
import org.apache.kafka.connect.sink.SinkRecord;
import org.apache.kafka.connect.sink.SinkTask;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.io.FileInputStream;
import java.io.IOException;
import java.util.Collection;
import java.util.Map;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicInteger;

/**
 * Kafka Connect Sink Task that publishes messages to Google Cloud Pub/Sub
 */
public class PubSubSinkTask extends SinkTask {
    
    private static final Logger log = LoggerFactory.getLogger(PubSubSinkTask.class);
    
    private PubSubSinkConnectorConfig config;
    private Publisher publisher;
    private AtomicInteger errorCount = new AtomicInteger(0);
    
    @Override
    public String version() {
        return "1.0.0";
    }

    @Override
    public void start(Map<String, String> props) {
        log.info("Starting PubSubSinkTask");
        
        try {
            config = new PubSubSinkConnectorConfig(props);
            publisher = createPublisher();
            log.info("PubSubSinkTask started successfully");
        } catch (Exception e) {
            log.error("Failed to start PubSubSinkTask", e);
            throw new ConnectException("Failed to start PubSubSinkTask", e);
        }
    }

    private Publisher createPublisher() throws IOException {
        String projectId = config.getGcpProjectId();
        String topicName = config.getPubSubTopic();
        
        TopicName topic = TopicName.of(projectId, topicName);
        Publisher.Builder builder = Publisher.newBuilder(topic);
        
        // Load credentials from file path if provided
        String credentialsPath = config.getGcpCredentialsFilePath();
        if (credentialsPath != null && !credentialsPath.isEmpty()) {
            log.info("Loading credentials from file: {}", credentialsPath);
            try {
                GoogleCredentials credentials = GoogleCredentials.fromStream(
                    new FileInputStream(credentialsPath)
                );
                CredentialsProvider credentialsProvider = FixedCredentialsProvider.create(credentials);
                builder.setCredentialsProvider(credentialsProvider);
                log.info("Successfully loaded credentials from file");
            } catch (IOException e) {
                log.error("Failed to load credentials from file: {}", credentialsPath, e);
                throw e;
            }
        } else {
            log.warn("No credentials file path configured, using Application Default Credentials");
        }
        
        return builder.build();
    }

    @Override
    public void put(Collection<SinkRecord> records) {
        if (records.isEmpty()) {
            return;
        }
        
        log.debug("Received {} records", records.size());
        
        for (SinkRecord record : records) {
            try {
                publishRecord(record);
            } catch (Exception e) {
                log.error("Error publishing record to Pub/Sub: topic={}, partition={}, offset={}",
                        record.topic(), record.kafkaPartition(), record.kafkaOffset(), e);
                
                if (errorCount.incrementAndGet() > 10) {
                    throw new RetriableException("Too many errors publishing to Pub/Sub", e);
                }
                throw new RetriableException("Error publishing to Pub/Sub", e);
            }
        }
    }

    private void publishRecord(SinkRecord record) {
        try {
            PubsubMessage message = convertToPubSubMessage(record);
            
            ApiFuture<String> messageIdFuture = publisher.publish(message);
            
            ApiFutures.addCallback(messageIdFuture, new ApiFutureCallback<String>() {
                @Override
                public void onSuccess(String messageId) {
                    log.debug("Published message with ID: {}", messageId);
                    errorCount.set(0); // Reset error count on success
                }

                @Override
                public void onFailure(Throwable throwable) {
                    if (throwable instanceof ApiException) {
                        ApiException apiException = (ApiException) throwable;
                        log.error("API error publishing message: status={}", 
                                apiException.getStatusCode(), throwable);
                    } else {
                        log.error("Error publishing message", throwable);
                    }
                }
            }, MoreExecutors.directExecutor());
            
        } catch (Exception e) {
            log.error("Error converting record to Pub/Sub message", e);
            throw new RetriableException("Error converting record", e);
        }
    }

    private PubsubMessage convertToPubSubMessage(SinkRecord record) {
        PubsubMessage.Builder messageBuilder = PubsubMessage.newBuilder();
        
        // Set message data
        ByteString data = extractMessageData(record);
        messageBuilder.setData(data);
        
        // Set ordering key
        String orderingKey = extractOrderingKey(record);
        if (orderingKey != null && !orderingKey.isEmpty()) {
            messageBuilder.setOrderingKey(orderingKey);
        }
        
        // Add attributes
        messageBuilder.putAttributes("kafka.topic", record.topic());
        messageBuilder.putAttributes("kafka.partition", String.valueOf(record.kafkaPartition()));
        messageBuilder.putAttributes("kafka.offset", String.valueOf(record.kafkaOffset()));
        
        if (record.timestamp() != null) {
            messageBuilder.putAttributes("kafka.timestamp", String.valueOf(record.timestamp()));
        }
        
        return messageBuilder.build();
    }

    private ByteString extractMessageData(SinkRecord record) {
        Object value = record.value();
        
        if (value == null) {
            return ByteString.copyFromUtf8("");
        }
        
        String bodyFieldName = config.getPubSubMessageBodyName();
        
        // If body field name is specified, extract that field
        if (bodyFieldName != null && !bodyFieldName.isEmpty()) {
            if (value instanceof Struct) {
                Struct struct = (Struct) value;
                Object fieldValue = struct.get(bodyFieldName);
                return ByteString.copyFromUtf8(fieldValue != null ? fieldValue.toString() : "");
            }
        }
        
        // Otherwise use the entire value
        if (value instanceof String) {
            return ByteString.copyFromUtf8((String) value);
        } else if (value instanceof byte[]) {
            return ByteString.copyFrom((byte[]) value);
        } else {
            return ByteString.copyFromUtf8(value.toString());
        }
    }

    private String extractOrderingKey(SinkRecord record) {
        String orderingKeySource = config.getPubSubOrderingKeySource();
        
        if (orderingKeySource == null || orderingKeySource.isEmpty()) {
            return null;
        }
        
        switch (orderingKeySource.toLowerCase()) {
            case "key":
                return record.key() != null ? record.key().toString() : null;
            case "partition":
                return String.valueOf(record.kafkaPartition());
            default:
                // Try to extract from value
                if (record.value() instanceof Struct) {
                    Struct struct = (Struct) record.value();
                    try {
                        Object fieldValue = struct.get(orderingKeySource);
                        return fieldValue != null ? fieldValue.toString() : null;
                    } catch (Exception e) {
                        log.warn("Could not extract ordering key from field: {}", orderingKeySource);
                        return null;
                    }
                }
                return null;
        }
    }

    @Override
    public void flush(Map<TopicPartition, OffsetAndMetadata> currentOffsets) {
        log.debug("Flushing records");
        // Publisher will handle batching and publishing
    }

    @Override
    public void stop() {
        log.info("Stopping PubSubSinkTask");
        
        if (publisher != null) {
            try {
                publisher.shutdown();
                publisher.awaitTermination(config.getPubSubPublishTimeoutMs(), TimeUnit.MILLISECONDS);
            } catch (Exception e) {
                log.error("Error stopping publisher", e);
            }
        }
        
        log.info("PubSubSinkTask stopped");
    }
}
