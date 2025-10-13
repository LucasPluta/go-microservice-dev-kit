package main

import (
	"context"
	"log"
	"os"
	"os/signal"
	"syscall"

	"github.com/LucasPluta/GoMicroserviceFramework/pkg/grpc"
	"github.com/LucasPluta/GoMicroserviceFramework/services/health-service/internal/handler"
	"github.com/LucasPluta/GoMicroserviceFramework/services/health-service/internal/service"
	pb "github.com/LucasPluta/GoMicroserviceFramework/services/health-service/proto"
)

func main() {
	log.Println("Starting health-service...")

	// Get configuration from environment
	serviceName := getEnv("SERVICE_NAME", "health-service")
	grpcPort := getEnv("GRPC_PORT", "50051")

	log.Printf("Service: %s", serviceName)
	log.Printf("gRPC Port: %s", grpcPort)

	ctx := context.Background()

	// Initialize service
	svc := service.NewService(ctx)

	// Create gRPC server
	grpcServer := grpc.NewServer()
	pb.RegisterHealthServiceServiceServer(grpcServer, handler.NewHandler(svc))

	// Start server in a goroutine
	go func() {
		if err := grpc.StartServer(grpcServer, grpcPort); err != nil {
			log.Fatalf("Failed to start gRPC server: %v", err)
		}
	}()

	// Wait for interrupt signal to gracefully shutdown
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit

	log.Println("Shutting down server...")
	grpcServer.GracefulStop()
	log.Println("Server stopped")
}

func getEnv(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}
