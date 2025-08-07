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

.PHONY: service
service:
	@if [ -z "$(name)" ]; then \
		echo "Usage: make service name=YourService"; \
		exit 1; \
	fi; \
	service_name=$$(echo $(name) | awk '{print toupper(substr($$0,1,1)) tolower(substr($$0,2))}'); \
	service_name_lc=$$(echo $(name) | tr '[:upper:]' '[:lower:]'); \
	proto_file=proto/$${service_name_lc}.proto; \
	echo 'syntax = "proto3";' > $$proto_file; \
	echo '' >> $$proto_file; \
	echo 'package pb;' >> $$proto_file; \
	echo '' >> $$proto_file; \
	echo 'import "google/api/annotations.proto";' >> $$proto_file; \
	echo 'option go_package = "grpc_anotation_sample/pb";' >> $$proto_file; \
	echo '' >> $$proto_file; \
	echo "message $${service_name} {" >> $$proto_file; \
	echo '  string id = 1;' >> $$proto_file; \
	echo '  string name = 2;' >> $$proto_file; \
	echo '}' >> $$proto_file; \
	echo '' >> $$proto_file; \
	echo "message Create$${service_name}Request { $${service_name} data = 1; }" >> $$proto_file; \
	echo "message Create$${service_name}Response { $${service_name} data = 1; }" >> $$proto_file; \
	echo "message Get$${service_name}Request { string id = 1; }" >> $$proto_file; \
	echo "message Get$${service_name}Response { $${service_name} data = 1; }" >> $$proto_file; \
	echo "message Update$${service_name}Request { $${service_name} data = 1; }" >> $$proto_file; \
	echo "message Update$${service_name}Response { $${service_name} data = 1; }" >> $$proto_file; \
	echo "message Delete$${service_name}Request { string id = 1; }" >> $$proto_file; \
	echo "message Delete$${service_name}Response { bool success = 1; }" >> $$proto_file; \
	echo "message List$${service_name}sRequest {}" >> $$proto_file; \
	echo "message List$${service_name}sResponse { repeated $${service_name} data = 1; }" >> $$proto_file; \
	echo '' >> $$proto_file; \
	echo "service $${service_name}Service {" >> $$proto_file; \
	echo "  rpc Create$${service_name}(Create$${service_name}Request) returns (Create$${service_name}Response) {" >> $$proto_file; \
	echo "    option (google.api.http) = { post: \"/v1/$${service_name_lc}s\" body: \"*\" };" >> $$proto_file; \
	echo "  }" >> $$proto_file; \
	echo "  rpc Get$${service_name}(Get$${service_name}Request) returns (Get$${service_name}Response) {" >> $$proto_file; \
	echo "    option (google.api.http) = { get: \"/v1/$${service_name_lc}s/{id}\" };" >> $$proto_file; \
	echo "  }" >> $$proto_file; \
	echo "  rpc Update$${service_name}(Update$${service_name}Request) returns (Update$${service_name}Response) {" >> $$proto_file; \
	echo "    option (google.api.http) = { put: \"/v1/$${service_name_lc}s/{data.id}\" body: \"*\" };" >> $$proto_file; \
	echo "  }" >> $$proto_file; \
	echo "  rpc Delete$${service_name}(Delete$${service_name}Request) returns (Delete$${service_name}Response) {" >> $$proto_file; \
	echo "    option (google.api.http) = { delete: \"/v1/$${service_name_lc}s/{id}\" };" >> $$proto_file; \
	echo "  }" >> $$proto_file; \
	echo "  rpc List$${service_name}s(List$${service_name}sRequest) returns (List$${service_name}sResponse) {" >> $$proto_file; \
	echo "    option (google.api.http) = { get: \"/v1/$${service_name_lc}s\" };" >> $$proto_file; \
	echo "  }" >> $$proto_file; \
	echo "}" >> $$proto_file; \
	echo "Created service proto: $$proto_file"; \
	echo "Don't forget to run: make proto"; \
	echo "Implement the service in services/ and register in server/grpc.go and server/gateway.go"
# Cleanup targets
.PHONY: clean
clean:
	rm -f pb/*.go pb/*.json