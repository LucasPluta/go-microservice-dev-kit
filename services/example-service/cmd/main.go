package main

import (
	"context"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"

	"database/sql"

	"github.com/LucasPluta/GoMicroserviceFramework/pkg/database"
	grpcpkg "github.com/LucasPluta/GoMicroserviceFramework/pkg/grpc"
	"github.com/LucasPluta/GoMicroserviceFramework/pkg/nats"
	"github.com/LucasPluta/GoMicroserviceFramework/pkg/redis"
	"github.com/LucasPluta/GoMicroserviceFramework/services/example-service/internal/handler"
	"github.com/LucasPluta/GoMicroserviceFramework/services/example-service/internal/service"
	pb "github.com/LucasPluta/GoMicroserviceFramework/services/example-service/proto"
	redisclient "github.com/go-redis/redis/v8"
	natslib "github.com/nats-io/nats.go"
)

func main() {
	log.Println("Starting example-service...")

	// Get configuration from environment
	serviceName := getEnv("SERVICE_NAME", "example-service")
	grpcPort := getEnv("GRPC_PORT", "50051")

	log.Printf("Service: %s", serviceName)
	log.Printf("gRPC Port: %s", grpcPort)

	ctx := context.Background()

	// Initialize PostgreSQL connection if enabled
	var db *sql.DB
	if getEnv("USE_POSTGRES", "false") == "true" {
		dbConfig := database.Config{
			Host:     getEnv("POSTGRES_HOST", "localhost"),
			Port:     getEnv("POSTGRES_PORT", "5432"),
			User:     getEnv("POSTGRES_USER", "postgres"),
			Password: getEnv("POSTGRES_PASSWORD", "postgres"),
			DBName:   getEnv("POSTGRES_DB", "microservices"),
		}
		var err error
		db, err = database.NewPostgresConnection(dbConfig)
		if err != nil {
			log.Fatalf("Failed to connect to PostgreSQL: %v", err)
		}
		defer db.Close()
	}

	// Initialize Redis connection if enabled
	var redisClient *redisclient.Client
	if getEnv("USE_REDIS", "false") == "true" {
		redisConfig := redis.Config{
			Host: getEnv("REDIS_HOST", "localhost"),
			Port: getEnv("REDIS_PORT", "6379"),
		}
		var err error
		redisClient, err = redis.NewRedisClient(redisConfig)
		if err != nil {
			log.Fatalf("Failed to connect to Redis: %v", err)
		}
		defer redisClient.Close()
	}

	// Initialize NATS connection if enabled
	var nc *natslib.Conn
	if getEnv("USE_NATS", "false") == "true" {
		natsConfig := nats.Config{
			URL: getEnv("NATS_URL", "nats://localhost:4222"),
		}
		var err error
		nc, err = nats.NewNATSConnection(natsConfig)
		if err != nil {
			log.Fatalf("Failed to connect to NATS: %v", err)
		}
		defer nc.Close()
	}

	// Initialize service
	svc := service.NewService(ctx, db, redisClient, nc)

	// Create handlers
	h := handler.NewHandler(svc)

	// Create gRPC server
	grpcServer := grpcpkg.NewConnectServer()
	pb.RegisterExampleServiceServiceServer(grpcServer, h)

	// Create Connect-RPC handlers
	connectMux := http.NewServeMux()
	handler.RegisterConnectHandlers(connectMux, h)

	// Start server in a goroutine (supports both gRPC and Connect-RPC)
	go func() {
		if err := grpcpkg.StartConnectServer(grpcServer, connectMux, grpcPort); err != nil {
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
