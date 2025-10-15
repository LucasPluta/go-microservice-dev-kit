# TLS Quick Reference

## Quick Commands

```bash
# Generate certificates
./scripts/setup/generate-certs.sh

# Full TLS setup (generate, build, deploy)
./setup-tls.sh

# Or use Make
make generate-certs
make setup-tls

# Trust CA (macOS)
sudo security add-trusted-cert -d -r trustRoot \
  -k /Library/Keychains/System.keychain certs/ca-cert.pem

# Trust CA (Linux)
sudo cp certs/ca-cert.pem /usr/local/share/ca-certificates/gomicroservices-ca.crt
sudo update-ca-certificates
```

## Service Endpoints

| Service | Endpoint | Protocol |
|---------|----------|----------|
| Web Client | https://localhost:8443 | HTTPS |
| gRPC Service | localhost:50051 | gRPC/TLS |
| API Proxy | https://localhost:8443/api | HTTPS |

## Testing

```bash
# Test gRPC with TLS
grpcurl -cacert certs/ca-cert.pem \
  -d '{"service_id": "test"}' \
  localhost:50051 \
  exampleservice.ExampleServiceService/GetStatus

# Test HTTPS web client
curl --cacert certs/ca-cert.pem https://localhost:8443

# Test with browser (after trusting CA)
open https://localhost:8443
```

## Configuration

### Enable TLS (Default)
```yaml
environment:
  - USE_TLS=true
  - TLS_CERT_FILE=/certs/server-cert.pem
  - TLS_KEY_FILE=/certs/server-key.pem
  - TLS_CA_FILE=/certs/ca-cert.pem
```

### Enable mTLS
```yaml
environment:
  - USE_TLS=true
  - TLS_REQUIRE_CLIENT_AUTH=true
```

### Disable TLS
```yaml
environment:
  - USE_TLS=false
```

## Cipher Suites

**TLS 1.3 (Preferred):**
- TLS_AES_128_GCM_SHA256
- TLS_AES_256_GCM_SHA384
- TLS_CHACHA20_POLY1305_SHA256

**TLS 1.2 (Fallback):**
- TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256
- TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256
- TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384
- TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384
- TLS_ECDHE_ECDSA_WITH_CHACHA20_POLY1305_SHA256
- TLS_ECDHE_RSA_WITH_CHACHA20_POLY1305_SHA256

## Certificate Files

```
certs/
├── ca-cert.pem          # CA certificate (trust this)
├── ca-key.pem           # CA private key
├── server-cert.pem      # Server certificate
├── server-key.pem       # Server private key
├── client-cert.pem      # Client certificate (mTLS)
└── client-key.pem       # Client private key (mTLS)
```

## Code Examples

### Server Configuration
```go
import "github.com/LucasPluta/GoMicroserviceFramework/pkg/grpc"

tlsConfig := grpcpkg.TLSConfig{
    CertFile:   "/certs/server-cert.pem",
    KeyFile:    "/certs/server-key.pem",
    CAFile:     "/certs/ca-cert.pem",
    ClientAuth: false, // true for mTLS
}

server, err := grpcpkg.NewSecureConnectServer(tlsConfig)
```

### Start Server
```go
err := grpcpkg.StartSecureConnectServer(
    grpcServer, 
    connectMux, 
    tlsConfig, 
    "50051",
)
```

### Client Configuration
```go
creds, err := grpcpkg.NewClientTLSConfig(
    "certs/ca-cert.pem", 
    "localhost",
)
conn, err := grpc.Dial(
    "localhost:50051", 
    grpc.WithTransportCredentials(creds),
)
```

## Troubleshooting

### Certificate Not Trusted
```bash
# Check if CA is trusted (macOS)
security find-certificate -a -c "GoMicroserviceFramework" | grep "GoMicroserviceFramework"

# Verify certificate
openssl x509 -in certs/server-cert.pem -text -noout

# Test TLS connection
openssl s_client -connect localhost:50051 -CAfile certs/ca-cert.pem
```

### Regenerate Certificates
```bash
rm -rf certs/
./scripts/setup/generate-certs.sh
make build
docker-compose build
docker-compose up -d
```

## Security Checklist

- [ ] Generate TLS certificates
- [ ] Trust CA certificate on dev machines
- [ ] Import CA certificate in browsers
- [ ] Verify TLS is enabled (USE_TLS=true)
- [ ] Test gRPC with TLS
- [ ] Test web client with HTTPS
- [ ] Never commit private keys to git
- [ ] Use trusted CA certificates in production
- [ ] Enable mTLS for production
- [ ] Monitor certificate expiration

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| USE_TLS | true | Enable/disable TLS |
| TLS_CERT_FILE | /certs/server-cert.pem | Server certificate path |
| TLS_KEY_FILE | /certs/server-key.pem | Server private key path |
| TLS_CA_FILE | /certs/ca-cert.pem | CA certificate path |
| TLS_REQUIRE_CLIENT_AUTH | false | Require client certificates |

## Production Notes

⚠️ **Self-signed certificates are for DEVELOPMENT ONLY!**

For production:
1. Use Let's Encrypt or enterprise CA
2. Enable mTLS
3. Monitor certificate expiration
4. Automate certificate renewal
5. Store private keys in secrets management
6. Use separate certificates per environment

## More Information

- **TLS_SECURITY.md** - Full documentation
- **TLS_IMPLEMENTATION_SUMMARY.md** - Implementation details
