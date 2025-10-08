package handler

import (
	"user-service/internal/service"
	pb "user-service/proto"
)

type Handler struct {
	pb.UnimplementedUserServiceServiceServer
	svc *service.Service
}

func NewHandler(svc *service.Service) *Handler {
	return &Handler{
		svc: svc,
	}
}

// Implement your gRPC methods here
