#!/bin/bash

set -e

echo "🔐 Authenticating to GCP Artifact Registry..."
docker login europe-west1-docker.pkg.dev -u _json_key -p "$(cat gcr-keys.json)"

echo "📦 Pulling open source images..."

# Data Plane - Open source images
docker pull docker.io/bitnami/clickhouse:25.3.2-debian-12-r3
docker pull clickhouse/clickhouse-server:25.3.2
docker pull docker.io/bitnami/kafka:3.9.0-debian-12-r1
docker pull docker.io/bitnami/os-shell:12-debian-12-r42
docker pull docker.io/bitnami/zookeeper:3.9.3-debian-12-r0
docker pull provectuslabs/kafka-ui:v0.7.2
docker pull curlimages/curl:8.13.0
docker pull redislabs/redisearch:2.6.9
docker pull postgres:17.2-alpine

# Control Plane - Open source images
docker pull postgres:17.2-alpine

echo "🏢 Pulling proprietary images from GCP Artifact Registry..."

# Data Plane - Own images
docker pull europe-west1-docker.pkg.dev/neuraltrust-app-prod/nt-docker/data-plane-api:v1.6.0 
docker pull europe-west1-docker.pkg.dev/neuraltrust-app-prod/nt-docker/workers:v1.4.0-with-models 
docker pull europe-west1-docker.pkg.dev/neuraltrust-app-prod/nt-docker/kafka-connect:v0.0.1 

# Control Plane - Own images
docker pull europe-west1-docker.pkg.dev/neuraltrust-app-prod/nt-docker/control-plane-api:v1.6.0 
docker pull europe-west1-docker.pkg.dev/neuraltrust-app-prod/nt-docker/scheduler:v1.4.0 
docker pull europe-west1-docker.pkg.dev/neuraltrust-app-prod/nt-docker/app:v1.6.0 

# Data Plane - Own images
docker pull europe-west1-docker.pkg.dev/neuraltrust-app-prod/nt-docker/firewall:v1.3.0
docker pull europe-west1-docker.pkg.dev/neuraltrust-app-prod/nt-docker/trustgate-ee:v1.7.35

echo "✅ All images pulled successfully!" 
