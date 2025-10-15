# Web Client - Quick Reference

## ✅ Status: WORKING

The React web client is now fully functional with webpack 5 build system.

## Quick Start

```bash
# 1. Test the setup (recommended first step)
make test-web-client

# 2. Start development
make dev-web-client        # React dev server on http://localhost:3000

# 3. Or start full stack
make up                    # All services + web client on http://localhost:8080
```

## Commands

| Command | Purpose |
|---------|---------|
| `make test-web-client` | Verify Node.js, dependencies, protobuf, build |
| `make dev-web-client` | Start webpack dev server (port 3000) |
| `make build-web-client` | Production build to `web-client/build/` |
| `make docker-build-web` | Build Docker image for web client |
| `make up` | Start all services including web client |

## Project Structure

```
web-client/
├── package.json           # Dependencies (webpack, React, Connect-RPC)
├── webpack.config.js      # Webpack 5 configuration
├── tsconfig.json         # TypeScript settings
├── buf.yaml              # Buf workspace config
├── buf.gen.yaml          # Protobuf generation (local plugins)
├── src/
│   ├── index.tsx         # Entry point
│   ├── App.tsx           # Main component with gRPC client
│   ├── index.css         # Styles
│   └── gen/              # Auto-generated protobuf types
│       ├── example-service_pb.ts
│       └── example-service_connect.ts
├── public/
│   └── index.html        # HTML template
└── build/                # Production output (gitignored)
```

## Technology Stack

- **React 18.3** - UI framework
- **TypeScript 5.3** - Type safety
- **Webpack 5** - Module bundler
- **Connect-RPC** (`@connectrpc/*`) - gRPC-Web client
- **Buf** - Protocol buffer toolchain

## Build Process

```
1. npm run proto
   └─> Generates TypeScript types from .proto files

2. webpack --mode production
   └─> Compiles TypeScript
   └─> Bundles React app
   └─> Optimizes and minifies
   └─> Outputs to build/
```

## Development Workflow

### Option A: Local Dev Server
```bash
# Terminal 1: Backend
make up

# Terminal 2: Frontend
make dev-web-client
# Access: http://localhost:3000 (proxies API to nginx:8080)
```

### Option B: Full Docker Stack
```bash
make up
# Access: http://localhost:8080 (nginx serves React + proxies gRPC)
```

## Adding New RPC Methods

1. **Update proto:**
   ```bash
   vi services/example-service/proto/example-service.proto
   ```

2. **Regenerate Go code:**
   ```bash
   make proto SERVICE=example-service
   ```

3. **Regenerate TypeScript:**
   ```bash
   cd web-client && npm run proto
   ```

4. **Update React component:**
   ```typescript
   // src/App.tsx
   const response = await client.yourNewMethod(request);
   ```

5. **Test:**
   ```bash
   npm start  # or make dev-web-client
   ```

## Troubleshooting

### "Module not found" errors after proto changes
```bash
cd web-client
rm -rf src/gen
npm run proto
```

### Build fails with dependency errors
```bash
cd web-client
rm -rf node_modules package-lock.json
npm install
```

### Can't connect to gRPC service
Check that:
1. Backend is running: `docker ps | grep example-service`
2. Nginx is running: `docker ps | grep nginx`
3. Nginx config correct: `cat nginx/nginx.conf`

### Hot reload not working
```bash
# Restart dev server
cd web-client
npm start
```

## Documentation

- **BUILD.md** - Detailed build system explanation
- **README.md** - General web client overview
- **WEB_CLIENT_FIX.md** - Migration from react-scripts to webpack

## Architecture

```
Browser ──HTTP/gRPC-Web──> nginx:80 ──gRPC──> example-service:50051
   │                          │
   └───Static Files───────────┘
```

- **nginx** serves React build and proxies `/api/*` to gRPC
- **React** uses Connect-RPC for type-safe gRPC-Web calls
- **Protobuf** provides shared types between Go and TypeScript

## Testing Checklist

- [ ] `make test-web-client` passes
- [ ] `npm start` opens browser and loads
- [ ] GetStatus RPC works (check browser console)
- [ ] StreamData RPC works (check browser console)
- [ ] `npm run build` creates build/ directory
- [ ] `make docker-build-web` succeeds
- [ ] `make up` starts web-client service
- [ ] http://localhost:8080 loads in browser