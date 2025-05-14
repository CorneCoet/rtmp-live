FROM golang:1.22-alpine

WORKDIR /app

COPY . .
RUN go mod tidy

# Build the application
RUN go build -o /app/server ./main.go

# Command to run the executable
CMD ["/app/server"] 