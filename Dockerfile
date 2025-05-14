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
    zlib-dev \
    procps

# Set up work directories
WORKDIR /app
COPY . /app

# Create process monitor script (similar to docker ps)
RUN echo '#!/bin/sh' > /process-monitor.sh && \
    echo 'echo "=== RUNNING PROCESSES (LIKE DOCKER PS) ===="' >> /process-monitor.sh && \
    echo 'echo "CONTAINER ID   IMAGE   STATUS   PORTS   NAMES"' >> /process-monitor.sh && \
    echo 'echo "------------   -----   ------   -----   -----"' >> /process-monitor.sh && \
    echo 'ps -o pid,etime,pcpu,pmem,args -C nginx,redis-server,supervisord,openresty | grep -v grep' >> /process-monitor.sh && \
    echo 'echo ""' >> /process-monitor.sh && \
    echo 'echo "PORT MAPPINGS:"' >> /process-monitor.sh && \
    echo 'netstat -tulpn | grep -E "nginx|redis|resty|api-server"' >> /process-monitor.sh && \
    chmod +x /process-monitor.sh

# Check if NGINX configs exist
RUN echo "Checking NGINX configs:" && \
    ls -la ./rtmp/ || echo "rtmp directory missing" && \
    ls -la ./edge/ || echo "edge directory missing"

# Create debug script
RUN echo '#!/bin/sh' > /debug.sh && \
    echo 'echo "===== PROCESS LIST ====="' >> /debug.sh && \
    echo 'ps aux' >> /debug.sh && \
    echo 'echo "===== NETWORK PORTS ====="' >> /debug.sh && \
    echo 'netstat -tulpn' >> /debug.sh && \
    echo 'echo "===== DIRECTORY LISTING ====="' >> /debug.sh && \
    echo 'ls -la /app' >> /debug.sh && \
    echo 'ls -la /app/rtmp' >> /debug.sh && \
    echo 'ls -la /app/edge' >> /debug.sh && \
    echo 'ls -la /app/stream-handler' >> /debug.sh && \
    echo 'echo "===== CONFIG FILES ====="' >> /debug.sh && \
    echo 'echo "NGINX CONFIG:"' >> /debug.sh && \
    echo 'cat /etc/nginx/nginx.conf' >> /debug.sh && \
    echo 'echo "SUPERVISORD CONFIG:"' >> /debug.sh && \
    echo 'cat /etc/supervisord.conf' >> /debug.sh && \
    chmod +x /debug.sh

# Set up NGINX RTMP
RUN mkdir -p /opt/data/hls /hls
RUN cp ./rtmp/live.conf /etc/nginx/nginx.conf 2>/dev/null || echo "Failed to copy NGINX conf"

