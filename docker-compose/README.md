# NeuralTrust - Docker Compose

> [!NOTE]  
> This deployment is recommended for local development and testing. For production deployments, we recommend using Kubernetes/OpenShift.

Complete Docker Compose deployment of the NeuralTrust platform with both Control Plane and Data Plane components.

## Components

### Data Plane
- **ClickHouse**: Analytics database for traces and sensitive data
- **Data Plane API**: Core API service for Clickhouse read and write operations
- **Worker**: Kafka consumer for processing traces
- **Kafka**: Message broker with Zookeeper for event streaming

### Control Plane  
- **PostgreSQL**: Primary database for application data
- **Control Plane API**: Management API service for application data
- **App**: Frontend web application
- **Scheduler**: Background job scheduling service


## Quick Start

1. **Copy environment file:**
   ```bash
   cp env.example .env
   ```

2. **Edit `.env` file with your configuration:**
   - **Database passwords** (ClickHouse, PostgreSQL)
   - **JWT secret** (Data Plane, Control Plane)
   - **API keys** (OpenAI, Google, Resend, HuggingFace)
   - **Clerk authentication** (for Control Plane UI) - optional

3. **Start all services:**
   ```bash
   # Start all services
   docker-compose up -d

   # Start only the data plane
   docker-compose --profile data-plane up -d

   # Start only the control plane
   docker-compose --profile control-plane up -d
   ```

4. **Check service status:**
   ```bash
   docker-compose ps
   ```

if everything is running, you should be able to access the following endpoints:
- Web UI: http://localhost:3000

## Service Endpoints

### Control Plane
- **Web Application**: http://localhost:3000
- **Control Plane API**: http://localhost:3001
- **Scheduler**: http://localhost:3002

### Data Plane
- **Data Plane API**: http://localhost:8000

### Infrastructure
- **Kafka UI**: http://localhost:8080
- **ClickHouse HTTP**: http://localhost:8123
- **PostgreSQL**: localhost:5432 (configurable)
- **Kafka Connect REST API**: http://localhost:8083


## Configure Red Teaming LLMs

For Red Teaming, you can configure which LLMs to use for different components. Currenlty we support OpenAI and Google.

In the base path define a `.trusttest_config.json` file with the following structure:

```json
{
    "evaluator": {
        "provider": "openai", // or "google"
        "model": "gpt-4o-mini",
        "temperature": 0.2
    },
    "question_generator": {
        "provider": "openai", // or "google"
        "model": "gpt-4o-mini",
        "temperature": 0.5
    },
    "embeddings": {
        "provider": "openai", // or "google"
        "model": "text-embedding-3-small"
    },
    "topic_summarizer": {
        "provider": "openai", // or "google"
        "model": "gpt-4o-mini",
        "temperature": 0.2
    }
} 
```

This will be used to configure the LLMs for the red teaming process in the Data Plane. For Azure OpenAI:

```json
{
    "evaluator": {
        "provider": "azure",
        "model": "azure deployment name",
        "temperature": 0.2,
        "extra_args": { // optional add other azure args
            "default_headers": {
                "my-header": "my-value"
            }
        }
    },
    "question_generator": {
        "provider": "azure",
        "model": "azure deployment name",
        "temperature": 0.2,
        "extra_args": { // optional
            "default_headers": {
                "my-header": "my-value"
            }
        }
    },
    "embeddings": {
        "provider": "openai", // or "google"
        "model": "text-embedding-3-small"
    },
    "topic_summarizer": {
        "provider": "azure",
        "model": "azure deployment name",
        "temperature": 0.2,
        "extra_args": { // optional
            "default_headers": {
                "my-header": "my-value"
            }
        }
    }
}
```
And configure the following environment variables in the `.env` file:

```bash
AZURE_OPENAI_ENDPOINT=https://<your-resource-name>.openai.azure.com/
AZURE_OPENAI_API_KEY=<your-api-key>
OPENAI_API_VERSION=2024-02-15-preview
```
