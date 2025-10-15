package handler

import (
	"context"
	"net/http"

	"connectrpc.com/connect"
	pb "github.com/LucasPluta/GoMicroserviceFramework/services/example-service/proto"
	"google.golang.org/grpc/metadata"
)

// ConnectHandler wraps the gRPC handler for Connect-RPC protocol
type ConnectHandler struct {
	handler *Handler
}

// NewConnectHandler creates a new Connect-RPC handler
func NewConnectHandler(h *Handler) *ConnectHandler {
	return &ConnectHandler{
		handler: h,
	}
}

// GetStatus implements Connect-RPC GetStatus
func (ch *ConnectHandler) GetStatus(
	ctx context.Context,
	req *connect.Request[pb.GetStatusRequest],
) (*connect.Response[pb.GetStatusResponse], error) {
	// Call the underlying gRPC handler
	resp, err := ch.handler.GetStatus(ctx, req.Msg)
	if err != nil {
		return nil, err
	}

	return connect.NewResponse(resp), nil
}

// StreamData implements Connect-RPC server streaming
func (ch *ConnectHandler) StreamData(
	ctx context.Context,
	req *connect.Request[pb.StreamDataRequest],
	stream *connect.ServerStream[pb.StreamDataResponse],
) error {
	// Create a wrapper that implements the gRPC stream interface
	grpcStream := &connectStreamWrapper{
		stream: stream,
		ctx:    ctx,
	}

	// Call the underlying gRPC handler
	return ch.handler.StreamData(req.Msg, grpcStream)
}

// connectStreamWrapper adapts Connect stream to gRPC stream interface
type connectStreamWrapper struct {
	stream *connect.ServerStream[pb.StreamDataResponse]
	ctx    context.Context
}

func (w *connectStreamWrapper) Send(resp *pb.StreamDataResponse) error {
	return w.stream.Send(resp)
}

func (w *connectStreamWrapper) SetHeader(md metadata.MD) error {
	return nil
}

func (w *connectStreamWrapper) SendHeader(md metadata.MD) error {
	return nil
}

func (w *connectStreamWrapper) SetTrailer(md metadata.MD) {
}

func (w *connectStreamWrapper) Context() context.Context {
	return w.ctx
}

func (w *connectStreamWrapper) SendMsg(m interface{}) error {
	return w.stream.Send(m.(*pb.StreamDataResponse))
}

func (w *connectStreamWrapper) RecvMsg(m interface{}) error {
	return nil
}

// RegisterConnectHandlers registers the Connect-RPC handlers
func RegisterConnectHandlers(mux *http.ServeMux, h *Handler) {
	connectHandler := NewConnectHandler(h)

	// Register GetStatus
	getStatusHandler := connect.NewUnaryHandler(
		"/exampleservice.ExampleServiceService/GetStatus",
		connectHandler.GetStatus,
	)
	mux.Handle("/exampleservice.ExampleServiceService/GetStatus", getStatusHandler)

	// Register StreamData
	streamDataHandler := connect.NewServerStreamHandler(
		"/exampleservice.ExampleServiceService/StreamData",
		connectHandler.StreamData,
	)
	mux.Handle("/exampleservice.ExampleServiceService/StreamData", streamDataHandler)
}
