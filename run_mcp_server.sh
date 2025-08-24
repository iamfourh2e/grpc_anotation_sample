#!/bin/bash

# Script to run the MCP Server with proper virtual environment activation
# This script resolves the httpx dependency issue by using the virtual environment
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Determine which virtual environment directory exists
if [ -d ".venv" ]; then
    VENV_DIR=".venv"
elif [ -d "venv" ]; then
    VENV_DIR="venv"
else
    echo "❌ No virtual environment found. Please run setup_mcp.sh first."
    echo "💡 Run: ./setup_mcp.sh"
    exit 1
fi

echo "🔧 Activating virtual environment ($VENV_DIR)..."
source "$VENV_DIR/bin/activate"

# Check if dependencies are installed
if ! python3 -c "import httpx, mcp" 2>/dev/null; then
    echo "📦 Missing dependencies detected. Installing..."
    if [ -f "requirements.txt" ]; then
        pip install -r requirements.txt
        echo "✅ Dependencies installed"
    else
        echo "❌ requirements.txt not found!"
        exit 1
    fi
fi

# Verify MCP server can be imported
if ! python3 -c "import mcp_server" 2>/dev/null; then
    echo "❌ Failed to import MCP server. Please check the installation."
    echo "💡 Try running: ./setup_mcp.sh"
    exit 1
fi

echo "🚀 Starting MCP Server..."
echo "📍 Project root: $SCRIPT_DIR"
echo "📁 Virtual environment: $SCRIPT_DIR/$VENV_DIR"
echo "🔗 Python path: $(which python3)"
if [ -n "$MCP_GRPC_PROJECT_ROOT" ]; then
    echo "🎯 Go project root: $MCP_GRPC_PROJECT_ROOT"
fi
echo ""

python3 mcp_server.py