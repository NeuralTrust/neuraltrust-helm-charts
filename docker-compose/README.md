# NeuralTrust Data Plane - Docker Compose

Simple Docker Compose deployment of the NeuralTrust Data Plane components.

## Components

- **ClickHouse**: Database for storing data
- **Kafka**: Message broker with Zookeeper
- **Kafka Connect**: Data integration platform
- **Kafka UI**: Web interface for Kafka management
- **Data Plane API**: Main API service
- **Worker**: Background processing service

## Quick Start

1. **Copy environment file:**
   ```bash
   cp env.example .env
   ```

2. **Edit `.env` file with your API keys:**
   - OpenAI API key
   - Google API key  
   - Resend API key
   - HuggingFace token
   - JWT secret

3. **Create init scripts directory (optional):**
   ```bash
   mkdir -p init-scripts
   ```

4. **Start all services:**
   ```bash
   docker-compose up -d
   ```

5. **Check service status:**
   ```bash
   docker-compose ps
   ```

## Service Endpoints

- **Data Plane API**: http://localhost:8000
- **Kafka UI**: http://localhost:8080
- **ClickHouse HTTP**: http://localhost:8123
- **Kafka Connect REST API**: http://localhost:8083

## Useful Commands

```bash
# View logs
docker-compose logs -f [service-name]

# Stop all services
docker-compose down

# Remove volumes (WARNING: deletes data)
docker-compose down -v

# Restart a specific service
docker-compose restart [service-name]
```

## Notes

- All services use `restart: unless-stopped` for automatic recovery
- Data persists in Docker volumes (`clickhouse_data`, `huggingface_cache`)
- ClickHouse initialization scripts can be placed in `./init-scripts/` 