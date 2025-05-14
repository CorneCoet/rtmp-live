FROM golang:1.22-alpine

# Install all required dependencies
RUN apk add --no-cache \
    bash \
    curl \
    redis \
    nginx \
    supervisor \
    openresty \
    git \
    wget \
    build-base \
    pcre-dev \
    zlib-dev

# Set up work directories
WORKDIR /app
COPY . /app

# Set up NGINX RTMP
RUN mkdir -p /opt/data/hls /hls
COPY ./rtmp/live.conf /etc/nginx/nginx.conf

# Set up edge server
COPY ./edge/nginx.conf /usr/local/openresty/nginx/conf/nginx.conf
COPY ./edge/router /router/

# Build the stream-handler
WORKDIR /app/stream-handler
RUN go mod tidy && go build -o /app/api-server main.go

# Set up supervisord to manage all services
RUN mkdir -p /etc/supervisor.d/

# Create supervisord.conf file
RUN echo '[supervisord]' > /etc/supervisord.conf && \
    echo 'nodaemon=true' >> /etc/supervisord.conf && \
    echo 'user=root' >> /etc/supervisord.conf && \
    echo '' >> /etc/supervisord.conf && \
    echo '[program:redis]' >> /etc/supervisord.conf && \
    echo 'command=redis-server --protected-mode no' >> /etc/supervisord.conf && \
    echo 'autostart=true' >> /etc/supervisord.conf && \
    echo 'autorestart=true' >> /etc/supervisord.conf && \
    echo '' >> /etc/supervisord.conf && \
    echo '[program:nginx]' >> /etc/supervisord.conf && \
    echo 'command=nginx -g "daemon off;"' >> /etc/supervisord.conf && \
    echo 'autostart=true' >> /etc/supervisord.conf && \
    echo 'autorestart=true' >> /etc/supervisord.conf && \
    echo '' >> /etc/supervisord.conf && \
    echo '[program:api]' >> /etc/supervisord.conf && \
    echo 'command=/app/api-server api' >> /etc/supervisord.conf && \
    echo 'directory=/app/stream-handler' >> /etc/supervisord.conf && \
    echo 'environment=REDIS_ADDR="localhost:6379"' >> /etc/supervisord.conf && \
    echo 'autostart=true' >> /etc/supervisord.conf && \
    echo 'autorestart=true' >> /etc/supervisord.conf && \
    echo '' >> /etc/supervisord.conf && \
    echo '[program:discovery]' >> /etc/supervisord.conf && \
    echo 'command=/app/api-server discovery' >> /etc/supervisord.conf && \
    echo 'directory=/app/stream-handler' >> /etc/supervisord.conf && \
    echo 'environment=HLS_PATH="/hls",IP="localhost",DISCOVERY_API_URL="http://localhost:9090"' >> /etc/supervisord.conf && \
    echo 'autostart=true' >> /etc/supervisord.conf && \
    echo 'autorestart=true' >> /etc/supervisord.conf && \
    echo '' >> /etc/supervisord.conf && \
    echo '[program:openresty]' >> /etc/supervisord.conf && \
    echo 'command=/usr/local/openresty/bin/openresty -g "daemon off;"' >> /etc/supervisord.conf && \
    echo 'autostart=true' >> /etc/supervisord.conf && \
    echo 'autorestart=true' >> /etc/supervisord.conf

# Expose all needed ports
EXPOSE 1935 8080 9090 6379 8081

# Start supervisord
CMD ["supervisord", "-c", "/etc/supervisord.conf"] 