# TLS Security Implementation

## Overview

This framework implements **TLS 1.2/1.3 transport security** with secure cipher suites for all client-server communication. All gRPC services and web traffic are encrypted end-to-end.

## Features

### ✅ Security Enhancements
- **TLS 1.2/1.3 Only**: Modern protocol versions with no fallback to insecure protocols
- **Secure Cipher Suites**: Mozilla "Modern" configuration with forward secrecy
  - TLS 1.3: AES-GCM and ChaCha20-Poly1305
  - TLS 1.2: ECDHE with AES-GCM and ChaCha20-Poly1305
- **Strong Curves**: X25519, P-256, P-384 for key exchange
- **HSTS**: HTTP Strict Transport Security enforced
- **Certificate Validation**: Full chain validation with CA certificates
- **Optional mTLS**: Mutual TLS for client authentication

### 🔐 What's Protected
1. **gRPC Service Communication**: All service-to-service and client-to-service calls
2. **Web Interface**: HTTPS for all web client traffic
3. **Connect-RPC/gRPC-Web**: Encrypted proxy through nginx
4. **HTTP/2**: Full HTTP/2 over TLS support

## Quick Start

### 1. Generate TLS Certificates

For development, generate self-signed certificates:

```bash
./scripts/setup/generate-certs.sh
```

This creates:
- `certs/ca-cert.pem` - Root CA certificate
- `certs/ca-key.pem` - Root CA private key
- `certs/server-cert.pem` - Server certificate (includes SANs for all services)
- `certs/server-key.pem` - Server private key
- `certs/client-cert.pem` - Client certificate (for mTLS)
- `certs/client-key.pem` - Client private key (for mTLS)

⚠️ **Important**: Trust the CA certificate on your system:

**macOS:**
```bash
sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain certs/ca-cert.pem
```

**Linux:**
```bash
sudo cp certs/ca-cert.pem /usr/local/share/ca-certificates/gomicroservices-ca.crt
sudo update-ca-certificates
```

**Browser:** Import `certs/ca-cert.pem` into your browser's certificate store.

### 2. Enable TLS

TLS is **enabled by default** in docker-compose. Services automatically use TLS when `USE_TLS=true`.

To disable TLS (not recommended):
```bash
# In docker-compose.yml, set:
USE_TLS=false
```

### 3. Start Services

```bash
make up
```

Services will start with TLS enabled:
- gRPC services: `https://localhost:50051`
- Web client: `https://localhost:8443`

## Configuration

### Environment Variables

Configure TLS via environment variables in `docker-compose.yml` or service startup:

| Variable | Default | Description |
|----------|---------|-------------|
| `USE_TLS` | `true` | Enable/disable TLS |
| `TLS_CERT_FILE` | `/certs/server-cert.pem` | Path to server certificate |
| `TLS_KEY_FILE` | `/certs/server-key.pem` | Path to server private key |
| `TLS_CA_FILE` | `/certs/ca-cert.pem` | Path to CA certificate |
| `TLS_REQUIRE_CLIENT_AUTH` | `false` | Require client certificates (mTLS) |

### Example: Enable mTLS

To require client certificate authentication:

```yaml
services:
  example-service:
    environment:
      - USE_TLS=true
      - TLS_REQUIRE_CLIENT_AUTH=true
```

Then clients must provide a valid client certificate.

## Testing TLS Connections

### Test gRPC Service with grpcurl

```bash
# With TLS (using CA certificate)
grpcurl -cacert certs/ca-cert.pem \
  -d '{"service_id": "test"}' \
  localhost:50051 \
  exampleservice.ExampleServiceService/GetStatus

# With mTLS (client certificate required)
grpcurl -cacert certs/ca-cert.pem \
  -cert certs/client-cert.pem \
  -key certs/client-key.pem \
  -d '{"service_id": "test"}' \
  localhost:50051 \
  exampleservice.ExampleServiceService/GetStatus
```

### Test Web Client

```bash
# Access via browser (trust CA cert first)
open https://localhost:8443

# Or with curl
curl --cacert certs/ca-cert.pem https://localhost:8443
```

### Test nginx → Backend TLS

```bash
# nginx proxies HTTPS → gRPC/TLS backend
curl -k https://localhost:8443/api/exampleservice.ExampleServiceService/GetStatus \
  -H "Content-Type: application/json" \
  -d '{"serviceId": "test"}'
```

## Security Best Practices

### Development vs Production

**Development (Self-Signed Certs):**
- ✅ Use for local testing
- ✅ Trust CA cert on dev machines
- ❌ **Never** use in production
- ❌ **Never** commit private keys to git

