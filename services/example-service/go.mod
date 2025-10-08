module example-service

go 1.21

require (
	github.com/LucasPluta/GoMicroserviceFramework v0.0.0
	github.com/go-redis/redis/v8 v8.11.5
	github.com/nats-io/nats.go v1.31.0
	google.golang.org/grpc v1.67.1
	google.golang.org/protobuf v1.34.2
)

require (
	github.com/cespare/xxhash/v2 v2.3.0 // indirect
	github.com/dgryski/go-rendezvous v0.0.0-20200823014737-9f7001d12a5f // indirect
	github.com/klauspost/compress v1.17.2 // indirect
	github.com/lib/pq v1.10.9 // indirect
	github.com/nats-io/nkeys v0.4.6 // indirect
	github.com/nats-io/nuid v1.0.1 // indirect
	golang.org/x/crypto v0.26.0 // indirect
	golang.org/x/net v0.28.0 // indirect
	golang.org/x/sys v0.24.0 // indirect
	golang.org/x/text v0.17.0 // indirect
	google.golang.org/genproto/googleapis/rpc v0.0.0-20240814211410-ddb44dafa142 // indirect
)

replace github.com/LucasPluta/GoMicroserviceFramework => ../../
