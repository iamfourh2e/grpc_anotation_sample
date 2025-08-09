# gRPC Annotation Sample

This project demonstrates generating gRPC services with HTTP/REST gateway and a helper UI to create/remove services quickly.

## Quick Start

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
  - name:repeated type
  - repeated type name
- Examples:
  - `favorites:repeated string`
  - `repeated UserRef followers`

### Type Normalization

The generator and UI normalize common types:
- Scalars kept lowercase: `string`, `bool`, `bytes`, `int32`, `int64`, `float`, `double`, etc.
- `timestamp` or `google.protobuf.timestamp` → `google.protobuf.Timestamp` and auto-imports `google/protobuf/timestamp.proto`.
- Custom message types are normalized to PascalCase first letter (e.g., `userRef` → `UserRef`).

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

## Project Structure

```
proto/     # .proto files (one per service)
pb/        # Generated protobuf, gRPC, gateway, swagger
services/  # Go service stubs implementing servers
server/    # gRPC server and HTTP gateway wiring
cmd/       # Server entrypoint
ui/        # Local UI for service management
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