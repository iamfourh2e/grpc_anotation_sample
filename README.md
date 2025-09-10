# gRPC Annotation Sample

This project demonstrates generating gRPC services with HTTP/REST gateway and a helper UI to create/remove services quickly.

## Quick Start

### For Fresh Projects

If you're starting a new project with a custom name:

```bash
git clone https://github.com/iamfourh2e/grpc_anotation_sample
cd grpc_anotation_sample

# Initialize fresh project with your custom name
make init-project PROJECT_NAME=my-pos-system

# Or just rename without removing git history
make rename-project NEW_NAME=my-pos-system
```

### For Development/Testing

```bash
git clone https://github.com/iamfourh2e/grpc_anotation_sample && cd grpc_anotation_sample
rm -rf .git
make dev
```

### Generate a Service

```bash
# Create a new service (fields are name:type pairs)
./gen_service.sh Book "title:string,author:string,pages:int32"

# Remove the service
./gen_service.sh remove Book
```

The script auto-detects your module name from `go.mod` and sets `option go_package` in proto files accordingly.

### Repeated Fields and Types

- Repeated fields are supported in two styles:
  - name:type style:
    - favorites:repeated string
    - followers:repeated UserRef
  - natural style:
    - repeated string favorites
    - repeated UserRef followers

### Type Normalization

The generator and UI normalize common types:
- Scalars kept lowercase: `string`, `bool`, `bytes`, `int32`, `int64`, `float`, `double`, etc.
- `timestamp` or `google.protobuf.timestamp` → `google.protobuf.Timestamp` and auto-imports `google/protobuf/timestamp.proto`.
- Custom message types are normalized to PascalCase first letter (e.g., `userRef` → `UserRef`).

## Generated Files

For each service, the script creates:

1. **proto/{service}.proto** - Protocol buffer definitions with HTTP annotations
2. **services/{service}.go** - Go service stub implementing the gRPC interface
3. **models/{service}.go** - Go model with MongoDB/JSON tags and conversion methods
4. **Auto-registration** in `server/grpc.go` and `server/gateway.go`

### Model Features

The generated model includes:
- Struct with proper JSON/BSON tags
- Constructor with MongoDB ObjectID generation
- `ToProto()` method to convert model → protobuf
- `FromProto()` method to convert protobuf → model
- `CollectionName()` method for MongoDB collection name
- Automatic timestamp handling for `google.protobuf.Timestamp` fields
- Support for repeated fields (slices)

## Makefile

Useful targets:

```bash
# Project Setup
make help                              # Show all available commands
make init-project PROJECT_NAME=name   # Initialize fresh project with new name
make rename-project NEW_NAME=name     # Rename existing project

# Development
make proto   # Generate pb code, grpc, gateway, and swagger from proto/
make build   # Build server binary into tmp/main
make run     # Build and run server
make dev     # Run with live reload (requires air)
make test    # Run tests

# UI Management
make ui      # Start the gRPC Service Manager UI (http://localhost:8081)
make ui-build # Build UI binary
make ui-clean # Clean UI build artifacts

# Cleanup
make clean   # Remove generated files
```

## UI: gRPC Service Manager

A local UI is available to create/remove services without using CLI.

```bash
cd ui
go run server.go
# Open http://localhost:8081
```

- Create services using a form with field validation
- Remove services with one click
- The UI accepts both repeated syntaxes and normalizes types before sending to the API

## MCP Server: Claude for Desktop Integration

An MCP (Model Context Protocol) server is available for seamless integration with Claude for Desktop and other MCP clients.

### Setup

```bash
# Install dependencies and setup the MCP server
./setup_mcp.sh
```

### Configure Claude for Desktop

Add the following to your Claude for Desktop configuration:
`~/Library/Application Support/Claude/claude_desktop_config.json`

```json
{
  "mcpServers": {
    "grpc-manager": {
      "command": "python3",
      "args": [
        "/path/to/your/project/mcp_server.py"
      ]
    }
  }
}
```

### Available Tools

