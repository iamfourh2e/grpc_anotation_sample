#!/usr/bin/env python3
"""
MCP Server for gRPC Service Management
Integrates with the existing gen_service.sh script and gRPC infrastructure
"""

import asyncio
import json
import logging
import os
import subprocess
import sys
from pathlib import Path
from typing import Any, Dict, List, Optional
import httpx
from mcp.server.fastmcp import FastMCP

# Configure logging to stderr (important for MCP servers)
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    stream=sys.stderr
)
logger = logging.getLogger(__name__)

# Initialize FastMCP server
mcp = FastMCP("grpc-service-manager")

# Constants
PROJECT_ROOT = Path(__file__).parent
GEN_SERVICE_SCRIPT = PROJECT_ROOT / "gen_service.sh"
PROTO_DIR = PROJECT_ROOT / "proto"
SERVICES_DIR = PROJECT_ROOT / "services"
MODELS_DIR = PROJECT_ROOT / "models"
PB_DIR = PROJECT_ROOT / "pb"

class ServiceManager:
    """Manages gRPC services and their generation"""
    
    def __init__(self):
        self.project_root = PROJECT_ROOT
        self.gen_script = GEN_SERVICE_SCRIPT
        
    async def list_services(self) -> List[Dict[str, Any]]:
        """List all existing services"""
        services = []
        
        # Check proto files
        for proto_file in PROTO_DIR.glob("*.proto"):
            if proto_file.name != "health.proto":  # Skip health service
                service_name = proto_file.stem
                service_info = {
                    "name": service_name,
                    "proto_file": str(proto_file),
                    "service_file": str(SERVICES_DIR / f"{service_name}.go"),
                    "model_file": str(MODELS_DIR / f"{service_name}.go"),
                    "has_proto": proto_file.exists(),
                    "has_service": (SERVICES_DIR / f"{service_name}.go").exists(),
                    "has_model": (MODELS_DIR / f"{service_name}.go").exists(),
                }
                services.append(service_info)
        
        return services
    
    async def generate_service(self, service_name: str, fields: str) -> Dict[str, Any]:
        """Generate a new service using gen_service.sh"""
        try:
            # Run the generation script
            result = subprocess.run(
                [str(self.gen_script), service_name, fields],
                capture_output=True,
                text=True,
                cwd=self.project_root
            )
            
            if result.returncode != 0:
                return {
                    "success": False,
                    "error": result.stderr,
                    "output": result.stdout
                }
            
            return {
                "success": True,
                "output": result.stdout,
                "service_name": service_name
            }
            
        except Exception as e:
            logger.error(f"Error generating service: {e}")
            return {
                "success": False,
                "error": str(e)
            }
    
    async def remove_service(self, service_name: str) -> Dict[str, Any]:
        """Remove a service using gen_service.sh"""
        try:
            result = subprocess.run(
                [str(self.gen_script), "remove", service_name],
                capture_output=True,
                text=True,
                cwd=self.project_root
            )
            
            if result.returncode != 0:
                return {
                    "success": False,
                    "error": result.stderr,
                    "output": result.stdout
                }
            
            return {
                "success": True,
                "output": result.stdout,
                "service_name": service_name
            }
            
        except Exception as e:
            logger.error(f"Error removing service: {e}")
            return {
                "success": False,
                "error": str(e)
            }

    async def add_rpc(
        self,
        service_name: str,
        rpc_name: str,
        req_fields: str,
        res_fields: str,
        http_spec: str,
        body_spec: Optional[str] = None,
    ) -> Dict[str, Any]:
        """Add a new RPC to an existing service using gen_service.sh add-rpc"""
        try:
            cmd = [
                str(self.gen_script),
                "add-rpc",
                service_name,
                rpc_name,
                req_fields,
                res_fields,
                f"http={http_spec}",
            ]
            if body_spec:
                cmd.append(f"body={body_spec}")

            result = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                cwd=self.project_root,
            )

            if result.returncode != 0:
                return {
                    "success": False,
                    "error": result.stderr,
                    "output": result.stdout,
                }

            return {
                "success": True,
                "output": result.stdout,
                "service_name": service_name,
                "rpc_name": rpc_name,
            }

        except Exception as e:
            logger.error(f"Error adding RPC: {e}")
            return {"success": False, "error": str(e)}
    
    async def regenerate_proto(self) -> Dict[str, Any]:
        """Regenerate protocol buffer files"""
        try:
            result = subprocess.run(
                ["make", "proto"],
                capture_output=True,
                text=True,
                cwd=self.project_root
            )
            
            if result.returncode != 0:
                return {
                    "success": False,
                    "error": result.stderr,
                    "output": result.stdout
                }
            
            return {
                "success": True,
                "output": result.stdout
            }
            
        except Exception as e:
            logger.error(f"Error regenerating proto: {e}")
            return {
                "success": False,
                "error": str(e)
            }
    
    async def get_service_status(self) -> Dict[str, Any]:
        """Get overall service status and health"""
        try:
            # Check if server is running
            async with httpx.AsyncClient() as client:
                try:
                    response = await client.get("http://localhost:8080/health", timeout=5.0)
                    server_status = "running" if response.status_code == 200 else "error"
                except:
                    server_status = "not_running"
            
            # Count files
            proto_count = len(list(PROTO_DIR.glob("*.proto")))
            service_count = len(list(SERVICES_DIR.glob("*.go")))
            model_count = len(list(MODELS_DIR.glob("*.go")))
            pb_count = len(list(PB_DIR.glob("*.go")))
            
            return {
                "server_status": server_status,
                "proto_files": proto_count,
                "service_files": service_count,
                "model_files": model_count,
                "generated_pb_files": pb_count,
                "project_root": str(self.project_root)
            }
            
        except Exception as e:
            logger.error(f"Error getting service status: {e}")
            return {
                "error": str(e)
            }

