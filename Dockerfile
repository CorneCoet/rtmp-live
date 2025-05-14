FROM golang:1.22-alpine

# Install required dependencies
RUN apk add --no-cache bash nginx redis curl

# Set up work directories 
WORKDIR /app
COPY . /app

# Create more robust startup script with error handling
RUN echo '#!/bin/sh' > /entrypoint.sh && \
    echo 'set -e' >> /entrypoint.sh && \
    echo 'echo "Starting services with debug logging..."' >> /entrypoint.sh && \
    echo 'cd /app' >> /entrypoint.sh && \
    echo '' >> /entrypoint.sh && \
    echo '# Start Redis' >> /entrypoint.sh && \
    echo 'echo "Starting Redis..."' >> /entrypoint.sh && \
    echo 'redis-server --daemonize yes || echo "Redis failed to start"' >> /entrypoint.sh && \
    echo 'sleep 2' >> /entrypoint.sh && \
    echo 'redis-cli ping || echo "Redis not responding"' >> /entrypoint.sh && \
    echo '' >> /entrypoint.sh && \
    echo '# Start NGINX for RTMP' >> /entrypoint.sh && \
    echo 'echo "Starting NGINX..."' >> /entrypoint.sh && \
    echo 'ls -la /etc/nginx/' >> /entrypoint.sh && \
    echo 'cat /etc/nginx/nginx.conf' >> /entrypoint.sh && \
    echo 'mkdir -p /opt/data/hls /hls' >> /entrypoint.sh && \
    echo 'nginx || echo "NGINX failed to start"' >> /entrypoint.sh && \
    echo '' >> /entrypoint.sh && \
    echo '# Start API service' >> /entrypoint.sh && \
    echo 'echo "Starting API service..."' >> /entrypoint.sh && \
    echo 'cd /app/stream-handler' >> /entrypoint.sh && \
    echo 'ls -la' >> /entrypoint.sh && \
    echo 'REDIS_ADDR=localhost:6379 go run main.go api &' >> /entrypoint.sh && \
    echo 'API_PID=$!' >> /entrypoint.sh && \
    echo 'echo "API service started with PID: $API_PID"' >> /entrypoint.sh && \
    echo '' >> /entrypoint.sh && \
    echo '# Basic status check and monitoring' >> /entrypoint.sh && \
    echo 'echo "Environment status:"' >> /entrypoint.sh && \
    echo 'ps aux' >> /entrypoint.sh && \
    echo 'netstat -tulpn' >> /entrypoint.sh && \
    echo '' >> /entrypoint.sh && \
    echo '# Keep container running and monitor processes' >> /entrypoint.sh && \
    echo 'echo "All services started, monitoring..."' >> /entrypoint.sh && \
    echo 'while true; do' >> /entrypoint.sh && \
    echo '  sleep 60' >> /entrypoint.sh && \
    echo '  echo "Service status check:"' >> /entrypoint.sh && \
    echo '  ps aux | grep -v grep | grep -E "nginx|redis|go"' >> /entrypoint.sh && \
    echo '  netstat -tulpn' >> /entrypoint.sh && \
    echo 'done' >> /entrypoint.sh && \
    chmod +x /entrypoint.sh

# Run the services
ENTRYPOINT ["/entrypoint.sh"]

# Expose the necessary ports
EXPOSE 1935 8080 9090 6379 8081 