- **list_services**: List all existing gRPC services
- **generate_service**: Create a new gRPC service with specified fields
- **add_rpc**: Add an RPC to an existing service (generates messages, inserts HTTP mapping, appends Go stub)
- **remove_service**: Remove a gRPC service and all its files
- **regenerate_proto**: Regenerate protocol buffer files
- **get_project_status**: Get project health and status
- **get_service_help**: Get help and examples

### Example Usage in Claude

```
Generate a User service with name, email, and age fields
```

For detailed documentation, see [MCP_README.md](MCP_README.md).

## Project Structure

```
proto/     # .proto files (one per service)
pb/        # Generated protobuf, gRPC, gateway, swagger
services/  # Go service stubs implementing servers
models/    # Go models with MongoDB/JSON tags and conversion methods
server/    # gRPC server and HTTP gateway wiring
cmd/       # Server entrypoint
ui/        # Local UI for service management
mcp_server.py          # MCP server for Claude for Desktop integration
setup_mcp.sh           # MCP server setup script
requirements.txt       # Python dependencies for MCP server
MCP_README.md          # Detailed MCP server documentation
```

## Examples

```bash
./gen_service.sh User "name:string,email:string,age:int32,active:bool,created_at:timestamp"
./gen_service.sh Profile "favourites:repeated string,repeated UserRef followers"

# Add RPC to existing service
./gen_service.sh add-rpc Action SearchActions "query:string,limit:int32" "data:repeated Action" "http=GET:/v1/actions:search"

# Add nested message and field to an existing service
# Adds message Location { type:string, coordinates:repeated double } and field `location` to message ServiceName
./gen_service.sh add-nested Place location "type:string,coordinates:repeated double"
```

After creating services, regenerate code:

```bash
make proto
```

## Notes

- Ensure the script is executable: `chmod +x gen_service.sh`
- The generator uses `go.mod` module name for proto `go_package` and imports
- Registrations are automatically added/removed in `server/grpc.go` and `server/gateway.go`
- Models include MongoDB ObjectID generation and proper timestamp handling

## RPCs and Nested Fields

### Conventions
- **Message naming**: Always use `Request`/`Response` suffixes (e.g., `CreateBookRequest`, `CreateBookResponse`).
- **HTTP annotations**: Every RPC exposed via the gateway must have `google.api.http` options.
- **Body mapping**: Use `body: "*"` for full request bodies or `body: "data"` when the payload is wrapped under `data`.
- **Pagination**: Standard fields `page:int32`, `limit:int32` and the response includes `total:int64`, `page:int32`, `limit:int32`.
- **Timestamps**: Use `google.protobuf.Timestamp` for datetime fields.
- **IDs**: Strings backed by MongoDB `ObjectID` (generated in models).

### Example: CRUD RPCs with HTTP Mappings
```proto
syntax = "proto3";
package pb;

import "google/api/annotations.proto";
import "google/protobuf/timestamp.proto";
option go_package = "grpc_anotation_sample/pb";

message Thing {
  string id = 1;
  string name = 2;
  google.protobuf.Timestamp created_at = 3;
}

message CreateThingRequest { Thing data = 1; }
message CreateThingResponse { Thing data = 1; }
message GetThingRequest { string id = 1; }
message GetThingResponse { Thing data = 1; }
message UpdateThingRequest { Thing data = 1; }
message UpdateThingResponse { Thing data = 1; }
message DeleteThingRequest { string id = 1; }
message DeleteThingResponse { bool success = 1; }

service ThingService {
  rpc CreateThing(CreateThingRequest) returns (CreateThingResponse) {
    option (google.api.http) = { post: "/v1/things" body: "*" };
  }
  rpc GetThing(GetThingRequest) returns (GetThingResponse) {
    option (google.api.http) = { get: "/v1/things/{id}" };
  }
  rpc UpdateThing(UpdateThingRequest) returns (UpdateThingResponse) {
    option (google.api.http) = { put: "/v1/things/{data.id}" body: "*" };
  }
  rpc DeleteThing(DeleteThingRequest) returns (DeleteThingResponse) {
    option (google.api.http) = { delete: "/v1/things/{id}" };
  }
}
```

