package handler

import (
	"github.com/LucasPluta/GoMicroserviceFramework/services/user-service/internal/service"
	pb "github.com/LucasPluta/GoMicroserviceFramework/services/user-service/proto"
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
