FROM golang:1.22-alpine

# Install required dependencies
RUN apk add --no-cache bash nginx redis curl openresty

# Set up work directories 
WORKDIR /app
COPY . /app

# Set up NGINX RTMP
RUN mkdir -p /opt/data/hls /hls
COPY ./rtmp/live.conf /etc/nginx/nginx.conf

# Set up edge server
COPY ./edge/nginx.conf /usr/local/openresty/nginx/conf/nginx.conf
COPY ./edge/router /router/

# Create startup script
RUN echo '#!/bin/sh' > /entrypoint.sh && \
    echo 'echo "Starting services directly..."' >> /entrypoint.sh && \
    echo 'cd /app' >> /entrypoint.sh && \
    echo '# Start Redis' >> /entrypoint.sh && \
    echo 'redis-server --daemonize yes' >> /entrypoint.sh && \
    echo '# Start NGINX for RTMP' >> /entrypoint.sh && \
    echo 'nginx -c /etc/nginx/nginx.conf &' >> /entrypoint.sh && \
    echo '# Start API service' >> /entrypoint.sh && \
    echo 'cd /app/stream-handler && go run main.go api &' >> /entrypoint.sh && \
    echo '# Start Discovery service' >> /entrypoint.sh && \
    echo 'cd /app/stream-handler && HLS_PATH=/hls IP=localhost DISCOVERY_API_URL=http://localhost:9090 go run main.go discovery &' >> /entrypoint.sh && \
    echo '# Start OpenResty for edge' >> /entrypoint.sh && \
    echo '/usr/local/openresty/bin/openresty -c /usr/local/openresty/nginx/conf/nginx.conf &' >> /entrypoint.sh && \
    echo '# Keep container running' >> /entrypoint.sh && \
    echo 'echo "All services started"' >> /entrypoint.sh && \
    echo 'tail -f /dev/null' >> /entrypoint.sh && \
    chmod +x /entrypoint.sh

# Run the services
ENTRYPOINT ["/entrypoint.sh"]

# Expose the necessary ports
EXPOSE 1935 8080 9090 6379 8081 