#!/bin/bash

# Setup script for MCP gRPC Service Manager
set -e

echo "🚀 Setting up MCP gRPC Service Manager..."

# Check if Python 3.10+ is installed
if ! command -v python3 &> /dev/null; then
    echo "❌ Python 3 is not installed. Please install Python 3.10 or higher."
    exit 1
fi

PYTHON_VERSION=$(python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
REQUIRED_VERSION="3.10"

if [ "$(printf '%s\n' "$REQUIRED_VERSION" "$PYTHON_VERSION" | sort -V | head -n1)" != "$REQUIRED_VERSION" ]; then
    echo "❌ Python version $PYTHON_VERSION is too old. Please install Python 3.10 or higher."
    exit 1
fi

echo "✅ Python $PYTHON_VERSION detected"

# Check if uv is installed
if ! command -v uv &> /dev/null; then
    echo "📦 Installing uv package manager..."
    curl -LsSf https://astral.sh/uv/install.sh | sh
    echo "✅ uv installed successfully"
    echo "⚠️  Please restart your terminal or run: source ~/.bashrc"
else
    echo "✅ uv is already installed"
fi

# Create virtual environment and install dependencies
echo "📦 Creating virtual environment and installing dependencies..."
uv venv
source .venv/bin/activate
uv pip install -r requirements.txt

echo "✅ Dependencies installed successfully"

# Make the MCP server executable
chmod +x mcp_server.py

echo ""
echo "🎉 Setup complete! You can now:"
echo ""
echo "1. Run the MCP server:"
echo "   source .venv/bin/activate"
echo "   python mcp_server.py"
echo ""
echo "2. Configure Claude for Desktop:"
echo "   Add to ~/Library/Application Support/Claude/claude_desktop_config.json:"
echo ""
echo "   {"
echo "     \"mcpServers\": {"
echo "       \"grpc-manager\": {"
echo "         \"command\": \"python3\","
echo "         \"args\": ["
echo "           \"$(pwd)/mcp_server.py\""
echo "         ]"
echo "       }"
echo "     }"
echo "   }"
echo ""
echo "3. Available tools:"
echo "   - list_services: List all existing gRPC services"
echo "   - generate_service: Create a new gRPC service"
echo "   - remove_service: Remove a gRPC service"
echo "   - regenerate_proto: Regenerate protocol buffer files"
echo "   - get_project_status: Get project status"
echo "   - get_service_help: Get help and examples"
echo ""
echo "Happy coding! 🚀"
