# Multi-architecture Dockerfile for building Go microservices
# Usage: docker build --build-arg SERVICE_NAME=example-service -t service-name .

ARG GOLANG_VERSION=1.21
ARG TARGETARCH
ARG TARGETOS

# Build stage
FROM --platform=${BUILDPLATFORM:-linux/amd64} golang:${GOLANG_VERSION}-alpine AS builder

ARG SERVICE_NAME
ARG TARGETARCH
ARG TARGETOS
ARG BUILDPLATFORM

WORKDIR /build

# Install build dependencies including protoc
RUN apk add --no-cache git ca-certificates tzdata protobuf-dev protoc

# Install Go protoc plugins
RUN go install google.golang.org/protobuf/cmd/protoc-gen-go@latest && \
    go install google.golang.org/grpc/cmd/protoc-gen-go-grpc@latest

# Copy go modules for the framework
COPY go.mod go.sum ./
RUN go mod download

# Copy framework packages
COPY pkg/ ./pkg/

# Copy the specific service
COPY services/${SERVICE_NAME}/ ./services/${SERVICE_NAME}/

# Change to service directory
WORKDIR /build/services/${SERVICE_NAME}

# Download service-specific dependencies
RUN go mod download

# Generate protobuf code if proto file exists
RUN if [ -f "proto/${SERVICE_NAME}.proto" ]; then \
        protoc --go_out=. --go_opt=paths=source_relative \
               --go-grpc_out=. --go-grpc_opt=paths=source_relative \
               proto/${SERVICE_NAME}.proto; \
    fi

# Build the service with optimizations
RUN CGO_ENABLED=0 GOOS=${TARGETOS} GOARCH=${TARGETARCH} \
    go build -a -installsuffix cgo \
    -ldflags='-w -s -extldflags "-static"' \
    -o /app/service \
    ./cmd/main.go

# Final stage - using scratch for minimal image size
FROM scratch

# Copy CA certificates for HTTPS
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/

# Copy timezone data
COPY --from=builder /usr/share/zoneinfo /usr/share/zoneinfo

# Copy the binary
COPY --from=builder /app/service /service

# Expose gRPC port (default)
EXPOSE 50051

# Run the service
ENTRYPOINT ["/service"]
