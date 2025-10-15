# HTTP 415 Error Fix - Connect-RPC Support

## Problem
When using the React web client with Connect-RPC (`@connectrpc/*` packages), you may encounter:
```
HTTP 415 Unsupported Media Type
```

## Root Cause
The original setup used:
1. **nginx with `grpc_pass`** - Only works with native gRPC protocol
2. **Standard gRPC server** - Doesn't understand Connect-RPC HTTP protocol

Connect-RPC uses HTTP/1.1 or HTTP/2 with standard HTTP semantics, not the native gRPC wire protocol.

## Solution Applied

### 1. Updated nginx Configuration
**File: `nginx/nginx.conf`**

Changed from:
```nginx
grpc_pass grpc://example-service:50051;
```

To:
```nginx
proxy_pass http://example-service:50051;
proxy_http_version 1.1;
```

This allows nginx to proxy Connect-RPC HTTP requests instead of expecting native gRPC.

### 2. Added Connect-RPC Server Support
**File: `pkg/grpc/connect.go` (NEW)**

Created `NewConnectServer()` and `StartConnectServer()` functions that:
- Use HTTP/2 with h2c (HTTP/2 Cleartext) support
- Handle both gRPC and Connect-RPC protocols
- Wrap gRPC server with HTTP handler

### 3. Updated example-service
**File: `services/example-service/cmd/main.go`**

Changed from:
```go
grpcServer := grpcpkg.NewServer()
grpcpkg.StartServer(grpcServer, grpcPort)
```

To:
```go
grpcServer := grpcpkg.NewConnectServer()
grpcpkg.StartConnectServer(grpcServer, grpcPort)
```

## How It Works

```
┌──────────┐   HTTP/Connect-RPC    ┌────────┐   HTTP/gRPC    ┌─────────────┐
│ Browser  │ ──────────────────────> │ nginx  │ ──────────────> │ Go Service  │
│ (React)  │   (application/json)   │ (HTTP) │  (h2c wrapped) │  (Connect)  │
└──────────┘                         └────────┘                 └─────────────┘
```

### Protocol Flow:
1. **Browser** sends Connect-RPC request (JSON over HTTP)
2. **nginx** proxies as regular HTTP request
3. **Go service** receives via h2c handler
4. **gRPC server** processes request using Connect protocol
5. **Response** flows back as HTTP/JSON

## Testing the Fix

### 1. Rebuild Services
```bash
cd /Users/lucaspluta/dev/GoMicroserviceFramework
make build-service SERVICE=example-service
```

### 2. Restart Docker Compose
```bash
make down
make up
```

### 3. Test Web Client
Open http://localhost:8080 and try:
- GetStatus RPC call
- StreamData RPC call

Check browser console - should see successful responses.

### 4. Verify with curl
```bash
# Test Connect-RPC endpoint
curl -X POST http://localhost:8080/api/exampleservice.ExampleServiceService/GetStatus \
  -H "Content-Type: application/json" \
  -d '{"serviceId": "test-123"}'
```

Should return JSON response (not 415 error).

## Debugging

### Check nginx logs
```bash
docker logs web-client 2>&1 | grep -i "415\|error"
```

### Check example-service logs
```bash
docker logs example-service 2>&1 | grep -i "error\|listening"
```

Should see:
```
Connect-RPC server listening on :50051 (supports gRPC and Connect-RPC)
```

### Browser DevTools
1. Open browser console (F12)
2. Network tab
3. Look for requests to `/api/...`
4. Check:
   - Request headers include `Content-Type: application/json`
   - Response status is 200 (not 415)
   - Response headers include Connect protocol headers

## Compatibility

The new setup supports:
- ✅ **Connect-RPC** (from browser via @connectrpc/connect-web)
- ✅ **Standard gRPC** (from Go services via google.golang.org/grpc)
- ✅ **grpcurl** (for testing)
- ✅ **gRPC reflection** (for service discovery)

## Future Services

When creating new services with web clients:

1. **In `cmd/main.go`**, use:
   ```go
   grpcServer := grpcpkg.NewConnectServer()
   grpcpkg.StartConnectServer(grpcServer, grpcPort)
   ```

2. **In `nginx.conf`**, use HTTP proxy:
   ```nginx
   location /api/ {
       proxy_pass http://service-name:50051;
       proxy_http_version 1.1;
       # ... CORS headers ...
   }
   ```

3. **In React client**, use Connect-RPC:
   ```typescript
   import { createConnectTransport } from '@connectrpc/connect-web';
   import { createPromiseClient } from '@connectrpc/connect';
   ```

## References

- [Connect-RPC Protocol](https://connectrpc.com/docs/protocol)
- [gRPC vs Connect-RPC](https://connectrpc.com/docs/go/getting-started)
- [nginx HTTP/2 Proxy](https://nginx.org/en/docs/http/ngx_http_proxy_module.html)