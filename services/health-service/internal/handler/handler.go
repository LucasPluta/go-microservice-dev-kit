package handler

import (
	"health-service/internal/service"
	pb "health-service/proto"
)

type Handler struct {
	pb.UnimplementedHealthServiceServiceServer
	svc *service.Service
}

func NewHandler(svc *service.Service) *Handler {
	return &Handler{
		svc: svc,
	}
}

// Implement your gRPC methods here