# Initialize service manager
service_manager = ServiceManager()

@mcp.tool()
async def list_services() -> str:
    """List all existing gRPC services in the project.
    
    Returns information about each service including:
    - Service name
    - File locations (proto, service, model)
    - Whether files exist
    """
    try:
        services = await service_manager.list_services()
        
        if not services:
            return "No services found in the project."
        
        result = "**Existing Services:**\n\n"
        for service in services:
            result += f"**{service['name']}**\n"
            result += f"- Proto: {'✅' if service['has_proto'] else '❌'} {service['proto_file']}\n"
            result += f"- Service: {'✅' if service['has_service'] else '❌'} {service['service_file']}\n"
            result += f"- Model: {'✅' if service['has_model'] else '❌'} {service['model_file']}\n"
            result += "\n"
        
        return result
        
    except Exception as e:
        logger.error(f"Error listing services: {e}")
        return f"Error listing services: {str(e)}"

@mcp.tool()
async def generate_service(service_name: str, fields: str) -> str:
    """Generate a new gRPC service with the specified fields.
    
    Args:
        service_name: Name of the service (e.g., "User", "Product")
        fields: Comma-separated field definitions in format "name:type,name2:type2"
               Supported types: string, int32, int64, bool, float, double, timestamp
               For repeated fields: "repeated type name" or "name:repeated type"
    
    Examples:
        - generate_service("User", "name:string,email:string,age:int32")
        - generate_service("Product", "name:string,price:float,is_active:bool,created_at:timestamp")
        - generate_service("Order", "items:repeated string,total:float")
    """
    try:
        result = await service_manager.generate_service(service_name, fields)
        
        if result["success"]:
            return f"✅ Service '{service_name}' generated successfully!\n\n{result['output']}"
        else:
            return f"❌ Failed to generate service '{service_name}':\n\n{result['error']}"
            
    except Exception as e:
        logger.error(f"Error generating service: {e}")
        return f"Error generating service: {str(e)}"

@mcp.tool()
async def add_rpc(
    service_name: str,
    rpc_name: str,
    req_fields: str,
    res_fields: str,
    http: str,
    body: Optional[str] = None,
) -> str:
    """Add a new RPC to an existing service.

    Args:
        service_name: Target service (e.g., "User")
        rpc_name: RPC method (PascalCase, e.g., "SearchUsers")
        req_fields: Request fields (e.g., "query:string,limit:int32")
        res_fields: Response fields (e.g., "data:repeated User")
        http: HTTP mapping METHOD:/path (e.g., "GET:/v1/users:search")
        body: Optional body mapping (e.g., "*" or "data")
    """
    try:
        result = await service_manager.add_rpc(service_name, rpc_name, req_fields, res_fields, http, body)
        if result["success"]:
            return f"✅ RPC '{rpc_name}' added to service '{service_name}' successfully!\n\n{result['output']}"
        else:
            return f"❌ Failed to add RPC '{rpc_name}' to service '{service_name}':\n\n{result['error']}"
    except Exception as e:
        logger.error(f"Error adding RPC: {e}")
        return f"Error adding RPC: {str(e)}"