**Production:**
- ✅ Use certificates from trusted CA (Let's Encrypt, DigiCert, etc.)
- ✅ Automate certificate renewal
- ✅ Store private keys securely (Kubernetes secrets, Vault, etc.)
- ✅ Enable mTLS for service-to-service communication
- ✅ Use separate certificates per environment

### Certificate Management

**Rotation:**
```bash
# Generate new certificates
./scripts/setup/generate-certs.sh

# Rebuild services
make build
make up
```

**Monitoring:**
- Monitor certificate expiration dates
- Set up alerts for certificates expiring within 30 days
- Automate renewal process

### Cipher Suite Selection

The framework uses Mozilla's "Modern" cipher suite configuration:

**TLS 1.3 (Preferred):**
- `TLS_AES_128_GCM_SHA256`
- `TLS_AES_256_GCM_SHA384`
- `TLS_CHACHA20_POLY1305_SHA256`

**TLS 1.2 (Fallback):**
- `TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256`
- `TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256`
- `TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384`
- `TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384`
- `TLS_ECDHE_ECDSA_WITH_CHACHA20_POLY1305_SHA256`
- `TLS_ECDHE_RSA_WITH_CHACHA20_POLY1305_SHA256`

All cipher suites provide:
- ✅ Forward secrecy (ECDHE/DHE)
- ✅ Authenticated encryption (GCM/Poly1305)
- ✅ No known vulnerabilities

## Architecture

### TLS Flow

```
┌──────────────┐     HTTPS      ┌────────────┐     gRPC/TLS   ┌─────────────────┐
│   Browser    │ ───────────────→│   nginx    │ ───────────────→│ example-service │
│  (Client)    │  TLS 1.2/1.3    │  (Proxy)   │   TLS 1.2/1.3  │   (Backend)     │
└──────────────┘                 └────────────┘                 └─────────────────┘
      │                                │                               │
      └─ Validates server cert         └─ Terminates TLS              └─ Validates client
         using CA cert                    Validates backend cert          using TLS config
```

### Certificate Hierarchy

```
┌──────────────────────┐
│   CA Certificate     │ ← Root of trust
│  (ca-cert.pem)       │
└──────────┬───────────┘
           │
           ├─────────────────────────────────┐
           ↓                                 ↓
┌──────────────────────┐         ┌──────────────────────┐
│ Server Certificate   │         │ Client Certificate   │
│ (server-cert.pem)    │         │ (client-cert.pem)    │
│                      │         │                      │
│ SANs:                │         │ Used for mTLS        │
│ - localhost          │         │                      │
│ - *.localhost        │         │                      │
│ - example-service    │         │                      │
│ - user-service       │         │                      │
│ - 127.0.0.1          │         │                      │
└──────────────────────┘         └──────────────────────┘
```

## Code Reference

### Server-Side TLS Configuration

**Creating TLS-enabled server:**
```go
import "github.com/LucasPluta/GoMicroserviceFramework/pkg/grpc"

tlsConfig := grpcpkg.TLSConfig{
    CertFile:   "/certs/server-cert.pem",
    KeyFile:    "/certs/server-key.pem",
    CAFile:     "/certs/ca-cert.pem",
    ClientAuth: false, // Set true for mTLS
}

server, err := grpcpkg.NewSecureConnectServer(tlsConfig)
if err != nil {
    log.Fatal(err)
}
```

**Starting TLS server:**
```go
err := grpcpkg.StartSecureConnectServer(grpcServer, connectMux, tlsConfig, "50051")
```

### Client-Side TLS Configuration

**Go gRPC client:**
```go
creds, err := grpcpkg.NewClientTLSConfig("certs/ca-cert.pem", "localhost")
if err != nil {
    log.Fatal(err)
}

conn, err := grpc.Dial("localhost:50051", grpc.WithTransportCredentials(creds))
```

**TypeScript/React client:**
```typescript
const transport = createConnectTransport({
  baseUrl: 'https://localhost:8443/api',
  // Browser automatically validates TLS if CA is trusted
});
```

## Troubleshooting

### Certificate Not Trusted

**Error:** `x509: certificate signed by unknown authority`

**Solution:** Trust the CA certificate on your system (see Quick Start).

### TLS Handshake Failures

**Error:** `tls: handshake failure`

**Causes:**
1. Certificate/key mismatch
2. Expired certificates
3. Wrong hostname in certificate

**Debug:**
```bash
# Check certificate details
openssl x509 -in certs/server-cert.pem -text -noout

# Test TLS connection
openssl s_client -connect localhost:50051 -CAfile certs/ca-cert.pem
```

### nginx → Backend Connection Issues

**Error:** `upstream SSL certificate verify error`

**Solution:** Ensure nginx has access to CA certificate and backend certificate is valid.

Check nginx logs:
```bash
docker logs web-client
```

### Browser Certificate Warnings

**Issue:** Browser shows "Your connection is not private"

**Solution:** Import `certs/ca-cert.pem` into browser's certificate authorities.

**Chrome:** Settings → Privacy and security → Security → Manage certificates → Authorities → Import

**Firefox:** Settings → Privacy & Security → Certificates → View Certificates → Authorities → Import

## Production Deployment

### Using Let's Encrypt

```bash
# Install certbot
sudo apt-get install certbot

# Obtain certificate
sudo certbot certonly --standalone -d yourdomain.com

# Update docker-compose.yml
services:
  example-service:
    environment:
      - TLS_CERT_FILE=/etc/letsencrypt/live/yourdomain.com/fullchain.pem
      - TLS_KEY_FILE=/etc/letsencrypt/live/yourdomain.com/privkey.pem
    volumes:
      - /etc/letsencrypt:/etc/letsencrypt:ro
```

### Using Kubernetes

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: tls-certs
type: kubernetes.io/tls
data:
  tls.crt: <base64-encoded-cert>
  tls.key: <base64-encoded-key>

---
apiVersion: apps/v1
kind: Deployment
spec:
  template:
    spec:
      containers:
      - name: example-service
        env:
        - name: USE_TLS
          value: "true"
        - name: TLS_CERT_FILE
          value: "/etc/tls/tls.crt"
        - name: TLS_KEY_FILE
          value: "/etc/tls/tls.key"
        volumeMounts:
        - name: tls-certs
          mountPath: /etc/tls
          readOnly: true
      volumes:
      - name: tls-certs
        secret:
          secretName: tls-certs
```

## Next Steps

- [ ] Set up certificate monitoring and alerting
- [ ] Implement certificate auto-renewal
- [ ] Enable mTLS for all service-to-service communication
- [ ] Add certificate pinning for mobile clients
- [ ] Configure certificate revocation checking (OCSP)
