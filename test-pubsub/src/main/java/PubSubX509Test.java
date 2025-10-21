import com.google.api.core.ApiFuture;
import com.google.api.gax.core.FixedCredentialsProvider;
import com.google.auth.oauth2.GoogleCredentials;
import com.google.cloud.pubsub.v1.Publisher;
import com.google.protobuf.ByteString;
import com.google.pubsub.v1.PubsubMessage;
import com.google.pubsub.v1.TopicName;

import java.io.FileInputStream;
import java.nio.charset.StandardCharsets;
import java.time.Instant;

/**
 * Test program to verify X.509 mTLS authentication with Google Pub/Sub
 */
public class PubSubX509Test {
    
    public static void main(String[] args) {
        if (args.length < 3) {
            System.err.println("Usage: java PubSubX509Test <credential-config-path> <project-id> <topic-id>");
            System.err.println("Example: java PubSubX509Test certs/workload-identity-gcloud-config.json service-projects-02 kafka-to-gcp");
            System.exit(1);
        }
        
        String credentialConfigPath = args[0];
        String projectId = args[1];
        String topicId = args[2];
        
        System.out.println("=== X.509 mTLS Pub/Sub Test ===");
        System.out.println("Credential Config: " + credentialConfigPath);
        System.out.println("Project ID: " + projectId);
        System.out.println("Topic ID: " + topicId);
        System.out.println();
        
        Publisher publisher = null;
        try {
            // Load credentials from the X.509 mTLS configuration
            System.out.println("Loading credentials from: " + credentialConfigPath);
            GoogleCredentials credentials = GoogleCredentials.fromStream(
                new FileInputStream(credentialConfigPath)
            ).createScoped("https://www.googleapis.com/auth/pubsub");
            
            System.out.println("✓ Credentials loaded successfully");
            System.out.println("  Credential type: " + credentials.getClass().getName());
            
            // Create topic name
            TopicName topicName = TopicName.of(projectId, topicId);
            System.out.println("✓ Topic name created: " + topicName.toString());
            
            // Create publisher
            System.out.println("\nCreating publisher...");
            publisher = Publisher.newBuilder(topicName)
                .setCredentialsProvider(FixedCredentialsProvider.create(credentials))
                .build();
            
            System.out.println("✓ Publisher created successfully");
            
            // Publish a test message
            String messageText = "X.509 mTLS Test Message - " + Instant.now().toString();
            PubsubMessage message = PubsubMessage.newBuilder()
                .setData(ByteString.copyFrom(messageText, StandardCharsets.UTF_8))
                .putAttributes("test", "x509-mtls")
                .putAttributes("timestamp", Instant.now().toString())
                .build();
            
            System.out.println("\nPublishing test message...");
            System.out.println("  Message: " + messageText);
            
            ApiFuture<String> future = publisher.publish(message);
            String messageId = future.get();
            
            System.out.println("✓ Message published successfully!");
            System.out.println("  Message ID: " + messageId);
            
            System.out.println("\n=== TEST PASSED ===");
            System.out.println("X.509 mTLS authentication is working!");
            
        } catch (Exception e) {
            System.err.println("\n✗ TEST FAILED");
            System.err.println("Error: " + e.getMessage());
            System.err.println("\nStack trace:");
            e.printStackTrace();
            
            // Check for specific error types
            if (e.getMessage() != null) {
                if (e.getMessage().contains("Missing credential source file location or URL")) {
                    System.err.println("\n[DIAGNOSIS]");
                    System.err.println("The credential configuration uses 'certificate' format which is not yet");
                    System.err.println("supported by the Google Auth Java library. The library only supports");
                    System.err.println("'file' or 'url' formats in credential_source.");
                    System.err.println("\nPossible solutions:");
                    System.err.println("1. Use service account key authentication instead");
                    System.err.println("2. Wait for Google to add X.509 mTLS support to Java client libraries");
                    System.err.println("3. Implement custom credential provider using STS mTLS API directly");
                }
            }
            
            System.exit(1);
        } finally {
            if (publisher != null) {
                try {
                    publisher.shutdown();
                    System.out.println("\nPublisher shut down cleanly");
                } catch (Exception e) {
                    System.err.println("Error shutting down publisher: " + e.getMessage());
                }
            }
        }
    }
}
