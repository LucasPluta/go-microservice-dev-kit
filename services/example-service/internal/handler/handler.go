package handler

import (
	"context"
	"time"

	"github.com/LucasPluta/GoMicroserviceFramework/services/example-service/internal/service"
	pb "github.com/LucasPluta/GoMicroserviceFramework/services/example-service/proto"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

type Handler struct {
	pb.UnimplementedExampleServiceServiceServer
	svc *service.Service
}

func NewHandler(svc *service.Service) *Handler {
	return &Handler{
		svc: svc,
	}
}

// GetStatus implements the unary RPC method
func (h *Handler) GetStatus(ctx context.Context, req *pb.GetStatusRequest) (*pb.GetStatusResponse, error) {
	if req.ServiceId == "" {
		return nil, status.Error(codes.InvalidArgument, "service_id is required")
	}

	// Call service layer
	statusMsg := h.svc.GetServiceStatus(req.ServiceId)

	return &pb.GetStatusResponse{
		Status:  "healthy",
		Message: statusMsg,
	}, nil
}

// StreamData implements the server-side streaming RPC method
func (h *Handler) StreamData(req *pb.StreamDataRequest, stream pb.ExampleServiceService_StreamDataServer) error {
	if req.Limit <= 0 {
		req.Limit = 10 // Default limit
	}

	// Stream data to client
	for i := int32(0); i < req.Limit; i++ {
		data := h.svc.GenerateData(req.Filter, i)

		resp := &pb.StreamDataResponse{
			Data:      data,
			Timestamp: time.Now().Unix(),
		}

		if err := stream.Send(resp); err != nil {
			return status.Errorf(codes.Internal, "failed to send data: %v", err)
		}

		// Simulate some processing time
		time.Sleep(100 * time.Millisecond)
	}

	return nil
}
