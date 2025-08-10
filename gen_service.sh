#!/bin/bash

# Usage: ./gen_service.sh ServiceName "field1:type1,field2:type2,..."
#        ./gen_service.sh remove ServiceName

set -e

# Determine module path from go.mod
MODULE_PATH="$(awk '/^module /{print $2}' go.mod 2>/dev/null)"
if [ -z "$MODULE_PATH" ]; then
  echo "Error: Could not read module path from go.mod. Please run this script in the repository root." >&2
  exit 1
fi

# Helper function to pluralize service names
pluralize() {
  local word="$1"
  local last_char="${word: -1}"
  local second_last_char="${word: -2:1}"
  
  # Handle special cases
  case "$word" in
    Story) echo "Stories" ;;
    Category) echo "Categories" ;;
    Country) echo "Countries" ;;
    City) echo "Cities" ;;
    Family) echo "Families" ;;
    Company) echo "Companies" ;;
    Baby) echo "Babies" ;;
    Lady) echo "Ladies" ;;
    Party) echo "Parties" ;;
    Study) echo "Studies" ;;
    Theory) echo "Theories" ;;
    History) echo "Histories" ;;
    Mystery) echo "Mysteries" ;;
    Discovery) echo "Discoveries" ;;
    Library) echo "Libraries" ;;
    Factory) echo "Factories" ;;
    Memory) echo "Memories" ;;
    Victory) echo "Victories" ;;
    Century) echo "Centuries" ;;
    Gallery) echo "Galleries" ;;
    Salary) echo "Salaries" ;;
    Boundary) echo "Boundaries" ;;
    Commentary) echo "Commentaries" ;;
    Dictionary) echo "Dictionaries" ;;
    Laboratory) echo "Laboratories" ;;
    Necessary) echo "Necessaries" ;;
    Primary) echo "Primaries" ;;
    Secondary) echo "Secondaries" ;;
    Temporary) echo "Temporaries" ;;
    Voluntary) echo "Voluntaries" ;;
    # Words ending in 'y' preceded by a consonant -> 'ies'
    *y)
      if [[ ! "$second_last_char" =~ [aeiou] ]]; then
        echo "${word%y}ies"
      else
        echo "${word}s"
      fi
      ;;
    # Words ending in 's', 'sh', 'ch', 'x', 'z' -> 'es'
    *s|*sh|*ch|*x|*z)
      echo "${word}es"
      ;;
    # Words ending in 'f' or 'fe' -> 'ves' (common cases)
    *f)
      case "$word" in
        Leaf|Life|Knife|Wolf|Calf|Half|Self|Shelf|Thief|Wife)
          echo "${word%f}ves"
          ;;
        *)
          echo "${word}s"
          ;;
      esac
      ;;
    *fe)
      case "$word" in
        Life|Knife|Wife)
          echo "${word%fe}ves"
          ;;
        *)
          echo "${word}s"
          ;;
      esac
      ;;
    # Default: just add 's'
    *)
      echo "${word}s"
      ;;
  esac
}

