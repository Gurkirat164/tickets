# How to Deploy Tickets Bot on Pterodactyl

## Table of Contents
1. [Prerequisites](#prerequisites)
2. [Infrastructure Setup](#infrastructure-setup)
3. [Pterodactyl Configuration](#pterodactyl-configuration)
4. [Service Deployment](#service-deployment)
5. [Discord Configuration](#discord-configuration)
6. [Testing and Monitoring](#testing-and-monitoring)
7. [Troubleshooting](#troubleshooting)

## Prerequisites

Before beginning this deployment, ensure you have:

- **Pterodactyl Panel** with admin access
- **PostgreSQL Database Server** (version 12 or higher)
- **Redis Server** (version 6 or higher)
- **Kafka Cluster** (or managed service like Confluent Cloud)
- **Domain Name** (for webhook endpoints)
- **SSL Certificate** (for HTTPS endpoints)
- **Discord Developer Account** (for bot creation)
- **Basic Knowledge** of Docker, environment variables, and networking

## Infrastructure Setup

### Step 1: Set up PostgreSQL Database

1. **Connect to your PostgreSQL server:**
   ```bash
   psql -h your-postgres-host -U postgres
   ```

2. **Create databases:**
   ```sql
   CREATE DATABASE tickets_main;
   CREATE DATABASE tickets_patreon;
   CREATE DATABASE tickets_votes;
   ```

3. **Create user with permissions:**
   ```sql
   CREATE USER tickets_user WITH PASSWORD 'your_secure_password_here';
   GRANT ALL PRIVILEGES ON DATABASE tickets_main TO tickets_user;
   GRANT ALL PRIVILEGES ON DATABASE tickets_patreon TO tickets_user;
   GRANT ALL PRIVILEGES ON DATABASE tickets_votes TO tickets_user;
   ```

4. **Test connection:**
   ```bash
   psql -h your-postgres-host -U tickets_user -d tickets_main
   ```

### Step 2: Set up Redis Server

1. **Install Redis** (if not already installed):
   ```bash
   # Ubuntu/Debian
   sudo apt install redis-server
   
   # CentOS/RHEL
   sudo yum install redis
   ```

2. **Configure Redis** (`/etc/redis/redis.conf`):
   ```
   bind 0.0.0.0
   port 6379
   requirepass your_redis_password
   ```

3. **Start Redis:**
   ```bash
   sudo systemctl start redis-server
   sudo systemctl enable redis-server
   ```

### Step 3: Set up Kafka (Optional - can use managed service)

1. **Download and install Kafka:**
   ```bash
   wget https://downloads.apache.org/kafka/2.8.0/kafka_2.13-2.8.0.tgz
   tar -xzf kafka_2.13-2.8.0.tgz
   cd kafka_2.13-2.8.0
   ```

2. **Start Kafka:**
   ```bash
   # Start Zookeeper
   bin/zookeeper-server-start.sh config/zookeeper.properties
   
   # Start Kafka
   bin/kafka-server-start.sh config/server.properties
   ```

3. **Create topics:**
   ```bash
   bin/kafka-topics.sh --create --topic tickets_events --bootstrap-server localhost:9092
   bin/kafka-topics.sh --create --topic tickets_commands --bootstrap-server localhost:9092
   ```

## Pterodactyl Configuration

### Step 4: Create Custom Rust Service Egg

1. **Log into Pterodactyl Admin Panel**

2. **Navigate to Admin → Nests → Create New**

3. **Create a new nest called "Tickets Bot"**

4. **Create a new egg with the following configuration:**
   - **Name:** Tickets Bot - Rust Service
   - **Description:** A Rust-based Discord bot service
   - **Docker Image:** `rust:1-buster`
   - **Startup Command:** `./{{SERVICE_NAME}}`

5. **Set Installation Script:**
   ```bash
   #!/bin/bash
   
   # Install dependencies
   apt-get update
   apt-get install -y curl build-essential pkg-config libssl-dev git
   
   # Install Rust
   curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
   source $HOME/.cargo/env
   
   # Clone repository
   cd /mnt/server
   git clone ${GIT_REPO} .
   
   # Build the specific service
   cargo build --release --bin ${SERVICE_NAME}
   
   # Copy binary to server root
   cp target/release/${SERVICE_NAME} ./
   
   echo "Installation completed successfully"
   ```

6. **Configure Variables:**
   - `GIT_REPO`: Your Git repository URL
   - `SERVICE_NAME`: The service binary name (e.g., "sharder", "http-gateway")

### Step 5: Set up Service Network

1. **Create a Docker network** for service communication:
   ```bash
   docker network create tickets-network
   ```

2. **Configure Pterodactyl** to use this network for all Tickets Bot services

## Service Deployment

### Step 6: Deploy Core Services

#### 6.1 Deploy Server Counter Service

1. **Create new server in Pterodactyl:**
   - **Name:** Tickets-ServerCounter
   - **Egg:** Tickets Bot - Rust Service
   - **Docker Image:** rust:1-buster

2. **Set Environment Variables:**
   ```bash
   SERVICE_NAME=server-counter
   GIT_REPO=https://github.com/yourusername/tickets-bot.git
   SERVER_ADDR=0.0.0.0:8080
   CACHE_URI=redis://redis-server:6379/0
   REDIS_PASSWORD=your_redis_password
   ```

3. **Allocate Port:** 8081

4. **Deploy and verify:** Check that the service starts and responds to health checks

#### 6.2 Deploy Cache Service

1. **Create new server:**
   - **Name:** Tickets-Cache
   - **Egg:** Tickets Bot - Rust Service

2. **Set Environment Variables:**
   ```bash
   SERVICE_NAME=cache
   GIT_REPO=https://github.com/yourusername/tickets-bot.git
   CACHE_URI=redis://redis-server:6379/1
   REDIS_PASSWORD=your_redis_password
   ```

3. **Deploy and test Redis connectivity**

#### 6.3 Deploy HTTP Gateway Service

1. **Create new server:**
   - **Name:** Tickets-HTTPGateway
   - **Egg:** Tickets Bot - Rust Service

2. **Set Environment Variables:**
   ```bash
   SERVICE_NAME=http-gateway
   GIT_REPO=https://github.com/yourusername/tickets-bot.git
   SERVER_ADDR=0.0.0.0:8080
   CACHE_URI=redis://redis-server:6379/0
   DATABASE_URI=postgresql://tickets_user:password@postgres-server:5432/tickets_main
   PUBLIC_BOT_ID=your_discord_bot_id
   PUBLIC_TOKEN=your_discord_bot_token
   PUBLIC_PUBLIC_KEY=your_discord_public_key
   KAFKA_BROKERS=kafka-server:9092
   KAFKA_TOPIC=tickets_commands
   SENTRY_DSN=your_sentry_dsn
   ```

3. **Allocate Port:** 8080

4. **Deploy and verify:** This service handles Discord interactions

#### 6.4 Deploy Sharder Service

1. **Create new server:**
   - **Name:** Tickets-Sharder
   - **Egg:** Tickets Bot - Rust Service

2. **Set Environment Variables:**
   ```bash
   SERVICE_NAME=public
   GIT_REPO=https://github.com/yourusername/tickets-bot.git
   SHARDER_ID=0
   SHARDER_TOTAL=1
   CACHE_URI=redis://redis-server:6379/0
   REDIS_ADDR=redis-server:6379
   REDIS_PASSWORD=your_redis_password
   REDIS_THREADS=4
   WORKER_SVC_URI=http://http-gateway:8080
   SENTRY_DSN=your_sentry_dsn
   KAFKA_BROKERS=kafka-server:9092
   KAFKA_TOPIC=tickets_events
   
   # Public Bot Configuration
   SHARDER_TOKEN=your_discord_bot_token
   BOT_ID=your_discord_bot_id
   SHARDER_CLUSTER_SIZE=1
   LARGE_SHARDING_BUCKETS=16
   ```

3. **No port allocation needed** (internal service)

4. **Deploy and monitor:** This connects to Discord Gateway

### Step 7: Deploy Supporting Services

#### 7.1 Deploy Bot List Updater

1. **Create new server:**
   - **Name:** Tickets-BotListUpdater
   - **Egg:** Tickets Bot - Rust Service

2. **Set Environment Variables:**
   ```bash
   SERVICE_NAME=bot-list-updater
   GIT_REPO=https://github.com/yourusername/tickets-bot.git
   DELAY=300
   BOT_ID=your_discord_bot_id
   BASE_URL=http://server-counter:8080
   DBL_TOKEN=your_top_gg_token
   DBOATS_TOKEN=your_discord_boats_token
   ```

3. **Deploy:** This updates bot statistics on listing sites

#### 7.2 Deploy Patreon Proxy (Optional)

1. **Create new server:**
   - **Name:** Tickets-PatreonProxy
   - **Egg:** Tickets Bot - Rust Service

2. **Set Environment Variables:**
   ```bash
   SERVICE_NAME=patreon-proxy
   GIT_REPO=https://github.com/yourusername/tickets-bot.git
   PATREON_CAMPAIGN_ID=your_patreon_campaign_id
   PATREON_CLIENT_ID=your_patreon_client_id
   PATREON_CLIENT_SECRET=your_patreon_client_secret
   PATREON_REDIRECT_URI=https://your-domain.com/patreon/callback
   SERVER_ADDR=0.0.0.0:8080
   DATABASE_URI=postgresql://tickets_user:password@postgres-server:5432/tickets_patreon
   SENTRY_DSN=your_sentry_dsn
   ```

3. **Allocate Port:** 8082

#### 7.3 Deploy Vote Listener (Optional)

1. **Create new server:**
   - **Name:** Tickets-VoteListener
   - **Egg:** Tickets Bot - Rust Service

2. **Set Environment Variables:**
   ```bash
   SERVICE_NAME=vote_listener
   GIT_REPO=https://github.com/yourusername/tickets-bot.git
   DBL_TOKEN=your_top_gg_webhook_token
   SERVER_ADDR=0.0.0.0:8080
   DATABASE_URI=postgresql://tickets_user:password@postgres-server:5432/tickets_votes
   VOTE_URL=https://top.gg/bot/your_bot_id/vote
   RUST_LOG=info
   ```

3. **Allocate Port:** 8083

## Discord Configuration

### Step 8: Set up Discord Application

1. **Create Discord Application:**
   - Go to https://discord.com/developers/applications
   - Click "New Application"
   - Name it "Tickets Bot" (or your preferred name)
   - Note the **Application ID** (this is your `BOT_ID`)

2. **Create Bot User:**
   - Go to "Bot" section
   - Click "Add Bot"
   - Copy the **Bot Token** (this is your `SHARDER_TOKEN`/`PUBLIC_TOKEN`)
   - Enable "Message Content Intent" if needed

3. **Get Public Key:**
   - Go to "General Information"
   - Copy the **Public Key** (this is your `PUBLIC_PUBLIC_KEY`)

4. **Set up Interactions Endpoint:**
   - In "General Information"
   - Set **Interactions Endpoint URL** to: `https://your-domain.com/interactions`
   - This should point to your HTTP Gateway service

5. **Configure OAuth2:**
   - Go to "OAuth2" → "URL Generator"
   - Select scopes: `bot`, `applications.commands`
   - Select appropriate bot permissions
   - Use generated URL to invite bot to test servers

### Step 9: Configure Reverse Proxy

1. **Set up Nginx/Apache** to route traffic to your services:

```nginx
# Nginx configuration example
server {
    listen 443 ssl;
    server_name your-domain.com;
    
    ssl_certificate /path/to/cert.pem;
    ssl_certificate_key /path/to/key.pem;
    
    location /interactions {
        proxy_pass http://http-gateway-server:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
    
    location /vote {
        proxy_pass http://vote-listener-server:8083;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
    
    location /patreon {
        proxy_pass http://patreon-proxy-server:8082;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

## Testing and Monitoring

### Step 10: Verify Deployment

1. **Check Service Health:**
   ```bash
   # Test each service endpoint
   curl http://server-counter:8081/ping
   curl http://http-gateway:8080/ping
   curl http://patreon-proxy:8082/ping
   curl http://vote-listener:8083/
   ```

2. **Verify Database Connections:**
   ```bash
   # Check if services can connect to PostgreSQL
   psql -h postgres-server -U tickets_user -d tickets_main -c "SELECT 1;"
   ```

3. **Test Redis Connectivity:**
   ```bash
   redis-cli -h redis-server -p 6379 ping
   ```

4. **Monitor Service Logs:**
   - Check Pterodactyl console for each service
   - Look for successful startup messages
   - Monitor for any error messages

### Step 11: Test Discord Integration

1. **Verify Bot is Online:**
   - Check Discord server for bot presence
   - Bot should show as online

2. **Test Slash Commands:**
   - Use `/help` or other commands
   - Verify responses are working

3. **Test Interactions:**
   - Try button clicks and other interactions
   - Verify HTTP Gateway is processing requests

### Step 12: Set up Monitoring

1. **Health Check Script:**
   ```bash
   #!/bin/bash
   # Create /opt/tickets-bot/health-check.sh
   
   echo "=== Tickets Bot Health Check ==="
   
   # Check core services
   services=("server-counter:8081" "http-gateway:8080" "patreon-proxy:8082" "vote-listener:8083")
   
   for service in "${services[@]}"; do
       echo -n "Checking $service: "
       if curl -s "http://$service/ping" > /dev/null 2>&1; then
           echo "✓ Healthy"
       else
           echo "✗ Unhealthy"
       fi
   done
   ```

2. **Set up Cron Job:**
   ```bash
   # Add to crontab
   */5 * * * * /opt/tickets-bot/health-check.sh >> /var/log/tickets-health.log 2>&1
   ```

3. **Configure Log Rotation:**
   ```bash
   # /etc/logrotate.d/tickets-bot
   /var/log/tickets-*.log {
       daily
       rotate 7
       compress
       delaycompress
       missingok
       notifempty
   }
   ```

## Troubleshooting

### Common Issues and Solutions

#### Service Won't Start

1. **Check Environment Variables:**
   - Verify all required variables are set
   - Check database connection strings
   - Validate API tokens and keys

2. **Check Dependencies:**
   - Ensure PostgreSQL is accessible
   - Verify Redis is running
   - Test Kafka connectivity

3. **Review Build Logs:**
   - Check for Rust compilation errors
   - Verify all dependencies are installed

#### Database Connection Errors

1. **Check Connection String:**
   ```bash
   # Test connection manually
   psql -h postgres-server -U tickets_user -d tickets_main
   ```

2. **Verify Network Connectivity:**
   ```bash
   # Test from service container
   telnet postgres-server 5432
   ```

3. **Check Firewall Rules:**
   - Ensure PostgreSQL port (5432) is open
   - Verify network security groups

#### Discord Bot Not Responding

1. **Check Bot Token:**
   - Verify token is correct and not expired
   - Ensure bot has necessary permissions

2. **Check Interactions Endpoint:**
   - Verify URL is accessible from Discord
   - Test SSL certificate validity

3. **Monitor Sharder Logs:**
   - Check for Discord Gateway connection errors
   - Verify shard is connecting successfully

#### Redis Connection Issues

1. **Test Redis Connectivity:**
   ```bash
   redis-cli -h redis-server -p 6379 ping
   ```

2. **Check Redis Configuration:**
   - Verify bind address allows connections
   - Check authentication settings

3. **Monitor Redis Logs:**
   - Look for connection errors
   - Check memory usage

### Performance Optimization

1. **Scale Sharder Service:**
   - Increase `SHARDER_TOTAL` and deploy multiple sharders
   - Distribute load across multiple instances

2. **Optimize Database:**
   - Add indexes for frequently queried columns
   - Configure connection pooling
   - Monitor query performance

3. **Cache Optimization:**
   - Increase Redis memory allocation
   - Configure appropriate cache TTL values
   - Monitor cache hit rates

### Security Considerations

1. **Secure Sensitive Data:**
   - Use environment variables for secrets
   - Implement proper access controls
   - Regular security audits

2. **Network Security:**
   - Use internal networks for service communication
   - Implement proper firewall rules
   - Regular security updates

3. **Monitoring and Alerting:**
   - Set up log monitoring
   - Configure alerts for service failures
   - Regular backup procedures

## Conclusion

You have successfully deployed the Tickets Bot on Pterodactyl! The system should now be running with:

- ✅ Core services (Sharder, HTTP Gateway, Cache, Server Counter)
- ✅ Optional services (Patreon Proxy, Vote Listener)
- ✅ Discord integration and slash commands
- ✅ Database and Redis connectivity
- ✅ Monitoring and health checks

For ongoing maintenance:
- Monitor service health regularly
- Keep dependencies updated
- Back up databases regularly
- Monitor Discord API changes
- Review logs for errors

If you encounter any issues, refer to the troubleshooting section or check the service logs in the Pterodactyl console.
