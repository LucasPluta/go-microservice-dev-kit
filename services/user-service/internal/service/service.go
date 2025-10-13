package service

import (
	"context"
	"database/sql"
	"github.com/go-redis/redis/v8"
)

type Service struct {
	ctx context.Context
	db  *sql.DB
	redis *redis.Client
}

func NewService(ctx context.Context, db *sql.DB, redis *redis.Client) *Service {
	return &Service{
		ctx: ctx,
		db:  db,
		redis: redis,
	}
}

// Add your business logic methods here