if [ "$1" = "remove" ]; then
  if [ -z "$2" ]; then
    echo "Usage: $0 remove ServiceName"
    exit 1
  fi
  SERVICE_NAME_RAW="$2"
  SERVICE_NAME="$(echo "$SERVICE_NAME_RAW" | awk '{print toupper(substr($0,1,1)) tolower(substr($0,2))}')"
  SERVICE_NAME_LC="$(echo "$SERVICE_NAME_RAW" | tr '[:upper:]' '[:lower:]')"
  PROTO_FILE="proto/${SERVICE_NAME_LC}.proto"
  GO_FILE="services/${SERVICE_NAME_LC}.go"
  GRPC_GO="server/grpc.go"
  GATEWAY_GO="server/gateway.go"
  GRPC_REG="pb.Register${SERVICE_NAME}ServiceServer(grpcServer, services.New${SERVICE_NAME}Service())"
  GATEWAY_REG="pb.Register${SERVICE_NAME}ServiceHandler(ctx, mux, conn)"

  # Remove proto file
  if [ -f "$PROTO_FILE" ]; then
    rm "$PROTO_FILE"
    echo "Removed proto file: $PROTO_FILE"
  else
    echo "Proto file not found: $PROTO_FILE"
  fi

  # Remove Go service file
  if [ -f "$GO_FILE" ]; then
    rm "$GO_FILE"
    echo "Removed Go service file: $GO_FILE"
  else
    echo "Go service file not found: $GO_FILE"
  fi

  # Remove model file
  MODEL_FILE="models/${SERVICE_NAME_LC}.go"
  if [ -f "$MODEL_FILE" ]; then
    rm "$MODEL_FILE"
    echo "Removed model file: $MODEL_FILE"
  else
    echo "Model file not found: $MODEL_FILE"
  fi

  # Remove registration from grpc.go
  GRPC_REG_REGEX="pb\\.Register${SERVICE_NAME}ServiceServer\\(grpcServer,[[:space:]]*services\\.New${SERVICE_NAME}Service\\([^)]*\\)\\)"
  if grep -E -q "$GRPC_REG_REGEX" "$GRPC_GO"; then
    sed -E -i '' "/$GRPC_REG_REGEX/d" "$GRPC_GO"
    echo "Removed gRPC registration from $GRPC_GO"
  else
    echo "gRPC registration not found in $GRPC_GO"
  fi

  # Remove registration from gateway.go
  if grep -q "$GATEWAY_REG" "$GATEWAY_GO"; then
    # Remove the entire if block for this registration
    sed -i '' "/if err = $GATEWAY_REG; err != nil {/,/}/d" "$GATEWAY_GO"
    echo "Removed gateway registration from $GATEWAY_GO"
  else
    echo "Gateway registration not found in $GATEWAY_GO"
  fi

  echo "Service $SERVICE_NAME removed."
  exit 0
fi

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
# Properly pluralized service name for routes and collection names
SERVICE_NAME_PLURAL="$(pluralize "$SERVICE_NAME")"
SERVICE_NAME_LC_PLURAL="$(echo "$SERVICE_NAME_PLURAL" | tr '[:upper:]' '[:lower:]')"
PROTO_FILE="proto/${SERVICE_NAME_LC}.proto"
GO_FILE="services/${SERVICE_NAME_LC}.go"

# Helper to normalize field types
normalize_type() {
  local t="$1"
  local tlc="$(echo "$t" | tr '[:upper:]' '[:lower:]')"
  case "$tlc" in
    string|bool|bytes|int32|int64|sint32|sint64|uint32|uint64|fixed32|fixed64|sfixed32|sfixed64|float|double)
      echo "$tlc"
      return 0
      ;;
    timestamp)
      echo "google.protobuf.Timestamp"
      return 0
      ;;
  esac
  # If already fully qualified google.protobuf.Timestamp (any case), standardize casing
  local tlc_lower="$(echo "$t" | tr '[:upper:]' '[:lower:]')"
  if [ "$tlc_lower" = "google.protobuf.timestamp" ]; then
    echo "google.protobuf.Timestamp"
    return 0
  fi
  # Custom message type: ensure PascalCase first letter
  local first="$(echo "${t:0:1}" | tr '[:lower:]' '[:upper:]')"
  echo "${first}${t:1}"
}