# Set up edge server
RUN cp ./edge/nginx.conf /usr/local/openresty/nginx/conf/nginx.conf 2>/dev/null || echo "Failed to copy OpenResty conf"
RUN mkdir -p /router && cp -r ./edge/router/* /router/ 2>/dev/null || echo "Failed to copy router directory"

# Build the stream-handler
WORKDIR /app/stream-handler
RUN go mod tidy && go build -o /app/api-server main.go

# Set up supervisord with more detailed logging
RUN mkdir -p /etc/supervisor.d/ /var/log/supervisor/

# Create supervisord.conf file with better logging and error handling
RUN echo '[supervisord]' > /etc/supervisord.conf && \
    echo 'nodaemon=true' >> /etc/supervisord.conf && \
    echo 'user=root' >> /etc/supervisord.conf && \
    echo 'logfile=/var/log/supervisor/supervisord.log' >> /etc/supervisord.conf && \
    echo 'logfile_maxbytes=50MB' >> /etc/supervisord.conf && \
    echo 'logfile_backups=10' >> /etc/supervisord.conf && \
    echo 'loglevel=info' >> /etc/supervisord.conf && \
    echo '' >> /etc/supervisord.conf && \
    echo '[program:debug]' >> /etc/supervisord.conf && \
    echo 'command=/bin/sh -c "sleep 10 && /debug.sh"' >> /etc/supervisord.conf && \
    echo 'startsecs=0' >> /etc/supervisord.conf && \
    echo 'autorestart=false' >> /etc/supervisord.conf && \
    echo 'priority=1' >> /etc/supervisord.conf && \
    echo 'stdout_logfile=/dev/stdout' >> /etc/supervisord.conf && \
    echo 'stdout_logfile_maxbytes=0' >> /etc/supervisord.conf && \
    echo 'stderr_logfile=/dev/stderr' >> /etc/supervisord.conf && \
    echo 'stderr_logfile_maxbytes=0' >> /etc/supervisord.conf && \
    echo '' >> /etc/supervisord.conf && \
    echo '[program:process-monitor]' >> /etc/supervisord.conf && \
    echo 'command=/bin/sh -c "while true; do /process-monitor.sh; sleep 30; done"' >> /etc/supervisord.conf && \
    echo 'autostart=true' >> /etc/supervisord.conf && \
    echo 'autorestart=true' >> /etc/supervisord.conf && \
    echo 'stdout_logfile=/dev/stdout' >> /etc/supervisord.conf && \
    echo 'stdout_logfile_maxbytes=0' >> /etc/supervisord.conf && \
    echo 'stderr_logfile=/dev/stderr' >> /etc/supervisord.conf && \
    echo 'stderr_logfile_maxbytes=0' >> /etc/supervisord.conf && \
    echo '' >> /etc/supervisord.conf && \
    echo '[program:redis]' >> /etc/supervisord.conf && \
    echo 'command=redis-server --protected-mode no' >> /etc/supervisord.conf && \
    echo 'autostart=true' >> /etc/supervisord.conf && \
    echo 'autorestart=true' >> /etc/supervisord.conf && \
    echo 'stdout_logfile=/dev/stdout' >> /etc/supervisord.conf && \
    echo 'stdout_logfile_maxbytes=0' >> /etc/supervisord.conf && \
    echo 'stderr_logfile=/dev/stderr' >> /etc/supervisord.conf && \
    echo 'stderr_logfile_maxbytes=0' >> /etc/supervisord.conf && \
    echo '' >> /etc/supervisord.conf && \
    echo '[program:nginx]' >> /etc/supervisord.conf && \
    echo 'command=nginx -g "daemon off;"' >> /etc/supervisord.conf && \
    echo 'autostart=true' >> /etc/supervisord.conf && \
    echo 'autorestart=true' >> /etc/supervisord.conf && \
    echo 'stdout_logfile=/dev/stdout' >> /etc/supervisord.conf && \
    echo 'stdout_logfile_maxbytes=0' >> /etc/supervisord.conf && \
    echo 'stderr_logfile=/dev/stderr' >> /etc/supervisord.conf && \
    echo 'stderr_logfile_maxbytes=0' >> /etc/supervisord.conf && \
    echo '' >> /etc/supervisord.conf && \
    echo '[program:api]' >> /etc/supervisord.conf && \
    echo 'command=/app/api-server api' >> /etc/supervisord.conf && \
    echo 'directory=/app/stream-handler' >> /etc/supervisord.conf && \
    echo 'environment=REDIS_ADDR="localhost:6379"' >> /etc/supervisord.conf && \
    echo 'autostart=true' >> /etc/supervisord.conf && \
    echo 'autorestart=true' >> /etc/supervisord.conf && \
    echo 'stdout_logfile=/dev/stdout' >> /etc/supervisord.conf && \
    echo 'stdout_logfile_maxbytes=0' >> /etc/supervisord.conf && \
    echo 'stderr_logfile=/dev/stderr' >> /etc/supervisord.conf && \
    echo 'stderr_logfile_maxbytes=0' >> /etc/supervisord.conf && \
    echo '' >> /etc/supervisord.conf && \
    echo '[program:discovery]' >> /etc/supervisord.conf && \
    echo 'command=/app/api-server discovery' >> /etc/supervisord.conf && \
    echo 'directory=/app/stream-handler' >> /etc/supervisord.conf && \
    echo 'environment=HLS_PATH="/hls",IP="localhost",DISCOVERY_API_URL="http://localhost:9090"' >> /etc/supervisord.conf && \
    echo 'autostart=true' >> /etc/supervisord.conf && \
    echo 'autorestart=true' >> /etc/supervisord.conf && \
    echo 'stdout_logfile=/dev/stdout' >> /etc/supervisord.conf && \
    echo 'stdout_logfile_maxbytes=0' >> /etc/supervisord.conf && \
    echo 'stderr_logfile=/dev/stderr' >> /etc/supervisord.conf && \
    echo 'stderr_logfile_maxbytes=0' >> /etc/supervisord.conf && \
    echo '' >> /etc/supervisord.conf && \
    echo '[program:openresty]' >> /etc/supervisord.conf && \
    echo 'command=/usr/local/openresty/bin/openresty -g "daemon off;"' >> /etc/supervisord.conf && \
    echo 'autostart=true' >> /etc/supervisord.conf && \
    echo 'autorestart=true' >> /etc/supervisord.conf && \
    echo 'stdout_logfile=/dev/stdout' >> /etc/supervisord.conf && \
    echo 'stdout_logfile_maxbytes=0' >> /etc/supervisord.conf && \
    echo 'stderr_logfile=/dev/stderr' >> /etc/supervisord.conf && \
    echo 'stderr_logfile_maxbytes=0' >> /etc/supervisord.conf && \
    echo '' >> /etc/supervisord.conf && \
    echo '[program:monitor]' >> /etc/supervisord.conf && \
    echo 'command=/bin/sh -c "while true; do echo \"=== Service Status $(date) ===\"; ps aux; netstat -tulpn; sleep 60; done"' >> /etc/supervisord.conf && \
    echo 'autostart=true' >> /etc/supervisord.conf && \
    echo 'autorestart=true' >> /etc/supervisord.conf && \
    echo 'stdout_logfile=/dev/stdout' >> /etc/supervisord.conf && \
    echo 'stdout_logfile_maxbytes=0' >> /etc/supervisord.conf && \
    echo 'stderr_logfile=/dev/stderr' >> /etc/supervisord.conf && \
    echo 'stderr_logfile_maxbytes=0' >> /etc/supervisord.conf

# Expose all needed ports
EXPOSE 1935 8080 9090 6379 8081

# Start supervisord with explicit log output
CMD ["supervisord", "-c", "/etc/supervisord.conf", "-n"] 