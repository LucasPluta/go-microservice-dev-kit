package grpc

import (
	"crypto/tls"
	"crypto/x509"
	"fmt"
	"os"

	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials"
)

// TLSConfig holds the configuration for TLS connections
type TLSConfig struct {
	CertFile   string // Path to the server certificate file
	KeyFile    string // Path to the server private key file
	CAFile     string // Path to the CA certificate file (optional, for mTLS)
	ClientAuth bool   // Whether to require client certificate authentication (mTLS)
}

// GetSecureCipherSuites returns a list of secure cipher suites
// Based on Mozilla's "Modern" configuration recommendations
func GetSecureCipherSuites() []uint16 {
	return []uint16{
		tls.TLS_AES_128_GCM_SHA256,
		tls.TLS_AES_256_GCM_SHA384,
		tls.TLS_CHACHA20_POLY1305_SHA256,
		// Fallback for older clients (still secure)
		tls.TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256,
		tls.TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256,
		tls.TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384,
		tls.TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384,
		tls.TLS_ECDHE_ECDSA_WITH_CHACHA20_POLY1305_SHA256,
		tls.TLS_ECDHE_RSA_WITH_CHACHA20_POLY1305_SHA256,
	}
}

// NewServerTLSConfig creates a secure TLS configuration for the server
func NewServerTLSConfig(config TLSConfig) (*tls.Config, error) {
	// Load server certificate and key
	cert, err := tls.LoadX509KeyPair(config.CertFile, config.KeyFile)
	if err != nil {
		return nil, fmt.Errorf("failed to load server certificate: %w", err)
	}

	tlsConfig := &tls.Config{
		Certificates: []tls.Certificate{cert},
		MinVersion:   tls.VersionTLS12, // Require TLS 1.2 or higher
		CipherSuites: GetSecureCipherSuites(),
		// Prefer server's cipher suite order
		PreferServerCipherSuites: true,
		// Use modern curve preferences
		CurvePreferences: []tls.CurveID{
			tls.X25519,
			tls.CurveP256,
			tls.CurveP384,
		},
	}

	// Configure mutual TLS (mTLS) if requested
	if config.ClientAuth && config.CAFile != "" {
		caCert, err := os.ReadFile(config.CAFile)
		if err != nil {
			return nil, fmt.Errorf("failed to read CA certificate: %w", err)
		}

		caCertPool := x509.NewCertPool()
		if !caCertPool.AppendCertsFromPEM(caCert) {
			return nil, fmt.Errorf("failed to append CA certificate")
		}

		tlsConfig.ClientCAs = caCertPool
		tlsConfig.ClientAuth = tls.RequireAndVerifyClientCert
	}

	return tlsConfig, nil
}

// NewSecureGRPCServer creates a gRPC server with TLS enabled
func NewSecureGRPCServer(tlsConfig TLSConfig) (*grpc.Server, error) {
	serverTLSConfig, err := NewServerTLSConfig(tlsConfig)
	if err != nil {
		return nil, err
	}

	creds := credentials.NewTLS(serverTLSConfig)

	opts := []grpc.ServerOption{
		grpc.Creds(creds),
		grpc.MaxRecvMsgSize(10 * 1024 * 1024), // 10MB
		grpc.MaxSendMsgSize(10 * 1024 * 1024), // 10MB
	}

	return grpc.NewServer(opts...), nil
}

// NewClientTLSConfig creates a secure TLS configuration for gRPC clients
func NewClientTLSConfig(caFile string, serverNameOverride string) (credentials.TransportCredentials, error) {
	if caFile == "" {
		// Use system CA pool
		return credentials.NewClientTLSFromCert(nil, serverNameOverride), nil
	}

	// Load CA certificate
	caCert, err := os.ReadFile(caFile)
	if err != nil {
		return nil, fmt.Errorf("failed to read CA certificate: %w", err)
	}

	caCertPool := x509.NewCertPool()
	if !caCertPool.AppendCertsFromPEM(caCert) {
		return nil, fmt.Errorf("failed to append CA certificate")
	}

	tlsConfig := &tls.Config{
		RootCAs:    caCertPool,
		MinVersion: tls.VersionTLS13,
		ServerName: serverNameOverride,
	}

	return credentials.NewTLS(tlsConfig), nil
}
