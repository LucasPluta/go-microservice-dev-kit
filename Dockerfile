# Multi-architecture Dockerfile for Go microservices
# Usage: docker build --build-arg SERVICE_NAME=example-service --build-arg TARGETARCH=amd64 -t service-name .
# Note: Binaries should be pre-built using the Makefile before running docker build

ARG TARGETARCH=amd64
ARG TARGETOS=linux

# Use a minimal base image to get CA certificates and timezone data
FROM alpine:latest AS certs
RUN apk add --no-cache ca-certificates tzdata

# Final stage - using scratch for minimal image size
FROM scratch

ARG SERVICE_NAME
ARG TARGETARCH
ARG TARGETOS

# Copy CA certificates for HTTPS
COPY --from=certs /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/

# Copy timezone data
COPY --from=certs /usr/share/zoneinfo /usr/share/zoneinfo

# Copy the pre-built binary for the target architecture
COPY bin/${SERVICE_NAME}-${TARGETOS}-${TARGETARCH} /service

# Expose gRPC port (default)
EXPOSE 50051

# Run the service
ENTRYPOINT ["/service"]
