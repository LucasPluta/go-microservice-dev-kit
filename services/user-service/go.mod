module user-service

go 1.21

require (
	github.com/LucasPluta/GoMicroserviceFramework v0.0.0
	google.golang.org/grpc v1.67.1
	google.golang.org/protobuf v1.34.2
	github.com/lib/pq v1.10.9
	github.com/go-redis/redis/v8 v8.11.5
)

replace github.com/LucasPluta/GoMicroserviceFramework => ../../
