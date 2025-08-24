#!/bin/bash

# Setup script for MCP gRPC Service Manager
# This script handles dependency installation and virtual environment setup
set -e

# Parse command line arguments
CLEAN_INSTALL=false
FORCE_REINSTALL=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --clean)
            CLEAN_INSTALL=true
            shift
            ;;
        --force)
            FORCE_REINSTALL=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [options]"
            echo "Options:"
            echo "  --clean   Remove existing virtual environment and start fresh"
            echo "  --force   Force reinstall all dependencies"
            echo "  --help    Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "🚀 Setting up MCP gRPC Service Manager..."
echo "📍 Project directory: $SCRIPT_DIR"
if [ "$CLEAN_INSTALL" = true ]; then
    echo "🧽 Clean installation requested"
fi
if [ "$FORCE_REINSTALL" = true ]; then
    echo "🔄 Force reinstall requested"
fi

# Check if Python 3.10+ is installed (MCP requirement)
if ! command -v python3 &> /dev/null; then
    echo "❌ Python 3 is not installed. Please install Python 3.10 or higher."
    echo "💡 On macOS: brew install python@3.11"
    echo "💡 On Ubuntu: sudo apt-get install python3.11 python3.11-pip python3.11-venv"
    exit 1
fi

PYTHON_VERSION=$(python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
REQUIRED_VERSION="3.10"

if [ "$(printf '%s\n' "$REQUIRED_VERSION" "$PYTHON_VERSION" | sort -V | head -n1)" != "$REQUIRED_VERSION" ]; then
    echo "❌ Python version $PYTHON_VERSION is too old. MCP requires Python 3.10 or higher."
    echo "💡 On macOS: brew install python@3.11 && brew link python@3.11"
    echo "💡 On Ubuntu: sudo apt-get install python3.11 python3.11-pip python3.11-venv"
    echo "💡 You may also need to use 'python3.11' instead of 'python3'"
    exit 1
fi

echo "✅ Python $PYTHON_VERSION detected (meets MCP requirement of 3.10+)"

# Handle clean installation
if [ "$CLEAN_INSTALL" = true ]; then
    echo "🧽 Performing clean installation..."
    if [ -d "venv" ]; then
        echo "🗑️ Removing existing venv directory..."
        rm -rf venv
    fi
    if [ -d ".venv" ]; then
        echo "🗑️ Removing existing .venv directory..."
        rm -rf .venv
    fi
fi

# Check if virtual environment already exists
if [ -d "venv" ] || [ -d ".venv" ]; then
    echo "🔄 Existing virtual environment found. Checking dependencies..."
    
    # Determine which venv directory exists
    if [ -d ".venv" ]; then
        VENV_DIR=".venv"
        ACTIVATE_SCRIPT=".venv/bin/activate"
    else
        VENV_DIR="venv"
        ACTIVATE_SCRIPT="venv/bin/activate"
    fi
    
    source "$ACTIVATE_SCRIPT"
    
    # Check if dependencies are already installed or force reinstall
    if [ "$FORCE_REINSTALL" = true ] || ! python3 -c "import httpx, mcp" 2>/dev/null; then
        if [ "$FORCE_REINSTALL" = true ]; then
            echo "🔄 Force reinstalling dependencies..."
        else
            echo "📦 Re-installing dependencies..."
        fi
        pip install --upgrade pip
        if [ "$FORCE_REINSTALL" = true ]; then
            pip install --force-reinstall -r requirements.txt
        else
            pip install -r requirements.txt
        fi
    else
        echo "✅ Dependencies already installed and working"
    fi
else
    # Prefer uv if available, fallback to standard venv + pip
    if command -v uv &> /dev/null; then
        echo "✅ uv package manager detected"
        
        # Create virtual environment and install dependencies with uv
        echo "📦 Creating virtual environment with uv..."
        uv venv
        
        echo "📦 Installing dependencies with uv..."
        source .venv/bin/activate
        uv pip install -r requirements.txt
        
        VENV_DIR=".venv"
        ACTIVATE_SCRIPT=".venv/bin/activate"
    else
        echo "⚠️  uv not found, using standard Python venv (recommended for broader compatibility)"
        
        # Check if venv module is available
        if ! python3 -m venv --help &> /dev/null; then
            echo "❌ Python venv module not available. Please install python3-venv:"
            echo "💡 On Ubuntu: sudo apt-get install python3-venv"
            echo "💡 On macOS: Should be included with Python installation"
            exit 1
        fi
        
        # Create virtual environment with standard venv
        echo "📦 Creating virtual environment..."
        python3 -m venv venv
        
        echo "📦 Installing dependencies..."
        source venv/bin/activate
        
        # Upgrade pip first to avoid issues
        echo "📦 Upgrading pip..."
        pip install --upgrade pip
        
        # Install requirements
        if [ -f "requirements.txt" ]; then
            echo "📦 Installing from requirements.txt..."
            if ! pip install -r requirements.txt; then
                echo "❌ Failed to install dependencies. This might be due to:"
                echo "   • Python version compatibility (MCP requires Python 3.10+)"
                echo "   • Network connectivity issues"
                echo "   • Missing system dependencies"
                echo "   • Externally managed environment (macOS/Linux)"
                echo ""
                echo "💡 Try:"
                echo "   • Ensure you have Python 3.10+ installed"
                echo "   • Check your internet connection"
                echo "   • On macOS: Use virtual environments (this script does that)"
                echo "   • Install system dependencies if needed"
                exit 1
            fi
        else
            echo "❌ requirements.txt not found!"
            exit 1
        fi
        
        VENV_DIR="venv"
        ACTIVATE_SCRIPT="venv/bin/activate"
    fi
fi

echo "✅ Dependencies installed successfully"

# Make scripts executable
chmod +x mcp_server.py
if [ -f "run_mcp_server.sh" ]; then
    chmod +x run_mcp_server.sh
fi
if [ -f "gen_service.sh" ]; then
    chmod +x gen_service.sh
fi

# Test the installation more thoroughly
echo "🧪 Testing MCP server installation..."
if source "$ACTIVATE_SCRIPT"; then
    # Test imports one by one for better error reporting
    if ! python3 -c "import httpx" 2>/dev/null; then
        echo "❌ httpx import failed. Attempting to reinstall..."
        pip install --force-reinstall httpx
    fi
    
    if ! python3 -c "import mcp" 2>/dev/null; then
        echo "❌ mcp import failed. Attempting to reinstall..."
        pip install --force-reinstall "mcp[cli]>=1.2.0"
    fi
    
    if python3 -c "import mcp_server; print('✅ MCP server imports successfully')" 2>/dev/null; then
        echo "✅ Installation test passed"
    else
        echo "❌ Installation test failed. Checking mcp_server.py..."
        if [ ! -f "mcp_server.py" ]; then
            echo "❌ mcp_server.py not found in current directory!"
            echo "💡 Please ensure you're running this script from the project root"
            exit 1
        else
            echo "💡 Running diagnostic..."
            python3 -c "import mcp_server" || {
                echo "❌ MCP server has syntax or import errors. Please check the file."
                exit 1
            }
        fi
    fi
else
    echo "❌ Failed to activate virtual environment"
    exit 1
fi

# Create or update the run script if it doesn't exist
if [ ! -f "run_mcp_server.sh" ]; then
    echo "📝 Creating run_mcp_server.sh script..."
    cat > run_mcp_server.sh << 'EOF'
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
echo ""

python3 mcp_server.py
EOF
    chmod +x run_mcp_server.sh
    echo "✅ run_mcp_server.sh created"
else
    echo "ℹ️  run_mcp_server.sh already exists, skipping creation"
fi

echo ""
echo "🎉 Setup complete! You can now:"
echo ""
echo "1. Run the MCP server (recommended):"
echo "   ./run_mcp_server.sh"
echo ""
echo "2. Or run manually:"
echo "   source $ACTIVATE_SCRIPT"
echo "   python3 mcp_server.py"
echo ""
echo "3. Troubleshooting options:"
echo "   ./setup_mcp.sh --clean    # Clean install (removes existing venv)"
echo "   ./setup_mcp.sh --force    # Force reinstall dependencies"
echo "   ./setup_mcp.sh --help     # Show help"
echo ""
echo "3. Configure Claude for Desktop:"
echo "   Add to ~/Library/Application Support/Claude/claude_desktop_config.json:"
echo ""
echo "   {"
echo "     \"mcpServers\": {"
echo "       \"grpc-manager\": {"
echo "         \"command\": \"$SCRIPT_DIR/run_mcp_server.sh\""
echo "       }"
echo "     }"
echo "   }"
echo ""
echo "   Or use the manual configuration:"
echo "   {"
echo "     \"mcpServers\": {"
echo "       \"grpc-manager\": {"
echo "         \"command\": \"python3\","
echo "         \"args\": ["
echo "           \"$SCRIPT_DIR/mcp_server.py\""
echo "         ],"
echo "         \"cwd\": \"$SCRIPT_DIR\","
echo "         \"env\": {"
echo "           \"PATH\": \"$SCRIPT_DIR/$VENV_DIR/bin:\$PATH\""
echo "         }"
echo "       }"
echo "     }"
echo "   }"
echo ""
echo "4. Available MCP tools:"
echo "   - list_services: List all existing gRPC services"
echo "   - generate_service: Create a new gRPC service"
echo "   - remove_service: Remove a gRPC service"
echo "   - regenerate_proto: Regenerate protocol buffer files"
echo "   - get_project_status: Get project status"
echo "   - get_service_help: Get help and examples"
echo ""
echo "📖 For troubleshooting, see TROUBLESHOOTING.md"
echo ""
echo "Happy coding! 🚀"