### Example: List and Search RPCs
```proto
message ListThingsRequest {
  int32 page = 1;
  int32 limit = 2;
  string sort_by = 3;
  string sort_order = 4; // asc|desc
}
message ListThingsResponse {
  repeated Thing data = 1;
  int64 total = 2;
  int32 page = 3;
  int32 limit = 4;
}

message SearchThingsRequest {
  string query = 1;
  int32 page = 2;
  int32 limit = 3;
}
message SearchThingsResponse {
  repeated Thing data = 1;
  int64 total = 2;
  int32 page = 3;
  int32 limit = 4;
}

service ThingService {
  rpc ListThings(ListThingsRequest) returns (ListThingsResponse) {
    option (google.api.http) = { get: "/v1/things" };
  }
  rpc SearchThings(SearchThingsRequest) returns (SearchThingsResponse) {
    option (google.api.http) = { get: "/v1/things:search" };
  }
}
```

### Nested Fields
Use nested messages to group related substructures, and reference them as fields on your main message.

```proto
message Address {
  string street = 1;
  string city = 2;
  string state = 3;
  string postal_code = 4;
  string country = 5;
}

message Location {
  double latitude = 1;
  double longitude = 2;
}

message Place {
  string id = 1;
  string name = 2;
  Address address = 3;            // single nested object
  repeated Address branches = 4;   // repeated nested objects
  Location location = 5;           // another nested object
}
```

### grpc-manager Tooling: Creating RPCs and Nested Types
- **Generate service**
  - generate_service("Thing", "name:string,created_at:timestamp")
- **Add RPCs**
  - add_rpc("Thing", "CreateThing", "data:Thing", "data:Thing", "POST:/v1/things", "*")
  - add_rpc("Thing", "GetThing", "id:string", "data:Thing", "GET:/v1/things/{id}")
  - add_rpc("Thing", "UpdateThing", "data:Thing", "data:Thing", "PUT:/v1/things/{data.id}", "*")
  - add_rpc("Thing", "DeleteThing", "id:string", "success:bool", "DELETE:/v1/things/{id}")
  - add_rpc("Thing", "ListThings", "page:int32,limit:int32,sort_by:string,sort_order:string", "data:repeated Thing,total:int64,page:int32,limit:int32", "GET:/v1/things")
  - add_rpc("Thing", "SearchThings", "query:string,page:int32,limit:int32", "data:repeated Thing,total:int64,page:int32,limit:int32", "GET:/v1/things:search")
- **Add nested message and field**
  - add_nested("Place", "address", "street:string,city:string,state:string,postal_code:string,country:string", false, "Address")
  - add_nested("Place", "location", "latitude:double,longitude:double", false, "Location")
- **Regenerate artifacts**
  - regenerate_proto()

### Model Conversion (Generated)
- `models/{service}.go` includes `ToProto()` and `FromProto()` helpers for both root and nested types.
- For repeated nested fields, conversions iterate slices to map between Go structs and protobuf messages.
- Timestamp fields are converted to/from `time.Time` and `google.protobuf.Timestamp` automatically.

### Testing RPCs and Nested Fields
- Use `go test -v ./...` and prefer `testify` suite/assert.
- For repository/integration tests, use a dedicated MongoDB test database set via environment variables.
- Test cases should cover:
  - Create/Read/Update/Delete flows
  - Pagination edge cases (page=0/limit=0, large pages)
  - Search filters and sorting
  - Nested field round-trip (model → proto → model)
  - Gateway routes and HTTP body mappings (e.g., `body: "*"` vs `body: "data"`)

### Gotchas and Tips
- If you see proto regeneration errors about duplicates, open the affected `proto/*.proto` and remove the duplicate RPC or message definitions, then run regeneration again.
- Always ensure `option go_package` matches your module path (`grpc_anotation_sample/pb`).
- Import `google/protobuf/timestamp.proto` when using `google.protobuf.Timestamp`.
- After structural changes (new service/RPC/nested), always run `make proto`.