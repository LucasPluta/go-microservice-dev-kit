# Web Client Quick Setup

This guide will help you get the React web client up and running quickly.

## Prerequisites

- Node.js 18+ and npm
- Docker and Docker Compose (for full stack)

## Option 1: Full Stack with Docker Compose

Start everything (services + web client):

```bash
# Build and start all services including web client
make up

# Access the web interface
open http://localhost:8080
```

## Option 2: Development Mode

Start backend services with Docker, web client locally:

```bash
# Terminal 1: Start backend services
make up

# Terminal 2: Start React development server
make dev-web-client

# Access development server
open http://localhost:3000
```

## Option 3: Test Setup Only

Verify the web client can be built without starting servers:

```bash
make test-web-client
```

## Available Commands

```bash
# Development
make dev-web-client          # Start React dev server
make test-web-client         # Test setup without starting servers

# Production builds  
make build-web-client        # Build React app for production
make docker-build-web        # Build Docker image

# Full stack
make up                      # Start all services + web client
make down                    # Stop all services
make logs SERVICE=web-client # View web client logs
```

## Architecture

```
┌─────────────┐    ┌─────────┐    ┌──────────────────┐
│   Browser   │───▶│  nginx  │───▶│ example-service  │
│             │    │ (8080)  │    │    (gRPC)        │
└─────────────┘    └─────────┘    └──────────────────┘
       │                │
       │                ▼
       │         ┌─────────────┐
       └────────▶│ React Files │
                 │  (Static)   │
                 └─────────────┘
```

- **nginx** serves React static files and proxies API calls
- **React** client communicates via gRPC-Web
- **gRPC service** handles business logic

## Features Demonstrated

1. **Unary RPC**: `GetStatus` - Simple request/response
2. **Server Streaming**: `StreamData` - Real-time data streaming
3. **Error Handling**: Proper gRPC status code handling
4. **TypeScript Integration**: Fully typed protobuf clients

## File Structure

```
web-client/
├── package.json              # Dependencies and scripts
├── src/
│   ├── App.tsx              # Main React component
│   ├── index.tsx            # Application entry point
│   └── gen/                 # Generated protobuf types
├── public/
│   └── index.html           # HTML template
└── README.md                # Detailed documentation
```

For detailed information, see [web-client/README.md](web-client/README.md).