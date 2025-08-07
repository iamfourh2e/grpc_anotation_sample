#!/bin/bash

# Usage: ./gen_service.sh ServiceName "field1:type1,field2:type2,..."

set -e

if [ -z "$1" ] || [ -z "$2" ]; then
  echo "Usage: $0 ServiceName \"field1:type1,field2:type2,...\""
  exit 1
fi

SERVICE_NAME_RAW="$1"
FIELDS_RAW="$2"

# PascalCase for service name
SERVICE_NAME="$(echo "$SERVICE_NAME_RAW" | awk '{print toupper(substr($0,1,1)) tolower(substr($0,2))}')"
# lower_snake_case for file name
SERVICE_NAME_LC="$(echo "$SERVICE_NAME_RAW" | tr '[:upper:]' '[:lower:]')"
PROTO_FILE="proto/${SERVICE_NAME_LC}.proto"
GO_FILE="services/${SERVICE_NAME_LC}.go"

# Start proto file
echo 'syntax = "proto3";' > "$PROTO_FILE"
echo '' >> "$PROTO_FILE"
echo 'package pb;' >> "$PROTO_FILE"
echo '' >> "$PROTO_FILE"
echo 'import "google/api/annotations.proto";' >> "$PROTO_FILE"
echo 'option go_package = "grpc_anotation_sample/pb";' >> "$PROTO_FILE"
echo '' >> "$PROTO_FILE"

# Message fields
echo "message ${SERVICE_NAME} {" >> "$PROTO_FILE"
echo "  string id = 1;" >> "$PROTO_FILE"
FIELD_NUM=2
IFS=',' read -ra FIELDS <<< "$FIELDS_RAW"
for FIELD in "${FIELDS[@]}"; do
  NAME="$(echo $FIELD | cut -d: -f1 | xargs)"
  TYPE="$(echo $FIELD | cut -d: -f2 | xargs)"
  echo "  $TYPE $NAME = $FIELD_NUM;" >> "$PROTO_FILE"
  FIELD_NUM=$((FIELD_NUM+1))
done
echo "}" >> "$PROTO_FILE"
echo '' >> "$PROTO_FILE"

# CRUD messages
echo "message Create${SERVICE_NAME}Request { ${SERVICE_NAME} data = 1; }" >> "$PROTO_FILE"
echo "message Create${SERVICE_NAME}Response { ${SERVICE_NAME} data = 1; }" >> "$PROTO_FILE"
echo "message Get${SERVICE_NAME}Request { string id = 1; }" >> "$PROTO_FILE"
echo "message Get${SERVICE_NAME}Response { ${SERVICE_NAME} data = 1; }" >> "$PROTO_FILE"
echo "message Update${SERVICE_NAME}Request { ${SERVICE_NAME} data = 1; }" >> "$PROTO_FILE"
echo "message Update${SERVICE_NAME}Response { ${SERVICE_NAME} data = 1; }" >> "$PROTO_FILE"
echo "message Delete${SERVICE_NAME}Request { string id = 1; }" >> "$PROTO_FILE"
echo "message Delete${SERVICE_NAME}Response { bool success = 1; }" >> "$PROTO_FILE"
echo "message List${SERVICE_NAME}sRequest {}" >> "$PROTO_FILE"
echo "message List${SERVICE_NAME}sResponse { repeated ${SERVICE_NAME} data = 1; }" >> "$PROTO_FILE"
echo '' >> "$PROTO_FILE"

