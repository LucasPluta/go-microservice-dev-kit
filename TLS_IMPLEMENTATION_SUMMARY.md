# TLS Security Implementation Summary

## Changes Made

This update adds comprehensive **TLS 1.2/1.3 transport security** to the GoMicroserviceFramework. All client-server communication is now encrypted with secure cipher suites.

## New Files Created

### Core TLS Implementation
1. **`pkg/grpc/tls.go`** - TLS configuration and utilities
   - `GetSecureCipherSuites()` - Mozilla "Modern" cipher suite configuration
   - `NewServerTLSConfig()` - Server TLS configuration with mTLS support
   - `NewSecureGRPCServer()` - TLS-enabled gRPC server factory
   - `NewClientTLSConfig()` - Client TLS configuration

2. **`scripts/setup/generate-certs.sh`** - Certificate generation script
   - Generates CA certificate and key
   - Generates server certificate with SANs for all services
   - Generates client certificate for mTLS
   - Includes proper permissions and cleanup

3. **`setup-tls.sh`** - Automated TLS setup and deployment
   - Generates certificates if needed
   - Builds services with TLS support
   - Deploys with TLS enabled
   - Verifies TLS connections

4. **`TLS_SECURITY.md`** - Comprehensive TLS documentation
   - Quick start guide
   - Configuration reference
   - Security best practices
   - Testing procedures
   - Production deployment guide
   - Troubleshooting

### Modified Files

#### gRPC Server Enhancement
- **`pkg/grpc/connect.go`**
  - Added `NewSecureConnectServer()` - Creates TLS-enabled dual-protocol server
  - Added `StartSecureConnectServer()` - Starts TLS-enabled HTTP/2 server
  - Supports both regular and TLS modes

#### Service Configuration
- **`services/example-service/cmd/main.go`**
  - Added TLS configuration environment variables
  - Conditional TLS server creation based on `USE_TLS` flag
  - Supports both TLS and non-TLS modes for backwards compatibility

#### Docker Configuration
- **`Dockerfile`** - Updated to include TLS certificates
- **`Dockerfile.web`** - Updated nginx image with TLS certificates and HTTPS support
- **`docker-compose.yml`** - Added TLS environment variables and ports

#### nginx Configuration
- **`nginx/nginx.conf`**
  - Added HTTPS listener on port 443
  - HTTP to HTTPS redirect
  - Modern TLS configuration (TLS 1.2/1.3 only)
  - Secure cipher suites
  - HSTS, OCSP stapling, security headers
  - TLS proxy to backend services

#### Web Client
- **`web-client/src/App.tsx`** - Updated to use HTTPS endpoint in production

#### Build System
- **`Makefile`** - Added `setup-tls` and `generate-certs` targets
- **`scripts/setup/setup.mk`** - Added TLS setup targets
- **`.gitignore`** - Excluded certificates and private keys

## Security Features

### ✅ Implemented

1. **Transport Encryption**
   - TLS 1.2 and 1.3 only (no older protocols)
   - Forward secrecy with ECDHE/DHE key exchange
   - Authenticated encryption (GCM/Poly1305)

2. **Cipher Suites** (Mozilla "Modern" Configuration)
   - TLS 1.3: AES-GCM, ChaCha20-Poly1305
   - TLS 1.2: ECDHE with AES-GCM and ChaCha20-Poly1305
   - Strong curves: X25519, P-256, P-384

3. **Certificate Management**
   - Self-signed CA for development
   - Server certificates with Subject Alternative Names (SANs)
   - Client certificates for mTLS (optional)
   - Proper certificate validation

4. **Additional Security Headers** (nginx)
   - HSTS (HTTP Strict Transport Security)
   - X-Frame-Options
   - X-Content-Type-Options
   - X-XSS-Protection

5. **Flexible Configuration**
   - Environment-based TLS enable/disable
   - Optional mTLS support
   - Configurable certificate paths
   - Development and production modes

## Quick Start

### 1. Generate Certificates
```bash
./scripts/setup/generate-certs.sh
```

### 2. Trust CA Certificate (macOS)
```bash
sudo security add-trusted-cert -d -r trustRoot \
  -k /Library/Keychains/System.keychain certs/ca-cert.pem
```

### 3. Setup TLS and Deploy
```bash
./setup-tls.sh
```

Or step by step:
```bash
make generate-certs
make build
docker-compose build
docker-compose up -d
```

### 4. Access Services
- Web Client: **https://localhost:8443**
- gRPC Service: **grpc://localhost:50051** (TLS)

## Configuration

### Environment Variables

Services are configured via environment variables in `docker-compose.yml`:

```yaml
environment:
  - USE_TLS=true                                # Enable TLS
  - TLS_CERT_FILE=/certs/server-cert.pem       # Server certificate
  - TLS_KEY_FILE=/certs/server-key.pem         # Server private key
  - TLS_CA_FILE=/certs/ca-cert.pem             # CA certificate
  - TLS_REQUIRE_CLIENT_AUTH=false              # Require mTLS
```

### Disable TLS (Not Recommended)

To disable TLS:
```yaml
environment:
  - USE_TLS=false
```

## Testing

