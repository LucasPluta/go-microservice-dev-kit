# HTTP 415 Fix - Final Solution

## Problem Summary
React web client using Connect-RPC (`@connectrpc/*`) gets HTTP 415 "Unsupported Media Type" error when calling gRPC services.

## Root Cause
Standard gRPC servers only understand:
- Content-Type: `application/grpc` (binary protobuf)

But Connect-RPC sends:
- Content-Type: `application/json` (JSON format)
- Header: `connect-protocol-version: 1`

## Solution Implemented

### 1. Added Connect-RPC Go Library
```bash
go get connectrpc.com/connect@latest
```

### 2. Created Connect Handlers
**File: `services/example-service/internal/handler/connect.go`**

- Wraps existing gRPC handlers
- Implements Connect-RPC protocol
- Handles both unary and streaming RPCs
- Adapts Connect streams to gRPC stream interface

### 3. Updated Server Startup
**File: `services/example-service/cmd/main.go`**

```go
// Create handlers
h := handler.NewHandler(svc)

// Create gRPC server
grpcServer := grpcpkg.NewConnectServer()
pb.RegisterExampleServiceServiceServer(grpcServer, h)

// Create Connect-RPC handlers  
connectMux := http.NewServeMux()
handler.RegisterConnectHandlers(connectMux, h)

// Start dual-protocol server
grpcpkg.StartConnectServer(grpcServer, connectMux, grpcPort)
```

### 4. Updated Server Package
**File: `pkg/grpc/connect.go`**

- Routes requests by Content-Type
- `application/json` or `application/connect*` → Connect handler
- `application/grpc` → gRPC handler
- Uses h2c for HTTP/2 without TLS

### 5. nginx Configuration
**File: `nginx/nginx.conf`**

- Uses HTTP proxy (not gRPC proxy)
- Forwards all Content-Types
- Adds proper CORS headers for Connect protocol

## Request Flow

```
┌──────────────────────────────────────────────────────────────┐
│ Browser                                                       │
│  - Content-Type: application/json                           │
│  - connect-protocol-version: 1                              │
│  - Body: {"serviceId": "test"}                              │
└───────────────────────┬──────────────────────────────────────┘
                        │
                        ▼
┌──────────────────────────────────────────────────────────────┐
│ nginx (HTTP Proxy)                                           │
│  - proxy_pass http://example-service:50051                  │
│  - Forwards request as-is                                   │
└───────────────────────┬──────────────────────────────────────┘
                        │
                        ▼
┌──────────────────────────────────────────────────────────────┐
│ Go Service (Dual Protocol Server)                           │
│                                                              │
│  HTTP Handler checks Content-Type:                          │
│                                                              │
│  ┌──────────────────┐          ┌──────────────────┐        │
│  │ application/json │ ────────>│ Connect Handler  │        │
│  └──────────────────┘          │ (JSON ↔ Proto)   │        │
│                                 └────────┬─────────┘        │
│                                          │                   │
│  ┌──────────────────┐                   ▼                   │
│  │ application/grpc │          ┌──────────────────┐        │
│  └────────┬─────────┘          │  Business Logic  │        │
│           │                    │  (Handler/Service)│        │
│           └───────────────────>└──────────────────┘        │
│                                          │                   │
└──────────────────────────────────────────┼──────────────────┘
                                           │
                                           ▼
                                     Response
```

## How to Apply

### Step 1: Rebuild Service
```bash
cd /Users/lucaspluta/dev/GoMicroserviceFramework

# Use system Go (framework Go was updated)
go build -o bin/example-service ./services/example-service/cmd/
```

### Step 2: Rebuild Docker
```bash
# Stop existing containers
docker-compose down

# Rebuild services
docker-compose build example-service web-client

# Start everything
docker-compose up -d
```

### Step 3: Test
```bash
# Open browser
open http://localhost:8080

# Or test with curl
curl -X POST http://localhost:8080/api/exampleservice.ExampleServiceService/GetStatus \
  -H "Content-Type: application/json" \
  -H "connect-protocol-version: 1" \
  -d '{"serviceId":"test-123"}'
```

## Expected Results

### Success Response
```json
{
  "status": "healthy",
  "message": "Service test-123 is running"
}
```

### Logs
```
Dual-protocol server listening on :50051 (supports gRPC and Connect-RPC)
```

## Files Changed

1. **`go.mod`** - Added `connectrpc.com/connect v1.19.1`
2. **`pkg/grpc/connect.go`** - Dual-protocol server implementation
3. **`services/example-service/internal/handler/connect.go`** - NEW: Connect handlers
4. **`services/example-service/cmd/main.go`** - Updated to register Connect handlers
5. **`nginx/nginx.conf`** - HTTP proxy configuration

## Troubleshooting

### Still Getting 415?

Check Content-Type in logs:
```bash
docker logs example-service 2>&1 | grep -i "content-type\|415"
```

### Check What Handler is Being Used

Add logging to `pkg/grpc/connect.go`:
```go
func StartConnectServer(...) error {
    handler := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        contentType := r.Header.Get("Content-Type")
        log.Printf("Request: %s %s Content-Type: %s", r.Method, r.URL.Path, contentType)
        
        if strings.Contains(contentType, "application/json") {
            log.Println("→ Routing to Connect handler")
            connectHandler.ServeHTTP(w, r)
            return
        }
        
        log.Println("→ Routing to gRPC handler")
        grpcServer.ServeHTTP(w, r)
    })
    //...
}
```

### Verify Connect Handlers Are Registered

```bash
# Check if handlers are registered
docker exec example-service ps aux | grep example-service

# Check logs for "Dual-protocol" message
docker logs example-service 2>&1 | head -10
```

## Why This Works

1. **Separate Protocol Handling**
   - Connect handlers understand JSON → Protobuf conversion
   - gRPC handlers work with binary protobuf

2. **Content-Type Routing**
   - Server inspects Content-Type header
   - Routes to appropriate handler

3. **Shared Business Logic**
   - Both handlers call the same service layer
   - No code duplication

4. **HTTP/2 Support**
   - h2c allows HTTP/2 without TLS
   - Supports streaming in both protocols

## Performance Notes

- Connect-RPC (JSON): ~30-40% larger payloads than binary protobuf
- Negligible performance difference for typical web apps
- For high-throughput: Use native gRPC between services
- For browsers: Connect-RPC is the only option

## Next Steps

1. ✅ Rebuild and test example-service
2. ✅ Update other services when needed
3. ✅ Add Connect handlers to service template
4. 📝 Document in CONNECT_RPC.md

## References

- [Connect-RPC Protocol](https://connectrpc.com/docs/protocol)
- [Connect-Go Documentation](https://connectrpc.com/docs/go/getting-started)
- [Dual Protocol Example](https://connectrpc.com/docs/go/deployment#dual-protocol-support)