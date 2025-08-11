# gRPC Annotation Sample

This project demonstrates generating gRPC services with HTTP/REST gateway and a helper UI to create/remove services quickly.

## Quick Start
```bash
git clone https://github.com/iamfourh2e/grpc_anotation_sample && cd grpc_anotation_sample
```
```bash
rm -rf .git
```
```bash
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
make proto   # Generate pb code, grpc, gateway, and swagger from proto/
make build   # Build server binary into tmp/main
make run     # Build and run server
make test    # Run tests
make ui      # Start the gRPC Service Manager UI (http://localhost:8081)
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