### Test gRPC with TLS
```bash
grpcurl -cacert certs/ca-cert.pem \
  -d '{"service_id": "test"}' \
  localhost:50051 \
  exampleservice.ExampleServiceService/GetStatus
```

### Test Web Client
```bash
# Browser (after trusting CA cert)
open https://localhost:8443

# curl
curl --cacert certs/ca-cert.pem https://localhost:8443
```

### Test mTLS
```bash
grpcurl -cacert certs/ca-cert.pem \
  -cert certs/client-cert.pem \
  -key certs/client-key.pem \
  -d '{"service_id": "test"}' \
  localhost:50051 \
  exampleservice.ExampleServiceService/GetStatus
```

## Architecture

### TLS Flow
```
┌──────────────┐     HTTPS      ┌────────────┐     gRPC/TLS   ┌─────────────────┐
│   Browser    │ ───────────────→│   nginx    │ ───────────────→│ example-service │
│  (Client)    │  TLS 1.2/1.3    │  (Proxy)   │   TLS 1.2/1.3  │   (Backend)     │
└──────────────┘                 └────────────┘                 └─────────────────┘
```

### What's Protected
- ✅ Browser → nginx: HTTPS (TLS 1.2/1.3)
- ✅ nginx → Backend: gRPC/TLS (TLS 1.2/1.3)
- ✅ Direct gRPC clients → Backend: gRPC/TLS
- ✅ Service-to-service: gRPC/TLS (when enabled)

## Production Deployment

### ⚠️ Development vs Production

**Development (Current Setup):**
- Self-signed certificates
- Single CA for all services
- Certificates in repository (gitignored)

**Production (Recommended):**
- Use trusted CA certificates (Let's Encrypt, DigiCert, etc.)
- Separate certificates per service
- Certificate rotation/renewal automation
- Store certificates in secrets management (Kubernetes secrets, Vault)
- Enable mTLS for service-to-service communication

### Using Let's Encrypt
```bash
# Obtain certificates
certbot certonly --standalone -d yourdomain.com

# Update docker-compose.yml
services:
  example-service:
    environment:
      - TLS_CERT_FILE=/etc/letsencrypt/live/yourdomain.com/fullchain.pem
      - TLS_KEY_FILE=/etc/letsencrypt/live/yourdomain.com/privkey.pem
    volumes:
      - /etc/letsencrypt:/etc/letsencrypt:ro
```

## Security Best Practices

### ✅ DO
- Use TLS 1.2/1.3 only
- Use modern cipher suites with forward secrecy
- Rotate certificates before expiration
- Monitor certificate expiration
- Use trusted CA certificates in production
- Enable mTLS for service-to-service communication
- Store private keys securely (never commit to git)

### ❌ DON'T
- Use self-signed certificates in production
- Commit private keys to version control
- Use outdated TLS versions (SSL, TLS 1.0, TLS 1.1)
- Use weak cipher suites
- Disable certificate validation

## Troubleshooting

### Certificate Not Trusted
**Error:** `x509: certificate signed by unknown authority`

**Solution:** Trust the CA certificate on your system (see Quick Start).

### TLS Handshake Failure
**Error:** `tls: handshake failure`

**Debug:**
```bash
# Check certificate
openssl x509 -in certs/server-cert.pem -text -noout

# Test TLS connection
openssl s_client -connect localhost:50051 -CAfile certs/ca-cert.pem
```

### Browser Certificate Warning
**Issue:** "Your connection is not private"

**Solution:** Import `certs/ca-cert.pem` into browser's certificate authorities.

## Makefile Commands

```bash
make generate-certs      # Generate TLS certificates
make setup-tls           # Full TLS setup and deployment
make build               # Build services (TLS-aware)
make up                  # Start services with TLS
make logs                # View service logs
make down                # Stop services
```

## Next Steps

### Recommended Enhancements
1. **Certificate Monitoring** - Add expiration alerts
2. **Auto-Renewal** - Implement Let's Encrypt auto-renewal
3. **mTLS by Default** - Require client certificates for all services
4. **Certificate Pinning** - Pin certificates in mobile/desktop clients
5. **OCSP Stapling** - Enable certificate revocation checking
6. **HSM Integration** - Store private keys in Hardware Security Module

### Migration Path
1. **Phase 1** (Current): Development with self-signed certs
2. **Phase 2**: Staging with Let's Encrypt
3. **Phase 3**: Production with enterprise CA + mTLS
4. **Phase 4**: Add certificate monitoring and automation

## Documentation

- **TLS_SECURITY.md** - Comprehensive TLS guide
- **README.md** - Updated with TLS instructions
- **ARCHITECTURE.md** - TLS architecture details
- **.github/copilot-instructions.md** - AI assistant TLS guidance

## Backward Compatibility

TLS is **enabled by default** but can be disabled:
- Set `USE_TLS=false` to disable TLS
- Services work in both TLS and non-TLS modes
- No breaking changes to existing services

## Support

For issues or questions:
1. Check TLS_SECURITY.md for detailed documentation
2. Review troubleshooting section
3. Check service logs: `make logs SERVICE=example-service`
4. Verify certificates: `openssl x509 -in certs/server-cert.pem -text -noout`
