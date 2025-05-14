FROM docker:24.0-dind

# Install docker-compose and other dependencies
RUN apk add --no-cache docker-compose python3 bash git

# Copy the whole repo
WORKDIR /app
COPY . /app

# Entrypoint script
RUN echo '#!/bin/sh' > /entrypoint.sh && \
    echo 'dockerd &' >> /entrypoint.sh && \
    echo 'sleep 5' >> /entrypoint.sh && \
    echo 'cd /app && docker-compose up' >> /entrypoint.sh && \
    chmod +x /entrypoint.sh

# Run the entrypoint script
ENTRYPOINT ["/entrypoint.sh"] 