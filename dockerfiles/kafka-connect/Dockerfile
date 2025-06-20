FROM confluentinc/cp-server-connect:7.7.0

# Set working directory
WORKDIR /tmp

# Install confluent-hub plugins with specific, compatible versions.
# Check the Confluent Hub or plugin's documentation for versions
# compatible with Confluent Platform 7.7.0.
RUN confluent-hub install --no-prompt clickhouse/clickhouse-kafka-connect:v1.3.1
RUN confluent-hub install --no-prompt confluentinc/kafka-connect-jdbc:10.7.6

# The 'connect-transforms' plugin is already included in the base image.
# Installing it again can cause dependency conflicts.
# RUN confluent-hub install --no-prompt confluentinc/connect-transforms:latest

# Verify installation
RUN echo "=== Installed plugins ===" && \
    ls -la /usr/share/confluent-hub-components/

# Clean up and set proper permissions
RUN chmod -R 755 /usr/share/confluent-hub-components

# Return to default working directory
WORKDIR /