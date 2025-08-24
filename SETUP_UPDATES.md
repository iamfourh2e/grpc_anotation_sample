# Setup Script Updates Summary

## Overview
The [`setup_mcp.sh`](setup_mcp.sh) script has been significantly improved to provide better error handling, more options, and enhanced user experience.

## New Features Added

### 1. Command Line Options
- `--clean`: Remove existing virtual environment and start fresh
- `--force`: Force reinstall all dependencies (useful for fixing corrupted installations)
- `--help`: Show usage information

### 2. Enhanced Virtual Environment Detection
- Supports both `venv` and `.venv` directory names
- Automatically detects existing environments
- Smart dependency checking and conditional installation

### 3. Improved Error Handling
- Better Python version validation (requires 3.10+)
- Individual dependency testing with recovery options
- More detailed error messages with troubleshooting hints
- Specific handling for macOS externally managed environments

### 4. Better User Experience
- Clear progress indicators with emojis
- Detailed installation feedback
- Comprehensive final instructions
- Troubleshooting options included in output

## Usage Examples

### Basic Setup
```bash
./setup_mcp.sh
```

### Clean Installation (removes existing venv)
```bash
./setup_mcp.sh --clean
```

### Force Reinstall Dependencies
```bash
./setup_mcp.sh --force
```

### Get Help
```bash
./setup_mcp.sh --help
```

## What the Script Does

1. **Validates Python Version**: Ensures Python 3.10+ is available
2. **Handles Virtual Environments**: Creates or reuses existing venv/venv directories
3. **Installs Dependencies**: Uses pip to install from requirements.txt
4. **Tests Installation**: Verifies all imports work correctly
5. **Makes Scripts Executable**: Sets proper permissions
6. **Provides Configuration**: Shows Claude for Desktop integration steps

## Error Recovery

The script now includes several recovery mechanisms:
- Automatic dependency reinstallation on import failures
- Force reinstall option for corrupted packages
- Clean install option for complete environment reset
- Detailed error messages with specific solutions

## Benefits

- **Reliability**: Handles edge cases and common installation issues
- **Flexibility**: Multiple options for different scenarios
- **User-Friendly**: Clear output and instructions
- **Maintainable**: Better error handling makes debugging easier
- **Cross-Platform**: Works on macOS and Linux with appropriate adjustments

## Related Files

- [`setup_mcp.sh`](setup_mcp.sh): Main setup script
- [`run_mcp_server.sh`](run_mcp_server.sh): MCP server runner (auto-created)
- [`activate_mcp.sh`](activate_mcp.sh): Quick activation helper
- [`requirements.txt`](requirements.txt): Python dependencies
- [`mcp_server.py`](mcp_server.py): MCP server implementation