# Helper to convert snake_case to camelCase
snake_to_camel() {
  local input="$1"
  local result=""
  local next_upper=false
  
  for ((i=0; i<${#input}; i++)); do
    local char="${input:$i:1}"
    if [ "$char" = "_" ]; then
      next_upper=true
    else
      if [ "$next_upper" = true ]; then
        result+="$(echo "$char" | tr '[:lower:]' '[:upper:]')"
        next_upper=false
      else
        result+="$char"
      fi
    fi
  done
  
  echo "$result"
}

# Pre-process fields to decide imports and build message body
TIMESTAMP_USED=0
FIELD_LINES="  string id = 1;\n"
FIELD_NUM=2
IFS=',' read -ra FIELDS <<< "$FIELDS_RAW"
for FIELD in "${FIELDS[@]}"; do
  RAW_TRIMMED="$(echo "$FIELD" | xargs)"
  [ -z "$RAW_TRIMMED" ] && continue

  NAME=""
  TYPE_RAW=""
  IS_REPEATED=0

  if [[ "$RAW_TRIMMED" == *:* ]]; then
    NAME="$(echo "$RAW_TRIMMED" | cut -d: -f1 | xargs)"
    TYPE_RAW="$(echo "$RAW_TRIMMED" | cut -d: -f2- | xargs)"
    # allow 'repeated <type>' after colon
    case "$TYPE_RAW" in
      repeated\ *)
        IS_REPEATED=1
        TYPE_RAW="${TYPE_RAW#repeated }"
        ;;
      Repeated\ *)
        IS_REPEATED=1
        TYPE_RAW="${TYPE_RAW#Repeated }"
        ;;
    esac
  else
    # accept 'repeated <type> <name>'
    if [[ "$RAW_TRIMMED" =~ ^[Rr]epeated[[:space:]]+([^[:space:]]+)[[:space:]]+([a-z][A-Za-z0-9_]*)$ ]]; then
      IS_REPEATED=1
      TYPE_RAW="${BASH_REMATCH[1]}"
      NAME="${BASH_REMATCH[2]}"
    else
      echo "Invalid field format: '$RAW_TRIMMED'. Use 'name:type' or 'repeated type name'" >&2
      exit 1
    fi
  fi

  TYPE_NORM="$(normalize_type "$TYPE_RAW")"
  if [ "$TYPE_NORM" = "google.protobuf.Timestamp" ]; then
    TIMESTAMP_USED=1
  fi

  if [ $IS_REPEATED -eq 1 ]; then
    FIELD_LINES+="  repeated ${TYPE_NORM} ${NAME} = ${FIELD_NUM};\n"
  else
    FIELD_LINES+="  ${TYPE_NORM} ${NAME} = ${FIELD_NUM};\n"
  fi
  FIELD_NUM=$((FIELD_NUM+1))
done

# Start proto file
echo 'syntax = "proto3";' > "$PROTO_FILE"
echo '' >> "$PROTO_FILE"
echo 'package pb;' >> "$PROTO_FILE"
echo '' >> "$PROTO_FILE"
echo 'import "google/api/annotations.proto";' >> "$PROTO_FILE"
if [ $TIMESTAMP_USED -eq 1 ]; then
  echo 'import "google/protobuf/timestamp.proto";' >> "$PROTO_FILE"
fi
echo "option go_package = \"${MODULE_PATH}/pb\";" >> "$PROTO_FILE"
echo '' >> "$PROTO_FILE"

# Message fields
echo "message ${SERVICE_NAME} {" >> "$PROTO_FILE"
echo -e "$FIELD_LINES" >> "$PROTO_FILE"
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
echo "message List${SERVICE_NAME_PLURAL}Request {}" >> "$PROTO_FILE"
echo "message List${SERVICE_NAME_PLURAL}Response { repeated ${SERVICE_NAME} data = 1; }" >> "$PROTO_FILE"
echo '' >> "$PROTO_FILE"

# Service definition
echo "service ${SERVICE_NAME}Service {" >> "$PROTO_FILE"
echo "  rpc Create${SERVICE_NAME}(Create${SERVICE_NAME}Request) returns (Create${SERVICE_NAME}Response) {" >> "$PROTO_FILE"
echo "    option (google.api.http) = { post: \"/v1/${SERVICE_NAME_LC_PLURAL}\" body: \"*\" };" >> "$PROTO_FILE"
echo "  }" >> "$PROTO_FILE"
echo "  rpc Get${SERVICE_NAME}(Get${SERVICE_NAME}Request) returns (Get${SERVICE_NAME}Response) {" >> "$PROTO_FILE"
echo "    option (google.api.http) = { get: \"/v1/${SERVICE_NAME_LC_PLURAL}/{id}\" };" >> "$PROTO_FILE"
echo "  }" >> "$PROTO_FILE"
echo "  rpc Update${SERVICE_NAME}(Update${SERVICE_NAME}Request) returns (Update${SERVICE_NAME}Response) {" >> "$PROTO_FILE"
echo "    option (google.api.http) = { put: \"/v1/${SERVICE_NAME_LC_PLURAL}/{data.id}\" body: \"*\" };" >> "$PROTO_FILE"
echo "  }" >> "$PROTO_FILE"
echo "  rpc Delete${SERVICE_NAME}(Delete${SERVICE_NAME}Request) returns (Delete${SERVICE_NAME}Response) {" >> "$PROTO_FILE"
echo "    option (google.api.http) = { delete: \"/v1/${SERVICE_NAME_LC_PLURAL}/{id}\" };" >> "$PROTO_FILE"
echo "  }" >> "$PROTO_FILE"
echo "  rpc List${SERVICE_NAME_PLURAL}(List${SERVICE_NAME_PLURAL}Request) returns (List${SERVICE_NAME_PLURAL}Response) {" >> "$PROTO_FILE"
echo "    option (google.api.http) = { get: \"/v1/${SERVICE_NAME_LC_PLURAL}\" };" >> "$PROTO_FILE"
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
	"${MODULE_PATH}/pb"
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

func (s *${SERVICE_NAME}Service) List${SERVICE_NAME_PLURAL}(ctx context.Context, req *pb.List${SERVICE_NAME_PLURAL}Request) (*pb.List${SERVICE_NAME_PLURAL}Response, error) {
	return &pb.List${SERVICE_NAME_PLURAL}Response{}, nil
}
EOF
  echo "Created Go service stub: $GO_FILE"
else
  echo "Go service stub already exists: $GO_FILE"
fi

# Generate model file
MODEL_FILE="models/${SERVICE_NAME_LC}.go"
if [ ! -f "$MODEL_FILE" ]; then
cat > "$MODEL_FILE" <<EOF
package models

import (
	"time"
	"go.mongodb.org/mongo-driver/bson/primitive"
	"${MODULE_PATH}/pb"
)

// ${SERVICE_NAME} represents the ${SERVICE_NAME_LC} entity in the database
type ${SERVICE_NAME} struct {
	ID        string    \`json:"id" bson:"_id"\`
EOF

# Add fields to model struct
FIELD_NUM=2
IFS=',' read -ra FIELDS <<< "$FIELDS_RAW"
for FIELD in "${FIELDS[@]}"; do
  RAW_TRIMMED="$(echo "$FIELD" | xargs)"
  [ -z "$RAW_TRIMMED" ] && continue

  NAME=""
  TYPE_RAW=""
  IS_REPEATED=0

  if [[ "$RAW_TRIMMED" == *:* ]]; then
    NAME="$(echo "$RAW_TRIMMED" | cut -d: -f1 | xargs)"
    TYPE_RAW="$(echo "$RAW_TRIMMED" | cut -d: -f2- | xargs)"
    case "$TYPE_RAW" in
      repeated\ *)
        IS_REPEATED=1
        TYPE_RAW="${TYPE_RAW#repeated }"
        ;;
      Repeated\ *)
        IS_REPEATED=1
        TYPE_RAW="${TYPE_RAW#Repeated }"
        ;;
    esac
  else
    if [[ "$RAW_TRIMMED" =~ ^[Rr]epeated[[:space:]]+([^[:space:]]+)[[:space:]]+([a-z][A-Za-z0-9_]*)$ ]]; then
      IS_REPEATED=1
      TYPE_RAW="${BASH_REMATCH[1]}"
      NAME="${BASH_REMATCH[2]}"
    fi
  fi

  TYPE_NORM="$(normalize_type "$TYPE_RAW")"
  
  # Map proto types to Go types
  GO_TYPE=""
  case "$TYPE_NORM" in
    string) GO_TYPE="string" ;;
    int32) GO_TYPE="int32" ;;
    int64) GO_TYPE="int64" ;;
    bool) GO_TYPE="bool" ;;
    float) GO_TYPE="float32" ;;
    double) GO_TYPE="float64" ;;
    bytes) GO_TYPE="[]byte" ;;
    google.protobuf.Timestamp) GO_TYPE="time.Time" ;;
    *) GO_TYPE="string" ;; # Default to string for custom types
  esac
  
  if [ $IS_REPEATED -eq 1 ]; then
    if [ "$GO_TYPE" = "string" ]; then
      GO_TYPE="[]string"
    else
      GO_TYPE="[]$GO_TYPE"
    fi
  fi
  
  # Convert snake_case to camelCase for Go struct field name
  FIELD_NAME="$(snake_to_camel "$NAME")"
  # Ensure first letter is uppercase for exported field (keep camelCase)
  FIELD_NAME="$(echo "$FIELD_NAME" | awk '{print toupper(substr($0,1,1)) substr($0,2)}')"
  echo "	${FIELD_NAME} ${GO_TYPE} \`json:\"${NAME}\" bson:\"${NAME}\"\`" >> "$MODEL_FILE"
done

cat >> "$MODEL_FILE" <<EOF
	CreatedAt time.Time \`json:"created_at" bson:"created_at"\`
	UpdatedAt time.Time \`json:"updated_at" bson:"updated_at"\`
}

// New${SERVICE_NAME} creates a new ${SERVICE_NAME} instance with default values
func New${SERVICE_NAME}() *${SERVICE_NAME} {
	return &${SERVICE_NAME}{
		ID:        primitive.NewObjectID().Hex(),
		CreatedAt: time.Now(),
		UpdatedAt: time.Now(),
	}
}

// ToProto converts the model to a protobuf message
func (m *${SERVICE_NAME}) ToProto() *pb.${SERVICE_NAME} {
	proto := &pb.${SERVICE_NAME}{
		Id: m.ID,
EOF

# Add field mappings for ToProto
FIELD_NUM=2
IFS=',' read -ra FIELDS <<< "$FIELDS_RAW"
for FIELD in "${FIELDS[@]}"; do
  RAW_TRIMMED="$(echo "$FIELD" | xargs)"
  [ -z "$RAW_TRIMMED" ] && continue

  NAME=""
  TYPE_RAW=""
  IS_REPEATED=0

  if [[ "$RAW_TRIMMED" == *:* ]]; then
    NAME="$(echo "$RAW_TRIMMED" | cut -d: -f1 | xargs)"
    TYPE_RAW="$(echo "$RAW_TRIMMED" | cut -d: -f2- | xargs)"
    case "$TYPE_RAW" in
      repeated\ *)
        IS_REPEATED=1
        TYPE_RAW="${TYPE_RAW#repeated }"
        ;;
      Repeated\ *)
        IS_REPEATED=1
        TYPE_RAW="${TYPE_RAW#Repeated }"
        ;;
    esac
  else
    if [[ "$RAW_TRIMMED" =~ ^[Rr]epeated[[:space:]]+([^[:space:]]+)[[:space:]]+([a-z][A-Za-z0-9_]*)$ ]]; then
      IS_REPEATED=1
      TYPE_RAW="${BASH_REMATCH[1]}"
      NAME="${BASH_REMATCH[2]}"
    fi
  fi

  TYPE_NORM="$(normalize_type "$TYPE_RAW")"
  
  # Generate field mapping
  if [ $IS_REPEATED -eq 1 ]; then
    FIELD_NAME="$(snake_to_camel "$NAME")"
    FIELD_NAME="$(echo "$FIELD_NAME" | awk '{print toupper(substr($0,1,1)) substr($0,2)}')"
    echo "		${FIELD_NAME}: m.${FIELD_NAME}," >> "$MODEL_FILE"
  else
    case "$TYPE_NORM" in
      google.protobuf.Timestamp)
        FIELD_NAME="$(snake_to_camel "$NAME")"
        FIELD_NAME="$(echo "$FIELD_NAME" | awk '{print toupper(substr($0,1,1)) substr($0,2)}')"
        echo "		${FIELD_NAME}: timestamppb.New(m.${FIELD_NAME})," >> "$MODEL_FILE"
        ;;
      *)
        FIELD_NAME="$(snake_to_camel "$NAME")"
        FIELD_NAME="$(echo "$FIELD_NAME" | awk '{print toupper(substr($0,1,1)) substr($0,2)}')"
        echo "		${FIELD_NAME}: m.${FIELD_NAME}," >> "$MODEL_FILE"
        ;;
    esac
  fi
done

cat >> "$MODEL_FILE" <<EOF
	}
	return proto
}

// FromProto creates a model from a protobuf message
func ${SERVICE_NAME}FromProto(p *pb.${SERVICE_NAME}) *${SERVICE_NAME} {
	if p == nil {
		return nil
	}
	
	m := &${SERVICE_NAME}{
		ID:        p.Id,
EOF

# Add field mappings for FromProto
FIELD_NUM=2
IFS=',' read -ra FIELDS <<< "$FIELDS_RAW"
for FIELD in "${FIELDS[@]}"; do
  RAW_TRIMMED="$(echo "$FIELD" | xargs)"
  [ -z "$RAW_TRIMMED" ] && continue

  NAME=""
  TYPE_RAW=""
  IS_REPEATED=0

  if [[ "$RAW_TRIMMED" == *:* ]]; then
    NAME="$(echo "$RAW_TRIMMED" | cut -d: -f1 | xargs)"
    TYPE_RAW="$(echo "$RAW_TRIMMED" | cut -d: -f2- | xargs)"
    case "$TYPE_RAW" in
      repeated\ *)
        IS_REPEATED=1
        TYPE_RAW="${TYPE_RAW#repeated }"
        ;;
      Repeated\ *)
        IS_REPEATED=1
        TYPE_RAW="${TYPE_RAW#Repeated }"
        ;;
    esac
  else
    if [[ "$RAW_TRIMMED" =~ ^[Rr]epeated[[:space:]]+([^[:space:]]+)[[:space:]]+([a-z][A-Za-z0-9_]*)$ ]]; then
      IS_REPEATED=1
      TYPE_RAW="${BASH_REMATCH[1]}"
      NAME="${BASH_REMATCH[2]}"
    fi
  fi

  TYPE_NORM="$(normalize_type "$TYPE_RAW")"
  
  # Generate field mapping
  if [ $IS_REPEATED -eq 1 ]; then
    FIELD_NAME="$(snake_to_camel "$NAME")"
    FIELD_NAME="$(echo "$FIELD_NAME" | awk '{print toupper(substr($0,1,1)) substr($0,2)}')"
    echo "		${FIELD_NAME}: p.${FIELD_NAME}," >> "$MODEL_FILE"
  else
    case "$TYPE_NORM" in
      google.protobuf.Timestamp)
        FIELD_NAME="$(snake_to_camel "$NAME")"
        FIELD_NAME="$(echo "$FIELD_NAME" | awk '{print toupper(substr($0,1,1)) substr($0,2)}')"
        echo "		${FIELD_NAME}: p.Get${FIELD_NAME}().AsTime()," >> "$MODEL_FILE"
        ;;
      *)
        FIELD_NAME="$(snake_to_camel "$NAME")"
        FIELD_NAME="$(echo "$FIELD_NAME" | awk '{print toupper(substr($0,1,1)) substr($0,2)}')"
        echo "		${FIELD_NAME}: p.${FIELD_NAME}," >> "$MODEL_FILE"
        ;;
    esac
  fi
done

cat >> "$MODEL_FILE" <<EOF
		CreatedAt: time.Now(),
		UpdatedAt: time.Now(),
	}
	
	return m
}

// CollectionName returns the MongoDB collection name for this model
func (${SERVICE_NAME}) CollectionName() string {
	return "${SERVICE_NAME_LC_PLURAL}"
}
EOF
  echo "Created model file: $MODEL_FILE"
else
  echo "Model file already exists: $MODEL_FILE"
fi

# Register in server/grpc.go
GRPC_GO="server/grpc.go"
GRPC_REG="pb.Register${SERVICE_NAME}ServiceServer(grpcServer, services.New${SERVICE_NAME}Service())"
grep -q "$GRPC_REG" "$GRPC_GO" || \
  sed -i '' "/grpcServer := grpc.NewServer()/a\\
$GRPC_REG
" "$GRPC_GO"

# Register in server/gateway.go
GATEWAY_GO="server/gateway.go"
GATEWAY_REG="pb.Register${SERVICE_NAME}ServiceHandler(ctx, mux, conn)"
grep -q "$GATEWAY_REG" "$GATEWAY_GO" || \
  sed -i '' "/defer conn.Close()/a\\
\\
	if err = $GATEWAY_REG; err != nil {\\
		return err\\
	}\\
" "$GATEWAY_GO"

echo "Don't forget to run: make proto"
echo "Service registered in $GRPC_GO and $GATEWAY_GO"
echo "Implement your business logic in $GO_FILE" 