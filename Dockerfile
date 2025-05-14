FROM docker:24.0-dind

# Install docker-compose and other dependencies
RUN apk add --no-cache docker-compose python3 bash git

# Copy the whole repo
WORKDIR /app
COPY . /app

# Create a more robust entrypoint script
RUN echo '#!/bin/sh' > /entrypoint.sh && \
    echo 'dockerd &' >> /entrypoint.sh && \
    echo 'echo "Waiting for Docker daemon to start..."' >> /entrypoint.sh && \
    echo 'until docker info > /dev/null 2>&1; do' >> /entrypoint.sh && \
    echo '  echo "Docker daemon not running yet, sleeping..."' >> /entrypoint.sh && \
    echo '  sleep 2' >> /entrypoint.sh && \
    echo 'done' >> /entrypoint.sh && \
    echo 'echo "Docker daemon started successfully!"' >> /entrypoint.sh && \
    echo 'cd /app && docker-compose up' >> /entrypoint.sh && \
    chmod +x /entrypoint.sh

# Run the entrypoint script
ENTRYPOINT ["/entrypoint.sh"] 