# Service definition
echo "service ${SERVICE_NAME}Service {" >> "$PROTO_FILE"
echo "  rpc Create${SERVICE_NAME}(Create${SERVICE_NAME}Request) returns (Create${SERVICE_NAME}Response) {" >> "$PROTO_FILE"
echo "    option (google.api.http) = { post: \"/v1/${SERVICE_NAME_LC}s\" body: \"*\" };" >> "$PROTO_FILE"
echo "  }" >> "$PROTO_FILE"
echo "  rpc Get${SERVICE_NAME}(Get${SERVICE_NAME}Request) returns (Get${SERVICE_NAME}Response) {" >> "$PROTO_FILE"
echo "    option (google.api.http) = { get: \"/v1/${SERVICE_NAME_LC}s/{id}\" };" >> "$PROTO_FILE"
echo "  }" >> "$PROTO_FILE"
echo "  rpc Update${SERVICE_NAME}(Update${SERVICE_NAME}Request) returns (Update${SERVICE_NAME}Response) {" >> "$PROTO_FILE"
echo "    option (google.api.http) = { put: \"/v1/${SERVICE_NAME_LC}s/{data.id}\" body: \"*\" };" >> "$PROTO_FILE"
echo "  }" >> "$PROTO_FILE"
echo "  rpc Delete${SERVICE_NAME}(Delete${SERVICE_NAME}Request) returns (Delete${SERVICE_NAME}Response) {" >> "$PROTO_FILE"
echo "    option (google.api.http) = { delete: \"/v1/${SERVICE_NAME_LC}s/{id}\" };" >> "$PROTO_FILE"
echo "  }" >> "$PROTO_FILE"
echo "  rpc List${SERVICE_NAME}s(List${SERVICE_NAME}sRequest) returns (List${SERVICE_NAME}sResponse) {" >> "$PROTO_FILE"
echo "    option (google.api.http) = { get: \"/v1/${SERVICE_NAME_LC}s\" };" >> "$PROTO_FILE"
echo "  }" >> "$PROTO_FILE"
echo "}" >> "$PROTO_FILE"
echo '' >> "$PROTO_FILE"
echo "Created service proto: $PROTO_FILE"

# Generate Go service stub
if [ ! -f "$GO_FILE" ]; then
cat > "$GO_FILE" <<EOF
package services

import (
	"context"
	"grpc_anotation_sample/pb"
)

type ${SERVICE_NAME}Service struct {
	pb.Unimplemented${SERVICE_NAME}ServiceServer
}

func New${SERVICE_NAME}Service() *${SERVICE_NAME}Service {
	return &${SERVICE_NAME}Service{}
}

func (s *${SERVICE_NAME}Service) Create${SERVICE_NAME}(ctx context.Context, req *pb.Create${SERVICE_NAME}Request) (*pb.Create${SERVICE_NAME}Response, error) {
	return &pb.Create${SERVICE_NAME}Response{}, nil
}

func (s *${SERVICE_NAME}Service) Get${SERVICE_NAME}(ctx context.Context, req *pb.Get${SERVICE_NAME}Request) (*pb.Get${SERVICE_NAME}Response, error) {
	return &pb.Get${SERVICE_NAME}Response{}, nil
}

func (s *${SERVICE_NAME}Service) Update${SERVICE_NAME}(ctx context.Context, req *pb.Update${SERVICE_NAME}Request) (*pb.Update${SERVICE_NAME}Response, error) {
	return &pb.Update${SERVICE_NAME}Response{}, nil
}

func (s *${SERVICE_NAME}Service) Delete${SERVICE_NAME}(ctx context.Context, req *pb.Delete${SERVICE_NAME}Request) (*pb.Delete${SERVICE_NAME}Response, error) {
	return &pb.Delete${SERVICE_NAME}Response{}, nil
}

func (s *${SERVICE_NAME}Service) List${SERVICE_NAME}s(ctx context.Context, req *pb.List${SERVICE_NAME}sRequest) (*pb.List${SERVICE_NAME}sResponse, error) {
	return &pb.List${SERVICE_NAME}sResponse{}, nil
}
EOF
  echo "Created Go service stub: $GO_FILE"
else
  echo "Go service stub already exists: $GO_FILE"
fi

# Register in server/grpc.go
GRPC_GO="server/grpc.go"
GRPC_REG="pb.Register${SERVICE_NAME}ServiceServer(grpcServer, services.New${SERVICE_NAME}Service())"
grep -q "$GRPC_REG" "$GRPC_GO" || \
  sed -i '' "/grpcServer := grpc.NewServer()/a\
    $GRPC_REG\
" "$GRPC_GO"

# Register in server/gateway.go
GATEWAY_GO="server/gateway.go"
GATEWAY_REG="pb.Register${SERVICE_NAME}ServiceHandler(ctx, mux, conn)"
grep -q "$GATEWAY_REG" "$GATEWAY_GO" || \
  sed -i '' "/mux, conn);/a\
    if err = $GATEWAY_REG; err != nil {\
        return err\
    }\
" "$GATEWAY_GO"

echo "Don't forget to run: make proto"
echo "Service registered in $GRPC_GO and $GATEWAY_GO"
echo "Implement your business logic in $GO_FILE" 