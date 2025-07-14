#!/bin/bash

# Health check script for Tickets Bot services

echo "=== Tickets Bot Health Check ==="

# Check core services
echo "Checking core services..."

# Server Counter
echo -n "Server Counter: "
if curl -s http://server-counter:8080/ping > /dev/null; then
    echo "✓ Running"
else
    echo "✗ Not responding"
fi

# HTTP Gateway
echo -n "HTTP Gateway: "
if curl -s http://http-gateway:8080/ping > /dev/null; then
    echo "✓ Running"
else
    echo "✗ Not responding"
fi

# Check external dependencies
echo -n "Redis: "
if redis-cli -h $REDIS_HOST ping > /dev/null 2>&1; then
    echo "✓ Connected"
else
    echo "✗ Connection failed"
fi

echo -n "PostgreSQL: "
if pg_isready -h $POSTGRES_HOST -U tickets_user > /dev/null 2>&1; then
    echo "✓ Connected"
else
    echo "✗ Connection failed"
fi

# Check optional services
echo "Checking optional services..."

# Patreon Proxy
echo -n "Patreon Proxy: "
if curl -s http://patreon-proxy:8082/ping > /dev/null; then
    echo "✓ Running"
else
    echo "✗ Not responding (optional)"
fi

# Vote Listener
echo -n "Vote Listener: "
if curl -s http://vote-listener:8083/ > /dev/null; then
    echo "✓ Running"
else
    echo "✗ Not responding (optional)"
fi

echo "=== Health Check Complete ==="
