package service

import (
	"context"
	"database/sql"
	"fmt"
	"log"

	redisclient "github.com/go-redis/redis/v8"
	natslib "github.com/nats-io/nats.go"
)

type Service struct {
	ctx   context.Context
	db    *sql.DB
	redis *redisclient.Client
	nats  *natslib.Conn
}

func NewService(ctx context.Context, db *sql.DB, redis *redisclient.Client, nc *natslib.Conn) *Service {
	return &Service{
		ctx:   ctx,
		db:    db,
		redis: redis,
		nats:  nc,
	}
}

// GetServiceStatus returns the status of the service
func (s *Service) GetServiceStatus(serviceID string) string {
	msg := fmt.Sprintf("Service %s is running", serviceID)

	// Example: Check if PostgreSQL is available
	if s.db != nil {
		if err := s.db.Ping(); err != nil {
			msg += " (PostgreSQL: error)"
			log.Printf("PostgreSQL ping failed: %v", err)
		} else {
			msg += " (PostgreSQL: connected)"
		}
	}

	// Example: Check if Redis is available
	if s.redis != nil {
		if err := s.redis.Ping(s.ctx).Err(); err != nil {
			msg += " (Redis: error)"
			log.Printf("Redis ping failed: %v", err)
		} else {
			msg += " (Redis: connected)"
		}
	}

	// Example: Check if NATS is available
	if s.nats != nil {
		if s.nats.IsConnected() {
			msg += " (NATS: connected)"
		} else {
			msg += " (NATS: disconnected)"
		}
	}

	return msg
}

// GenerateData generates sample data for streaming
func (s *Service) GenerateData(filter string, index int32) string {
	data := fmt.Sprintf("Item %d", index)

	if filter != "" {
		data = fmt.Sprintf("%s (filtered by: %s)", data, filter)
	}

	// Example: Store data in Redis if available
	if s.redis != nil {
		key := fmt.Sprintf("stream:data:%d", index)
		if err := s.redis.Set(s.ctx, key, data, 0).Err(); err != nil {
			log.Printf("Failed to store data in Redis: %v", err)
		}
	}

	// Example: Publish to NATS if available
	if s.nats != nil {
		subject := "example.stream.data"
		if err := s.nats.Publish(subject, []byte(data)); err != nil {
			log.Printf("Failed to publish to NATS: %v", err)
		}
	}

	return data
}
