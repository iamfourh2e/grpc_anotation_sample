# gRPC Service Manager UI

A modern, interactive web interface for managing gRPC services in your project. This UI provides an easy way to create and remove services without using the command line.

## Features

- 🎨 **Modern UI**: Clean, responsive design with gradient backgrounds and smooth animations
- ➕ **Create Services**: Easy form-based service creation with field validation
- 🗑️ **Remove Services**: One-click service removal with confirmation
- 📋 **Service Discovery**: Automatically detects existing services from proto files
- 🔄 **Auto-refresh**: Services list updates automatically
- 📱 **Responsive**: Works on desktop and mobile devices
- ⚡ **Real-time**: Instant feedback and loading states

## Quick Start

### 1. Start the UI Server

```bash
cd ui
go run server.go
```

The UI will be available at: http://localhost:8081

### 2. Create a Service

1. Open http://localhost:8081 in your browser
2. Fill in the service name (e.g., "User")
3. Add fields in the format: `name:string,email:string,age:int32`
4. Click "Create Service"

### 3. Remove a Service

1. Find the service in the "Existing Services" section
2. Click "Remove Service"
3. Confirm the deletion

## API Endpoints

The UI server provides these REST API endpoints:

- `GET /api/services` - List all services
- `POST /api/services` - Create a new service
- `DELETE /api/services/{name}` - Remove a service

## Service Field Types

Supported Protocol Buffer field types:

- `string` - String values
- `int32` - 32-bit integers
- `int64` - 64-bit integers
- `bool` - Boolean values
- `float` - 32-bit floating point
- `double` - 64-bit floating point
- `google.protobuf.Timestamp` - Timestamp values
- `bytes` - Byte arrays

## Examples

### User Service
```
Service Name: User
Fields: name:string,email:string,age:int32,active:bool,created_at:google.protobuf.Timestamp
```

### Product Service
```
Service Name: Product
Fields: name:string,description:string,price:double,stock:int32,category:string
```

### Order Service
```
Service Name: Order
Fields: customer_id:string,items:bytes,total:double,status:string,created_at:google.protobuf.Timestamp
```

## File Structure

```
ui/
├── index.html          # Main UI interface
├── server.go           # HTTP server and API handlers
├── go.mod             # Go module dependencies
└── README.md          # This file
```

## Development

### Prerequisites

- Go 1.21 or later
- Access to the parent directory with `gen_service.sh` script
- `make` command available for proto generation

### Building

```bash
cd ui
go build -o service-manager-ui server.go
./service-manager-ui
```

### Customization

The UI can be customized by modifying:

- `index.html` - Frontend interface and styling
- `server.go` - Backend API logic and service discovery
- CSS styles in the HTML file for visual customization

## Integration

The UI integrates with your existing project by:

1. Using the `gen_service.sh` script for service creation/removal
2. Running `make proto` to regenerate protocol buffer code
3. Discovering services by scanning the `proto/` directory
4. Providing REST API endpoints for programmatic access

## Troubleshooting

### Common Issues

1. **"Failed to create service"**
   - Ensure `gen_service.sh` is executable: `chmod +x ../gen_service.sh`
   - Check that the script exists in the parent directory

2. **"Proto generation failed"**
   - Verify `make proto` works from the parent directory
   - Check that protoc and related tools are installed

3. **"Service not found"**
   - Ensure the service name matches the proto file name
   - Check that the proto file exists in the `proto/` directory

### Logs

The server provides detailed error messages in the API responses. Check the browser's developer console for additional debugging information.

## Security Notes

- The UI server runs on localhost only
- No authentication is implemented (intended for local development)
- File operations are restricted to the project directory
- CORS is enabled for local development

## Contributing

To add new features:

1. Modify the HTML interface in `index.html`
2. Add new API endpoints in `server.go`
3. Update the service discovery logic as needed
4. Test with various service configurations

## License

This UI is part of the gRPC annotation sample project and follows the same license terms. 