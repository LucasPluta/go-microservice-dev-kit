#!/bin/bash
set -euo pipefail

# Script to generate TLS certificates for development
# In production, use proper certificates from a trusted CA (Let's Encrypt, etc.)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CERTS_DIR="$PROJECT_ROOT/certs"

# Source utilities
source "$SCRIPT_DIR/../util.sh"

# Create certs directory
mkdir -p "$CERTS_DIR"

lp-echo "Generating TLS certificates for development..."

# Certificate parameters
DAYS_VALID=365
COUNTRY="US"
STATE="CA"
CITY="San Francisco"
ORGANIZATION="GoMicroserviceFramework"
ORGANIZATIONAL_UNIT="Development"
COMMON_NAME="localhost"

# Generate CA private key
lp-echo "Generating CA private key..."
openssl genrsa -out "$CERTS_DIR/ca-key.pem" 4096

# Generate CA certificate
lp-echo "Generating CA certificate..."
openssl req -new -x509 -days $DAYS_VALID -key "$CERTS_DIR/ca-key.pem" \
    -sha256 -out "$CERTS_DIR/ca-cert.pem" \
    -subj "/C=$COUNTRY/ST=$STATE/L=$CITY/O=$ORGANIZATION/OU=$ORGANIZATIONAL_UNIT CA/CN=CA"

# Generate server private key
lp-echo "Generating server private key..."
openssl genrsa -out "$CERTS_DIR/server-key.pem" 4096

# Generate server certificate signing request
lp-echo "Generating server CSR..."
openssl req -new -key "$CERTS_DIR/server-key.pem" \
    -out "$CERTS_DIR/server.csr" \
    -subj "/C=$COUNTRY/ST=$STATE/L=$CITY/O=$ORGANIZATION/OU=$ORGANIZATIONAL_UNIT/CN=$COMMON_NAME"

# Create extensions file for SAN (Subject Alternative Names)
cat > "$CERTS_DIR/server-ext.cnf" << EOF
subjectAltName = @alt_names
extendedKeyUsage = serverAuth

[alt_names]
DNS.1 = localhost
DNS.2 = *.localhost
DNS.3 = example-service
DNS.4 = user-service
DNS.5 = health-service
IP.1 = 127.0.0.1
IP.2 = ::1
EOF

# Sign the server certificate with CA
lp-echo "Signing server certificate..."
openssl x509 -req -days $DAYS_VALID -in "$CERTS_DIR/server.csr" \
    -CA "$CERTS_DIR/ca-cert.pem" -CAkey "$CERTS_DIR/ca-key.pem" \
    -CAcreateserial -out "$CERTS_DIR/server-cert.pem" \
    -extfile "$CERTS_DIR/server-ext.cnf"

# Generate client private key (for mTLS if needed)
lp-echo "Generating client private key..."
openssl genrsa -out "$CERTS_DIR/client-key.pem" 4096

# Generate client certificate signing request
lp-echo "Generating client CSR..."
openssl req -new -key "$CERTS_DIR/client-key.pem" \
    -out "$CERTS_DIR/client.csr" \
    -subj "/C=$COUNTRY/ST=$STATE/L=$CITY/O=$ORGANIZATION/OU=$ORGANIZATIONAL_UNIT/CN=client"

# Sign the client certificate with CA
lp-echo "Signing client certificate..."
openssl x509 -req -days $DAYS_VALID -in "$CERTS_DIR/client.csr" \
    -CA "$CERTS_DIR/ca-cert.pem" -CAkey "$CERTS_DIR/ca-key.pem" \
    -CAcreateserial -out "$CERTS_DIR/client-cert.pem" \
    -sha256

# Set appropriate permissions
chmod 600 "$CERTS_DIR"/*-key.pem
chmod 644 "$CERTS_DIR"/*-cert.pem

# Clean up intermediate files
rm -f "$CERTS_DIR/server.csr" "$CERTS_DIR/client.csr" "$CERTS_DIR/server-ext.cnf"

lp-success "TLS certificates generated successfully!"
echo ""
echo "Certificate files created in: $CERTS_DIR"
echo "  - ca-cert.pem: Root CA certificate (trust this in clients)"
echo "  - ca-key.pem: Root CA private key"
echo "  - server-cert.pem: Server certificate"
echo "  - server-key.pem: Server private key"
echo "  - client-cert.pem: Client certificate (for mTLS)"
echo "  - client-key.pem: Client private key (for mTLS)"
echo ""
echo "To trust the CA certificate on macOS:"
echo "  sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain $CERTS_DIR/ca-cert.pem"
echo ""
echo "To trust the CA certificate on Linux:"
echo "  sudo cp $CERTS_DIR/ca-cert.pem /usr/local/share/ca-certificates/gomicroservices-ca.crt"
echo "  sudo update-ca-certificates"
echo ""
echo "⚠️  WARNING: These are self-signed certificates for DEVELOPMENT ONLY!"
echo "   Do NOT use these certificates in production!"
