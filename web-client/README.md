# Example Service Web Client

A React-based web client that interfaces with the example-service using gRPC-Web.

## Features

- **Unary RPC**: Get service status
- **Server Streaming RPC**: Stream data from the service
- **gRPC-Web Integration**: Seamless communication with gRPC services through nginx proxy
- **TypeScript**: Fully typed protobuf-generated clients

## Architecture

```
┌─────────────┐    HTTP/gRPC-Web    ┌─────────┐    gRPC    ┌──────────────────┐
│ React Client│ ──────────────────> │  nginx  │ ─────────> │ example-service  │
│  (Browser)  │                     │ (Proxy) │            │    (gRPC)        │
└─────────────┘                     └─────────┘            └──────────────────┘
```

The React client communicates with the gRPC service through an nginx proxy that:
- Serves the static React application
- Proxies gRPC-Web requests to the backend service
- Handles CORS headers for browser compatibility

## Development

### Prerequisites

- Node.js 18+
- npm

### Setup and Development

```bash
# Install dependencies and start development server
make dev-web-client

# Or manually:
cd web-client
npm install
npm run proto  # Generate TypeScript types from protobuf
npm start      # Start development server on http://localhost:3000
```

### Building for Production

```bash
# Build the React application
make build-web-client

# Build Docker image
make docker-build-web
```

### Generated Files

The `npm run proto` command generates TypeScript types from the protobuf definitions:

- `src/gen/example-service_pb.ts` - Message types
- `src/gen/example-service_connect.ts` - Service client types

## Usage

### In Docker Compose

The web client is automatically included when you run:

```bash
make up
```

Access the web interface at http://localhost:8080

### Standalone Development

For development with a local React dev server:

```bash
# Terminal 1: Start backend services
make up

# Terminal 2: Start React dev server
make dev-web-client
```

Access the development server at http://localhost:3000

## API Integration

The client uses [@bufbuild/connect](https://github.com/bufbuild/connect-es) for gRPC-Web communication:

```typescript
import { createConnectTransport } from '@connectrpc/connect-web';
import { createPromiseClient } from '@connectrpc/connect';
import { ExampleServiceService } from './gen/example-service_connect';

const transport = createConnectTransport({
  baseUrl: '/api', // Proxied by nginx to gRPC service
});

const client = createPromiseClient(ExampleServiceService, transport);
```

## File Structure

```
web-client/
├── package.json          # Dependencies and scripts
├── tsconfig.json         # TypeScript configuration
├── buf.gen.yaml          # Protobuf generation config
├── public/
│   └── index.html        # HTML template
└── src/
    ├── index.tsx         # Application entry point
    ├── App.tsx           # Main application component
    ├── index.css         # Styles
    └── gen/              # Generated protobuf types (created by npm run proto)
```

## Nginx Configuration

The nginx configuration (`nginx/nginx.conf`) handles:

- Serving static React files
- Proxying `/api/*` requests to the gRPC service
- Adding appropriate CORS headers
- Health check endpoint

## Troubleshooting

### Common Issues

1. **Protobuf types not found**: Run `npm run proto` to generate TypeScript types
2. **CORS errors**: Ensure nginx is properly configured and running
3. **Connection refused**: Verify the example-service is running and accessible

### Development vs Production

- **Development**: React dev server proxies API requests to localhost:8080 (nginx)
- **Production**: nginx serves both static files and proxies API requests