@mcp.tool()
async def remove_service(service_name: str) -> str:
    """Remove a gRPC service and all its associated files.
    
    Args:
        service_name: Name of the service to remove (e.g., "User", "Product")
    
    This will remove:
    - Proto file
    - Service implementation file
    - Model file
    - Service registrations from server files
    """
    try:
        result = await service_manager.remove_service(service_name)
        
        if result["success"]:
            return f"✅ Service '{service_name}' removed successfully!\n\n{result['output']}"
        else:
            return f"❌ Failed to remove service '{service_name}':\n\n{result['error']}"
            
    except Exception as e:
        logger.error(f"Error removing service: {e}")
        return f"Error removing service: {str(e)}"

@mcp.tool()
async def regenerate_proto() -> str:
    """Regenerate all protocol buffer files from proto definitions.
    
    This runs 'make proto' to regenerate:
    - Go gRPC client/server code
    - Gateway code
    - OpenAPI/Swagger documentation
    """
    try:
        result = await service_manager.regenerate_proto()
        
        if result["success"]:
            return f"✅ Protocol buffer files regenerated successfully!\n\n{result['output']}"
        else:
            return f"❌ Failed to regenerate proto files:\n\n{result['error']}"
            
    except Exception as e:
        logger.error(f"Error regenerating proto: {e}")
        return f"Error regenerating proto: {str(e)}"

@mcp.tool()
async def get_project_status() -> str:
    """Get the current status of the gRPC project.
    
    Returns information about:
    - Server status (running/not running)
    - File counts (proto, services, models, generated files)
    - Project structure
    """
    try:
        status = await service_manager.get_service_status()
        
        if "error" in status:
            return f"❌ Error getting project status: {status['error']}"
        
        result = "**Project Status:**\n\n"
        result += f"**Server Status:** {status['server_status']}\n"
        result += f"**Project Root:** {status['project_root']}\n\n"
        result += "**File Counts:**\n"
        result += f"- Proto files: {status['proto_files']}\n"
        result += f"- Service files: {status['service_files']}\n"
        result += f"- Model files: {status['model_files']}\n"
        result += f"- Generated PB files: {status['generated_pb_files']}\n"
        
        return result
        
    except Exception as e:
        logger.error(f"Error getting project status: {e}")
        return f"Error getting project status: {str(e)}"

@mcp.tool()
async def get_service_help() -> str:
    """Get help information about the gRPC service generation system.
    
    Provides examples and usage information for:
    - Field types and formats
    - Service generation patterns
    - Common use cases
    """
    help_text = """
# gRPC Service Manager Help

## Field Types
Supported protobuf field types:
- `string` - Text data
- `int32`, `int64` - Integer numbers
- `bool` - Boolean values
- `float`, `double` - Floating point numbers
- `timestamp` - Date/time (maps to google.protobuf.Timestamp)
- `bytes` - Binary data

## Field Formats
1. **Simple fields:** `name:type`
   - Example: `name:string,age:int32,is_active:bool`

2. **Repeated fields:** `name:repeated type` or `repeated type name`
   - Example: `tags:repeated string` or `repeated string tags`

3. **Timestamp fields:** `created_at:timestamp`
   - Automatically maps to google.protobuf.Timestamp

## Service Examples

### User Service
```
generate_service("User", "name:string,email:string,age:int32,is_active:bool,created_at:timestamp")
```

### Product Service
```
generate_service("Product", "name:string,description:string,price:float,stock:int32,categories:repeated string")
```

### Order Service
```
generate_service("Order", "user_id:string,items:repeated string,total:float,status:string,created_at:timestamp")
```

### Add RPC to Existing Service
```
add_rpc("Action", "SearchActions", "query:string,limit:int32", "data:repeated Action", "GET:/v1/actions:search")
add_rpc("Order", "UpsertOrder", "data:Order", "data:Order", "PUT:/v1/orders/{data.id}", "*")
```

## Generated Files
Each service generates:
- `proto/{service}.proto` - Protocol buffer definitions
- `services/{service}.go` - gRPC service implementation
- `models/{service}.go` - Go model with MongoDB integration
- Updates server registration files

## Workflow
1. Generate service: `generate_service("ServiceName", "fields")`
2. Regenerate proto: `regenerate_proto()`
3. Implement business logic in the service file
4. Test and deploy

## Tips
- Use PascalCase for service names (e.g., "User", "Product")
- Use snake_case for field names (e.g., "user_name", "created_at")
- Always regenerate proto after creating new services
- Check project status to verify file generation
"""
    return help_text

if __name__ == "__main__":
    # Initialize and run the server
    mcp.run(transport='stdio')
