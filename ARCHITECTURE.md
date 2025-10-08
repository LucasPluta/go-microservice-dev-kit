# Architecture Overview

## System Architecture

The GoMicroserviceFramework provides a modular, scalable architecture for building Go-based microservices. The framework is designed around clean architecture principles with clear separation of concerns.

## Components

### 1. Infrastructure Layer

The infrastructure layer provides the foundational services that microservices can optionally depend on:

```
┌─────────────────────────────────────────────────┐
│           Infrastructure Services               │
├─────────────┬─────────────┬─────────────────────┤
│  PostgreSQL │    Redis    │        NATS         │
│   (Port     │  (Port      │   (Ports 4222,      │
│    5432)    │   6379)     │         8222)       │
└─────────────┴─────────────┴─────────────────────┘
```

- **PostgreSQL**: Relational database for persistent data storage
- **Redis**: In-memory cache and data structure store
- **NATS**: Message bus for inter-service communication

### 2. Service Layer

Each microservice is independently deployable with its own:

```
┌────────────────────────────────────────┐
│         Microservice Container         │
├────────────────────────────────────────┤
│  ┌──────────────────────────────────┐  │
│  │       gRPC Server (Port 50051)   │  │
│  └──────────────────────────────────┘  │
│  ┌──────────────────────────────────┐  │
│  │    Handler Layer (gRPC Methods)  │  │
│  └──────────────────────────────────┘  │
│  ┌──────────────────────────────────┐  │
│  │   Service Layer (Business Logic) │  │
│  └──────────────────────────────────┘  │
│  ┌──────────────────────────────────┐  │
│  │  Integration Layer (DB, Cache,   │  │
│  │        Messaging)                │  │
│  └──────────────────────────────────┘  │
└────────────────────────────────────────┘
```

## Service Architecture

Each generated service follows a layered architecture:

### Layer Responsibilities

#### 1. Protocol Layer (`proto/`)
- **Purpose**: Define service contracts
- **Contents**: `.proto` files with message and service definitions
- **Generated**: `.pb.go` and `_grpc.pb.go` files

#### 2. Handler Layer (`internal/handler/`)
- **Purpose**: Handle gRPC requests and responses
- **Responsibilities**:
  - Request validation
  - Response marshaling
  - Error handling and status codes
  - Streaming management
- **Dependencies**: Service layer

#### 3. Service Layer (`internal/service/`)
- **Purpose**: Implement business logic
- **Responsibilities**:
  - Core business operations
  - Data transformation
  - Orchestration of multiple operations
  - Integration with databases, caches, and message queues
- **Dependencies**: Infrastructure clients (DB, Redis, NATS)

#### 4. Main Entry Point (`cmd/main.go`)
- **Purpose**: Bootstrap the application
- **Responsibilities**:
  - Configuration loading
  - Dependency injection
  - Infrastructure initialization
  - Graceful shutdown handling

## Communication Patterns

### 1. Synchronous Communication (gRPC)

```
┌─────────┐         gRPC          ┌─────────┐
│ Client  │ ──────────────────────>│ Service │
│         │<────────────────────── │         │
└─────────┘       Response         └─────────┘
```

**Use Cases**:
- Request-response patterns
- Real-time data queries
- Service-to-service calls requiring immediate response

**Types Supported**:
- Unary RPC: Single request, single response
- Server Streaming: Single request, stream of responses

### 2. Asynchronous Communication (NATS)

```
┌───────────┐     Publish      ┌──────┐     Subscribe    ┌───────────┐
│ Publisher │ ────────────────>│ NATS │<───────────────  │ Subscriber│
└───────────┘                  └──────┘                  └───────────┘
```

**Use Cases**:
- Event-driven architectures
- Background job processing
- Fire-and-forget operations
- Decoupled service communication

## Data Flow

### Typical Request Flow

```
1. Client Request
       │
       ▼
2. gRPC Handler (Validation)
       │
       ▼
3. Service Layer (Business Logic)
       │
       ├──────────────┬──────────────┐
       ▼              ▼              ▼
4. Database      Redis Cache    NATS Messaging
       │              │              │
       └──────────────┴──────────────┘
       │
       ▼
5. Response Construction
       │
       ▼
6. Client Response
```

### Caching Strategy

The framework supports a cache-aside pattern:

```
Request
   │
   ▼
Check Redis Cache ──> Cache Hit ──> Return from Cache
   │
   │ Cache Miss
   ▼
Query Database
   │
   ▼
Store in Cache
   │
   ▼
Return Response
```

## Configuration Management

Services are configured via environment variables for 12-factor app compliance:

```
Environment Variables
        │
        ▼
    Service Startup
        │
        ├─────────────┬─────────────┬─────────────┐
        ▼             ▼             ▼             ▼
   gRPC Config  DB Config    Cache Config  Message Config
```

### Configuration Hierarchy

1. **Environment Variables** (Highest Priority)
2. **Default Values** (Fallback)

