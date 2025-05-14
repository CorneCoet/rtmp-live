FROM golang:1.22-alpine

WORKDIR /app

# Copy go.mod and go.sum first for better caching
COPY go.mod go.sum ./
RUN go mod download

# Copy the rest of the source code
COPY . .

# Build the application
RUN go build -o server main.go

# Expose API port
EXPOSE 9090

# Default command (will be overridden by Porter service command)
CMD ["./server"]