FROM openresty/openresty:alpine

# Copy nginx configuration
COPY nginx.conf /usr/local/openresty/nginx/conf/nginx.conf

# Copy router files
COPY router /router/

# Expose the edge server port
EXPOSE 8081

# Command to run OpenResty
CMD ["/usr/local/openresty/bin/openresty", "-g", "daemon off;"]
