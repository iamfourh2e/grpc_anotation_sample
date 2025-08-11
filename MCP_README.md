# MCP gRPC Service Manager

An MCP (Model Context Protocol) server that integrates with your existing gRPC service generation system. This server provides tools to manage, generate, and maintain gRPC services through Claude for Desktop and other MCP clients.

## Features

- **Service Management**: List, generate, and remove gRPC services
- **Protocol Buffer Generation**: Automatically regenerate proto files
- **Project Status**: Monitor your gRPC project health
- **Integration**: Works seamlessly with your existing `gen_service.sh` script
- **MongoDB Support**: Follows your MongoDB conventions and patterns

## Quick Start

### 1. Setup

Run the setup script to install dependencies:

```bash
./setup_mcp.sh
```

### 2. Configure Claude for Desktop

Add the following to your Claude for Desktop configuration file:
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

Replace `/path/to/your/project/` with the actual path to your project.

### 3. Restart Claude for Desktop

Restart Claude for Desktop to load the new MCP server configuration.

## Available Tools

### 1. `list_services`
Lists all existing gRPC services in your project.

**Example:**
```
List all services in the project
```

### 2. `generate_service`
Generate a new gRPC service with specified fields.

**Parameters:**
- `service_name`: Name of the service (e.g., "User", "Product")
- `fields`: Comma-separated field definitions

**Examples:**
```
generate_service("User", "name:string,email:string,age:int32,is_active:bool,created_at:timestamp")
generate_service("Product", "name:string,description:string,price:float,stock:int32,categories:repeated string")
generate_service("Order", "user_id:string,items:repeated string,total:float,status:string,created_at:timestamp")
```

### 3. `remove_service`
Remove a gRPC service and all its associated files.

**Parameters:**
- `service_name`: Name of the service to remove

**Example:**
```
remove_service("User")
```

### 4. `regenerate_proto`
Regenerate all protocol buffer files from proto definitions.

**Example:**
```
Regenerate all proto files
```

### 5. `get_project_status`
Get the current status of your gRPC project.

**Example:**
```
Get project status
```

### 6. `get_service_help`
Get help information about the gRPC service generation system.

**Example:**
```
Get help with service generation
```

## Field Types

The MCP server supports all standard protobuf field types:

- `string` - Text data
- `int32`, `int64` - Integer numbers
- `bool` - Boolean values
- `float`, `double` - Floating point numbers
- `timestamp` - Date/time (maps to google.protobuf.Timestamp)
- `bytes` - Binary data

## Field Formats

### Simple Fields
```
name:type
```
Example: `name:string,age:int32,is_active:bool`

### Repeated Fields
```
name:repeated type
```
Example: `tags:repeated string,categories:repeated string`

### Timestamp Fields
```
created_at:timestamp
```
Automatically maps to `google.protobuf.Timestamp`

## Generated Files

Each service generates the following files:

- `proto/{service}.proto` - Protocol buffer definitions
- `services/{service}.go` - gRPC service implementation
- `models/{service}.go` - Go model with MongoDB integration
- Updates server registration files

## Workflow

1. **Generate Service**: Use `generate_service()` to create a new service
2. **Regenerate Proto**: Use `regenerate_proto()` to generate Go code
3. **Implement Logic**: Add business logic to the service file
4. **Test**: Run your gRPC server and test the new service

## Integration with Your Existing System

This MCP server integrates seamlessly with your existing:

- `gen_service.sh` script
- Go workspace structure
- MongoDB conventions
- Protocol buffer patterns
- Makefile build system

## Troubleshooting

### Server Not Showing Up in Claude
1. Check your `claude_desktop_config.json` file syntax
2. Ensure the path to your project is absolute
3. Restart Claude for Desktop completely

### Tool Calls Failing
1. Check Claude's logs in `~/Library/Logs/Claude/`
2. Verify your server builds and runs without errors
3. Ensure all dependencies are installed

### Permission Issues
1. Make sure `mcp_server.py` is executable: `chmod +x mcp_server.py`
2. Check that the virtual environment is activated
3. Verify Python path in the configuration

## Development

### Running the Server Manually

```bash
# Activate virtual environment
source .venv/bin/activate

# Run the server
python mcp_server.py
```

### Testing Tools

You can test the tools directly in Claude for Desktop:

1. Open Claude for Desktop
2. Look for the "Search and tools" icon (slider)
3. You should see the gRPC manager tools listed
4. Try generating a test service:

```
Generate a User service with name, email, and age fields
```

## Architecture

The MCP server consists of:

- **FastMCP Server**: Main server implementation using the MCP Python SDK
- **ServiceManager Class**: Manages gRPC service operations
- **Tool Decorators**: Expose functionality as MCP tools
- **Integration Layer**: Connects with your existing shell scripts and build system

## Contributing

To extend the MCP server:

1. Add new methods to the `ServiceManager` class
2. Create corresponding tool functions with `@mcp.tool()` decorator
3. Update the help documentation
4. Test with Claude for Desktop

## License

This MCP server is part of your gRPC annotation sample project and follows the same licensing terms.
