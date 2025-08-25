.PHONY: all help
all: help

help:
	@echo "🚀 gRPC Service Manager - Available Commands"
	@echo ""
	@echo "🗺️ Project Setup:"
	@echo "  init-project PROJECT_NAME=name   Initialize fresh project with new name"
	@echo "  rename-project NEW_NAME=name     Rename existing project"
	@echo ""
	@echo "🛠️ Development:"
	@echo "  proto                           Generate protocol buffer files"
	@echo "  build                           Build the server"
	@echo "  run                             Build and run the server"
	@echo "  dev                             Run with live reload (requires air)"
	@echo "  test                            Run tests"
	@echo ""
	@echo "🖥️ UI Management:"
	@echo "  ui                              Start the web UI server"
	@echo "  ui-build                        Build the UI binary"
	@echo "  ui-clean                        Clean UI build artifacts"
	@echo ""
	@echo "🧹 Cleanup:"
	@echo "  clean                           Remove generated files"
	@echo ""
	@echo "📝 Examples:"
	@echo "  make init-project PROJECT_NAME=my-pos-system"
	@echo "  make rename-project NEW_NAME=my-new-name"
	@echo "  make dev"
	@echo ""

.PHONY: proto
proto: clean
	protoc --proto_path=proto \
	--proto_path=$(GRPC_GATEWAY_MOD) \
	--proto_path=$(GOOGLEAPIS_MOD) \
	--go_out=./pb --go_opt=paths=source_relative \
	--go-grpc_out=./pb --go-grpc_opt=paths=source_relative \
	--grpc-gateway_out=./pb --grpc-gateway_opt=paths=source_relative \
	--openapiv2_out=./pb \
	$(wildcard proto/*.proto)

.PHONY: dev
dev:
	@air

.PHONY: build
build:
	go build -o tmp/main ./cmd/server

.PHONY: run
run: build
	./tmp/main

.PHONY: test
test:
	go test ./...

# UI Management
ui:
	@echo "Starting gRPC Service Manager UI..."
	@cd ui && go run server.go

ui-build:
	@echo "Building gRPC Service Manager UI..."
	@cd ui && go build -o service-manager-ui server.go

ui-clean:
	@echo "Cleaning UI build artifacts..."
	@cd ui && rm -f service-manager-ui

# Project setup
.PHONY: rename-project
rename-project:
	@if [ -z "$(NEW_NAME)" ]; then \
		echo "Usage: make rename-project NEW_NAME=your-new-project-name"; \
		echo "Example: make rename-project NEW_NAME=my-pos-system"; \
		exit 1; \
	fi
	@echo "Renaming project from 'grpc_anotation_sample' to '$(NEW_NAME)'..."
	@# Update go.mod
	@sed -i '' 's/grpc_anotation_sample/$(NEW_NAME)/g' go.mod
	@# Update all Go import statements
	@find . -name "*.go" -type f -exec sed -i '' 's|grpc_anotation_sample|$(NEW_NAME)|g' {} +
	@# Update gen_service.sh script
	@if [ -f "gen_service.sh" ]; then \
		sed -i '' 's/grpc_anotation_sample/$(NEW_NAME)/g' gen_service.sh; \
	fi
	@# Update MCP server configuration example
	@if [ -f "claude_config_example.json" ]; then \
		sed -i '' 's|grpc_anotation_sample|$(NEW_NAME)|g' claude_config_example.json; \
	fi
	@echo "✅ Project renamed successfully!"
	@echo "📝 Next steps:"
	@echo "   1. Run 'go mod tidy' to update dependencies"
	@echo "   2. Run 'make proto' to regenerate protocol buffers"
	@echo "   3. Update your git remote if needed"
	@echo "   4. Update README.md and documentation as needed"

.PHONY: init-project
init-project:
	@if [ -z "$(PROJECT_NAME)" ]; then \
		echo "Usage: make init-project PROJECT_NAME=your-project-name"; \
		echo "Example: make init-project PROJECT_NAME=my-pos-system"; \
		exit 1; \
	fi
	@echo "🚀 Initializing fresh project '$(PROJECT_NAME)'..."
	@# Remove git history
	@if [ -d ".git" ]; then \
		echo "🗑️ Removing existing git history..."; \
		rm -rf .git; \
	fi
	@# Rename project
	@$(MAKE) rename-project NEW_NAME=$(PROJECT_NAME)
	@# Clean generated files
	@$(MAKE) clean
	@# Initialize new git repo
	@echo "📦 Initializing new git repository..."
	@git init
	@git add .
	@git commit -m "Initial commit: $(PROJECT_NAME) project"
	@echo "✅ Fresh project '$(PROJECT_NAME)' initialized!"
	@echo "📝 Next steps:"
	@echo "   1. Run 'go mod tidy'"
	@echo "   2. Run 'make proto' to generate protocol buffers"
	@echo "   3. Add your remote repository: git remote add origin <url>"
	@echo "   4. Update README.md with your project details"

# Cleanup targets
.PHONY: clean
clean:
	rm -f pb/*.go pb/*.json