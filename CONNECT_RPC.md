# Connect-RPC Setup - Complete Guide

## Overview
The GoMicroserviceFramework now supports **Connect-RPC** protocol, allowing React web clients to communicate seamlessly with Go gRPC services over HTTP.

## What Changed

### 1. Server-Side (Go)
- **Added:** `pkg/grpc/connect.go` with Connect-RPC compatible server functions
- **Updated:** `services/example-service/cmd/main.go` to use Connect server
- **Updated:** `scripts/develop/create-service.sh` template for new services

### 2. Client-Side (TypeScript/React)
- Uses `@connectrpc/connect` and `@connectrpc/connect-web` packages
- Protocol: HTTP/1.1 or HTTP/2 with JSON payloads
- Transport: Standard HTTP (not native gRPC wire format)

### 3. Proxy (nginx)
- Changed from `grpc_pass` to `proxy_pass` for HTTP proxying
- Added Connect-RPC specific headers
- Maintains CORS support

## Quick Start

### For Existing Services
If you're getting HTTP 415 errors:

```bash
# 1. Rebuild services
make build-service SERVICE=example-service

# 2. Rebuild Docker images
make down
docker-compose build example-service web-client

# 3. Start everything
make up

# 4. Test
open http://localhost:8080
```

### For New Services
New services created with `./scripts/develop/create-service.sh` automatically include Connect-RPC support.

## Architecture

```
┌────────────────┐
│ React Browser  │
│  (@connectrpc) │
└───────┬────────┘
        │ HTTP/JSON
        │ (Connect-RPC Protocol)
        ▼
┌────────────────┐
│     nginx      │
│ (HTTP Proxy)   │
└───────┬────────┘
        │ HTTP
        │ (Proxied)
        ▼
┌────────────────┐
│  Go Service    │
│ (h2c Handler)  │
│ ┌────────────┐ │
│ │ gRPC Server│ │
│ └────────────┘ │
└────────────────┘
```

## Protocol Comparison

| Feature | Native gRPC | Connect-RPC |
|---------|-------------|-------------|
| Wire Format | Protobuf binary | JSON or Protobuf |
| Transport | HTTP/2 only | HTTP/1.1 or HTTP/2 |
| Browser Support | Requires proxy | Native |
| Content-Type | `application/grpc` | `application/json` |
| Streaming | Bidirectional | Server streaming |
| Our Usage | Service-to-service | Browser-to-service |

## Server Implementation

### Old (gRPC only):
```go
grpcServer := grpc.NewServer()
pb.RegisterMyServiceServer(grpcServer, handler)
grpc.StartServer(grpcServer, port)
```

### New (gRPC + Connect-RPC):
```go
grpcServer := grpc.NewConnectServer()
pb.RegisterMyServiceServer(grpcServer, handler)
grpc.StartConnectServer(grpcServer, port)
```

The new server:
- ✅ Accepts Connect-RPC requests (HTTP/JSON from browsers)
- ✅ Accepts standard gRPC requests (from other Go services)
- ✅ Supports gRPC reflection
- ✅ Works with grpcurl and other gRPC tools

## Client Implementation

### Browser (TypeScript):
```typescript
import { createConnectTransport } from '@connectrpc/connect-web';
import { createPromiseClient } from '@connectrpc/connect';

const transport = createConnectTransport({
  baseUrl: '/api',
});

const client = createPromiseClient(MyService, transport);
const response = await client.myMethod(request);
```

### Go (Standard gRPC):
```go
conn, _ := grpc.Dial("localhost:50051", grpc.WithInsecure())
client := pb.NewMyServiceClient(conn)
response, _ := client.MyMethod(ctx, request)
```

## nginx Configuration

```nginx
location /api/ {
    rewrite ^/api/(.*)$ /$1 break;
    
    # HTTP proxy (not grpc_pass!)
    proxy_pass http://example-service:50051;
    proxy_http_version 1.1;
    
    # Standard HTTP proxy headers
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    
    # CORS for browser
    add_header 'Access-Control-Allow-Origin' '*' always;
    # ... more CORS headers ...
}
```

## Troubleshooting

### HTTP 415 Error
**Cause:** nginx trying to use gRPC protocol with Connect-RPC client

**Fix:** 
1. Check `nginx/nginx.conf` uses `proxy_pass` (not `grpc_pass`)
2. Rebuild web-client Docker image: `docker-compose build web-client`

### Connection Refused
**Cause:** Service not listening or wrong port

**Fix:**
1. Check service logs: `docker logs example-service`
2. Should see: "Connect-RPC server listening on :50051"
3. Verify port mapping in docker-compose.yml

### CORS Errors
**Cause:** Missing or incorrect CORS headers in nginx

**Fix:**
1. Verify nginx.conf has CORS headers in `/api/` location
2. Check browser DevTools Network tab for preflight OPTIONS request
3. Restart nginx: `docker-compose restart web-client`

### Streaming Not Working
**Cause:** Connect-RPC has limited streaming support compared to gRPC

**Note:** 
- Server streaming works
- Client streaming and bidirectional require different approach
- For full streaming, use standard gRPC from non-browser clients

## Testing

### Manual Test (curl):
```bash
# Connect-RPC request
curl -X POST http://localhost:8080/api/exampleservice.ExampleServiceService/GetStatus \
  -H "Content-Type: application/json" \
  -d '{"serviceId": "test-123"}'

# Should return JSON response
```

### Browser Test:
1. Open http://localhost:8080
2. Enter service ID and click "Get Status"
3. Check browser console for response
4. Try "Stream Data" feature

### Go Client Test:
```bash
# Use grpcurl
grpcurl -plaintext localhost:50051 list
grpcurl -plaintext localhost:50051 \
  exampleservice.ExampleServiceService/GetStatus
```

## Migration Checklist

For migrating existing services:

- [ ] Add `pkg/grpc/connect.go` if not present
- [ ] Update `cmd/main.go` to use `NewConnectServer()` and `StartConnectServer()`
- [ ] Update `nginx.conf` to use `proxy_pass` instead of `grpc_pass`
- [ ] Rebuild service binary
- [ ] Rebuild Docker images
- [ ] Test with web client
- [ ] Verify service-to-service gRPC still works

## Performance Notes

- Connect-RPC JSON: ~1.5-2x larger payloads than Protobuf
- HTTP/1.1: Multiple connections for concurrent requests
- HTTP/2: Multiplexing on single connection
- For high-throughput inter-service: Use standard gRPC
- For browser clients: Use Connect-RPC

## References

- [Connect-RPC Documentation](https://connectrpc.com/)
- [Connect-ES (TypeScript)](https://connectrpc.com/docs/web/getting-started)
- [Connect-Go](https://connectrpc.com/docs/go/getting-started)
- [gRPC-Web vs Connect](https://connectrpc.com/docs/protocol)