## Service Discovery

Currently, services use static configuration (Docker Compose service names). For production, consider:

- **Kubernetes**: Service discovery via DNS
- **Consul**: Dynamic service registry
- **etcd**: Distributed configuration

## Deployment Architecture

### Development (Docker Compose)

```
┌─────────────────────────────────────────────┐
│            Docker Compose Network           │
├─────────────────────────────────────────────┤
│                                             │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐ │
│  │PostgreSQL│  │  Redis   │  │   NATS   │ │
│  └──────────┘  └──────────┘  └──────────┘ │
│                                             │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐ │
│  │Service A │  │Service B │  │Service C │ │
│  └──────────┘  └──────────┘  └──────────┘ │
└─────────────────────────────────────────────┘
```

### Production (Kubernetes)

```
┌─────────────────────────────────────────────┐
│          Kubernetes Cluster                 │
├─────────────────────────────────────────────┤
│                                             │
│  ┌────────────────────────────────────┐    │
│  │   Stateful Sets (Databases)        │    │
│  │   - PostgreSQL                     │    │
│  │   - Redis                          │    │
│  │   - NATS                           │    │
│  └────────────────────────────────────┘    │
│                                             │
│  ┌────────────────────────────────────┐    │
│  │   Deployments (Services)           │    │
│  │   - Service A (3 replicas)         │    │
│  │   - Service B (2 replicas)         │    │
│  │   - Service C (5 replicas)         │    │
│  └────────────────────────────────────┘    │
│                                             │
│  ┌────────────────────────────────────┐    │
│  │   Ingress / Load Balancer          │    │
│  └────────────────────────────────────┘    │
└─────────────────────────────────────────────┘
```

## Scalability Patterns

### Horizontal Scaling

Services can be scaled horizontally:

```bash
docker-compose up --scale user-service=3
```

Or in Kubernetes:

```bash
kubectl scale deployment user-service --replicas=3
```

### Database Connection Pooling

Each service maintains a connection pool:
- Max open connections: 25
- Max idle connections: 5
- Connection max lifetime: 5 minutes

### Redis Connection Management

Single Redis client per service with automatic reconnection.

### NATS Message Distribution

NATS automatically distributes messages across service instances in a queue group.

## Security Considerations

### Current Implementation

- Services communicate over internal Docker network
- No authentication on gRPC endpoints (suitable for internal services)
- Database credentials via environment variables

### Production Recommendations

1. **Add TLS for gRPC**:
   ```go
   creds, _ := credentials.NewServerTLSFromFile(certFile, keyFile)
   grpc.NewServer(grpc.Creds(creds))
   ```

2. **Add Authentication**:
   - JWT tokens
   - mTLS (mutual TLS)
   - API keys

3. **Secrets Management**:
   - Use Kubernetes Secrets
   - HashiCorp Vault
   - AWS Secrets Manager

4. **Network Policies**:
   - Restrict service-to-service communication
   - Limit external access

## Monitoring and Observability

### Recommended Additions

1. **Metrics** (Prometheus):
   - Request rate
   - Error rate
   - Duration (latency)
   - Resource utilization

2. **Logging** (Structured):
   - Request IDs for tracing
   - Contextual information
   - Error details

3. **Tracing** (OpenTelemetry/Jaeger):
   - Request flow across services
   - Performance bottlenecks
   - Dependency mapping

4. **Health Checks**:
   - Liveness probes
   - Readiness probes
   - Dependency health

## Extensibility

### Adding New Infrastructure

1. Create package in `pkg/<infrastructure>/`
2. Implement connection management
3. Add configuration to docker-compose.yml
4. Update service generator script

### Custom Middleware

Add gRPC interceptors:

```go
server := grpc.NewServer(
    grpc.UnaryInterceptor(loggingInterceptor),
    grpc.StreamInterceptor(streamLoggingInterceptor),
)
```

### API Gateway Pattern

For HTTP REST support, add an API gateway service:

```
HTTP/REST Client
       │
       ▼
  API Gateway
       │
       ├────────┬────────┬────────┐
       ▼        ▼        ▼        ▼
   Service A Service B Service C ...
```

## Best Practices

1. **Service Independence**: Each service should be independently deployable
2. **Idempotency**: Design operations to be safely retried
3. **Circuit Breakers**: Prevent cascading failures
4. **Graceful Degradation**: Handle dependency failures gracefully
5. **Versioning**: Version your protobuf definitions
6. **Testing**: Unit tests, integration tests, and contract tests
7. **Documentation**: Keep API documentation up-to-date

## Migration Path

### From Monolith to Microservices

1. Identify bounded contexts
2. Extract services one at a time
3. Use strangler fig pattern
4. Maintain data consistency carefully
5. Monitor and measure

## Future Enhancements

- Service mesh integration (Istio, Linkerd)
- GraphQL gateway
- Event sourcing support
- CQRS pattern implementation
- Multi-tenancy support
- Rate limiting
- API versioning strategies
