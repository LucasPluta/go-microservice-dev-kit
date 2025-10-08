package nats

import (
	"fmt"
	"log"

	"github.com/nats-io/nats.go"
)

type Config struct {
	URL string
}

// NewNATSConnection creates a new NATS connection
func NewNATSConnection(cfg Config) (*nats.Conn, error) {
	nc, err := nats.Connect(cfg.URL)
	if err != nil {
		return nil, fmt.Errorf("failed to connect to NATS: %w", err)
	}

	log.Println("Successfully connected to NATS")
	return nc, nil
}

// NewJetStreamContext creates a JetStream context for advanced messaging
func NewJetStreamContext(nc *nats.Conn) (nats.JetStreamContext, error) {
	js, err := nc.JetStream()
	if err != nil {
		return nil, fmt.Errorf("failed to create JetStream context: %w", err)
	}

	log.Println("Successfully created JetStream context")
	return js, nil
}
