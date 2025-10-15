package grpc

import (
	"fmt"
	"log"
	"net/http"
	"strings"

	"golang.org/x/net/http2"
	"golang.org/x/net/http2/h2c"
	"google.golang.org/grpc"
	"google.golang.org/grpc/reflection"
)

// ConnectServerConfig holds configuration for the dual-protocol server
type ConnectServerConfig struct {
	GRPCServer     *grpc.Server
	ConnectHandler http.Handler
}

// NewConnectServer creates a server that supports both gRPC and Connect-RPC
func NewConnectServer() *grpc.Server {
	opts := []grpc.ServerOption{
		grpc.MaxRecvMsgSize(10 * 1024 * 1024), // 10MB
		grpc.MaxSendMsgSize(10 * 1024 * 1024), // 10MB
	}

	server := grpc.NewServer(opts...)

	// Enable reflection for tools like grpcurl
	reflection.Register(server)

	return server
}

// StartConnectServer starts a server that handles both gRPC and Connect-RPC protocols
// connectHandler should be the Connect-RPC handler (can be nil to only support gRPC)
func StartConnectServer(grpcServer *grpc.Server, connectHandler http.Handler, port string) error {
	// Create a handler that routes between gRPC and Connect-RPC
	handler := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		contentType := r.Header.Get("Content-Type")

		// Route to Connect handler if available and content type matches
		if connectHandler != nil &&
			(strings.Contains(contentType, "application/json") ||
				strings.Contains(contentType, "application/connect") ||
				strings.Contains(contentType, "application/proto")) {
			connectHandler.ServeHTTP(w, r)
			return
		}

		// Default to gRPC handler for application/grpc
		grpcServer.ServeHTTP(w, r)
	})

	// Wrap with h2c to support HTTP/2 without TLS
	h2cHandler := h2c.NewHandler(handler, &http2.Server{})

	addr := fmt.Sprintf(":%s", port)
	if connectHandler != nil {
		log.Printf("Dual-protocol server listening on %s (supports gRPC and Connect-RPC)", addr)
	} else {
		log.Printf("gRPC server listening on %s", addr)
	}

	if err := http.ListenAndServe(addr, h2cHandler); err != nil {
		return fmt.Errorf("failed to serve: %w", err)
	}

	return nil
}
