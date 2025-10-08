.PHONY: proto build run clean

proto:
	protoc --go_out=. --go_opt=paths=source_relative \
		--go-grpc_out=. --go-grpc_opt=paths=source_relative \
		proto/user-service.proto

build:
	go build -o bin/user-service ./cmd/main.go

run:
	go run ./cmd/main.go

clean:
	rm -rf bin/
	rm -f proto/*.pb.go

test:
	go test -v ./...
