.PHONY: all
all: help

.PHONY: proto
proto: clean
	protoc --proto_path=proto \
	--proto_path=$(GRPC_GATEWAY_MOD) \
	--proto_path=$(GOOGLEAPIS_MOD) \
	--go_out=./pb --go_opt=paths=source_relative \
	--go-grpc_out=./pb --go-grpc_opt=paths=source_relative \
	--grpc-gateway_out=./pb --grpc-gateway_opt=paths=source_relative \
	--openapiv2_out=./pb \
	$(wildcard proto/*.proto)

.PHONY: dev
dev:
	@air

.PHONY: build
build:
	go build -o tmp/main ./cmd/server

.PHONY: run
run: build
	./tmp/main

.PHONY: test
test:
	go test ./...

# Cleanup targets
.PHONY: clean
clean:
	rm -f pb/*.go pb/*.json