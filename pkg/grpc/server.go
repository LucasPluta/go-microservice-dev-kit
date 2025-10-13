package grpc

import (
	"fmt"
	"log"
	"net"

	"google.golang.org/grpc"
	"google.golang.org/grpc/reflection"
)

// ServerConfig holds gRPC server configuration
type ServerConfig struct {
	Port string
}

// NewServer creates and configures a new gRPC server
func NewServer() *grpc.Server {
	opts := []grpc.ServerOption{
		grpc.MaxRecvMsgSize(10 * 1024 * 1024), // 10MB
		grpc.MaxSendMsgSize(10 * 1024 * 1024), // 10MB
	}
	
	server := grpc.NewServer(opts...)
	
	// Enable reflection for tools like grpcurl
	reflection.Register(server)
	
	return server
}

// StartServer starts the gRPC server on the specified port
func StartServer(server *grpc.Server, port string) error {
	lis, err := net.Listen("tcp", fmt.Sprintf(":%s", port))
	if err != nil {
		return fmt.Errorf("failed to listen on port %s: %w", port, err)
	}

	log.Printf("gRPC server listening on port %s", port)
	
	if err := server.Serve(lis); err != nil {
		return fmt.Errorf("failed to serve: %w", err)
	}

	return nil
}
