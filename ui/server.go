package main

import (
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
)

type ServiceRequest struct {
	ServiceName   string `json:"serviceName"`
	ServiceFields string `json:"serviceFields"`
}

type ServiceResponse struct {
	Success bool   `json:"success"`
	Message string `json:"message,omitempty"`
	Error   string `json:"error,omitempty"`
}

type Service struct {
	Name   string   `json:"name"`
	Fields []string `json:"fields"`
}

type ServicesResponse struct {
	Services []Service `json:"services"`
	Error    string    `json:"error,omitempty"`
}

func main() {
	// Serve static files
	http.HandleFunc("/", handleIndex)

	// API endpoints
	http.HandleFunc("/api/services", handleServices)
	http.HandleFunc("/api/services/", handleServiceOperations)
	http.HandleFunc("/api/rpc", handleRpc)
	http.HandleFunc("/api/nested", handleNested)

	fmt.Println("🚀 gRPC Service Manager UI starting on http://localhost:8081")
	fmt.Println("📁 Serving UI from: ui/")
	fmt.Println("🔧 API endpoints: /api/services")

	if err := http.ListenAndServe(":8081", nil); err != nil {
		fmt.Printf("Error starting server: %v\n", err)
		os.Exit(1)
	}
}

func handleIndex(w http.ResponseWriter, r *http.Request) {
	if r.URL.Path != "/" {
		http.NotFound(w, r)
		return
	}

	// Read and serve the HTML file
	htmlPath := "index.html"
	content, err := os.ReadFile(htmlPath)
	if err != nil {
		http.Error(w, "Failed to read index.html", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "text/html")
	w.Write(content)
}

func handleServices(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	w.Header().Set("Access-Control-Allow-Origin", "*")
	w.Header().Set("Access-Control-Allow-Methods", "GET, POST, DELETE, OPTIONS")
	w.Header().Set("Access-Control-Allow-Headers", "Content-Type")

	if r.Method == "OPTIONS" {
		w.WriteHeader(http.StatusOK)
		return
	}

	switch r.Method {
	case "GET":
		handleGetServices(w, r)
	case "POST":
		handleCreateService(w, r)
	default:
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
	}
}

func handleServiceOperations(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	w.Header().Set("Access-Control-Allow-Origin", "*")
	w.Header().Set("Access-Control-Allow-Methods", "DELETE, OPTIONS")
	w.Header().Set("Access-Control-Allow-Headers", "Content-Type")

	if r.Method == "OPTIONS" {
		w.WriteHeader(http.StatusOK)
		return
	}

	if r.Method == "DELETE" {
		handleDeleteService(w, r)
	} else {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
	}
}

type AddRpcRequest struct {
	ServiceName string `json:"serviceName"`
	RpcName     string `json:"rpcName"`
	ReqFields   string `json:"reqFields"`
	ResFields   string `json:"resFields"`
	Http        string `json:"http"`
	Body        string `json:"body,omitempty"`
}

type AddNestedRequest struct {
	ServiceName string `json:"serviceName"`
	FieldName   string `json:"fieldName"`
	Fields      string `json:"fields"`
	Repeated    bool   `json:"repeated"`
	MessageName string `json:"messageName,omitempty"`
}

func handleNested(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	w.Header().Set("Access-Control-Allow-Origin", "*")
	w.Header().Set("Access-Control-Allow-Methods", "POST, OPTIONS")
	w.Header().Set("Access-Control-Allow-Headers", "Content-Type")

	if r.Method == "OPTIONS" {
		w.WriteHeader(http.StatusOK)
		return
	}

	if r.Method != "POST" {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	var req AddNestedRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		json.NewEncoder(w).Encode(ServiceResponse{Success: false, Error: "Invalid JSON request"})
		return
	}

	if req.ServiceName == "" || req.FieldName == "" || req.Fields == "" {
		json.NewEncoder(w).Encode(ServiceResponse{Success: false, Error: "serviceName, fieldName and fields are required"})
		return
	}

	args := []string{"gen_service.sh", "add-nested", req.ServiceName, req.FieldName, req.Fields}
	if req.Repeated {
		args = append(args, "repeated")
	}
	if strings.TrimSpace(req.MessageName) != "" {
		args = append(args, req.MessageName)
	}
	cmd := exec.Command("./"+args[0], args[1:]...)
	cmd.Dir = ".."

	output, err := cmd.CombinedOutput()
	if err != nil {
		json.NewEncoder(w).Encode(ServiceResponse{Success: false, Error: fmt.Sprintf("Failed to add nested message: %v\nOutput: %s", err, string(output))})
		return
	}

	protoCmd := exec.Command("make", "proto")
	protoCmd.Dir = ".."
	if protoOut, perr := protoCmd.CombinedOutput(); perr != nil {
		json.NewEncoder(w).Encode(ServiceResponse{Success: false, Error: fmt.Sprintf("Nested added but proto regeneration failed: %v\nOutput: %s", perr, string(protoOut))})
		return
	}

	json.NewEncoder(w).Encode(ServiceResponse{Success: true, Message: "Nested message and field added"})
}

func handleRpc(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	w.Header().Set("Access-Control-Allow-Origin", "*")
	w.Header().Set("Access-Control-Allow-Methods", "POST, OPTIONS")
	w.Header().Set("Access-Control-Allow-Headers", "Content-Type")

	if r.Method == "OPTIONS" {
		w.WriteHeader(http.StatusOK)
		return
	}

	if r.Method != "POST" {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	var req AddRpcRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		json.NewEncoder(w).Encode(ServiceResponse{Success: false, Error: "Invalid JSON request"})
		return
	}

	if req.ServiceName == "" || req.RpcName == "" || req.ReqFields == "" || req.ResFields == "" || req.Http == "" {
		json.NewEncoder(w).Encode(ServiceResponse{Success: false, Error: "serviceName, rpcName, reqFields, resFields and http are required"})
		return
	}

	// Execute gen_service.sh add-rpc
	args := []string{"gen_service.sh", "add-rpc", req.ServiceName, req.RpcName, req.ReqFields, req.ResFields, fmt.Sprintf("http=%s", req.Http)}
	if strings.TrimSpace(req.Body) != "" {
		args = append(args, fmt.Sprintf("body=%s", req.Body))
	}
	cmd := exec.Command("./"+args[0], args[1:]...)
	cmd.Dir = ".."

	output, err := cmd.CombinedOutput()
	if err != nil {
		json.NewEncoder(w).Encode(ServiceResponse{Success: false, Error: fmt.Sprintf("Failed to add RPC: %v\nOutput: %s", err, string(output))})
		return
	}

	// Regenerate proto
	protoCmd := exec.Command("make", "proto")
	protoCmd.Dir = ".."
	if protoOut, perr := protoCmd.CombinedOutput(); perr != nil {
		json.NewEncoder(w).Encode(ServiceResponse{Success: false, Error: fmt.Sprintf("RPC added but proto regeneration failed: %v\nOutput: %s", perr, string(protoOut))})
		return
	}

	json.NewEncoder(w).Encode(ServiceResponse{Success: true, Message: fmt.Sprintf("RPC '%s' added to '%s'", req.RpcName, req.ServiceName)})
}

func handleGetServices(w http.ResponseWriter, _ *http.Request) {
	services, err := discoverServices()
	if err != nil {
		response := ServicesResponse{
			Error: fmt.Sprintf("Failed to discover services: %v", err),
		}
		json.NewEncoder(w).Encode(response)
		return
	}

	response := ServicesResponse{
		Services: services,
	}
	json.NewEncoder(w).Encode(response)
}

func handleCreateService(w http.ResponseWriter, r *http.Request) {
	var req ServiceRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		response := ServiceResponse{
			Success: false,
			Error:   "Invalid JSON request",
		}
		json.NewEncoder(w).Encode(response)
		return
	}

	// Validate input
	if req.ServiceName == "" || req.ServiceFields == "" {
		response := ServiceResponse{
			Success: false,
			Error:   "Service name and fields are required",
		}
		json.NewEncoder(w).Encode(response)
		return
	}

	// Execute the gen_service.sh script
	cmd := exec.Command("./gen_service.sh", req.ServiceName, req.ServiceFields)
	cmd.Dir = ".." // Run from parent directory where gen_service.sh is located

	output, err := cmd.CombinedOutput()
	if err != nil {
		response := ServiceResponse{
			Success: false,
			Error:   fmt.Sprintf("Failed to create service: %v\nOutput: %s", err, string(output)),
		}
		json.NewEncoder(w).Encode(response)
		return
	}

	// Run make proto to generate the protocol buffer code
	protoCmd := exec.Command("make", "proto")
	protoCmd.Dir = ".."
	protoOutput, err := protoCmd.CombinedOutput()
	if err != nil {
		response := ServiceResponse{
			Success: false,
			Error:   fmt.Sprintf("Service created but proto generation failed: %v\nOutput: %s", err, string(protoOutput)),
		}
		json.NewEncoder(w).Encode(response)
		return
	}

	response := ServiceResponse{
		Success: true,
		Message: fmt.Sprintf("Service '%s' created successfully with fields: %s", req.ServiceName, req.ServiceFields),
	}
	json.NewEncoder(w).Encode(response)
}

func handleDeleteService(w http.ResponseWriter, r *http.Request) {
	// Extract service name from URL path
	pathParts := strings.Split(r.URL.Path, "/")
	if len(pathParts) < 4 {
		http.Error(w, "Invalid service name", http.StatusBadRequest)
		return
	}

	serviceName := pathParts[3] // /api/services/{serviceName}

	// Execute the gen_service.sh script with remove command
	cmd := exec.Command("./gen_service.sh", "remove", serviceName)
	cmd.Dir = ".." // Run from parent directory where gen_service.sh is located

	output, err := cmd.CombinedOutput()
	if err != nil {
		response := ServiceResponse{
			Success: false,
			Error:   fmt.Sprintf("Failed to remove service: %v\nOutput: %s", err, string(output)),
		}
		json.NewEncoder(w).Encode(response)
		return
	}

	// Run make proto to regenerate the protocol buffer code
	protoCmd := exec.Command("make", "proto")
	protoCmd.Dir = ".."
	protoOutput, err := protoCmd.CombinedOutput()
	if err != nil {
		response := ServiceResponse{
			Success: false,
			Error:   fmt.Sprintf("Service removed but proto regeneration failed: %v\nOutput: %s", err, string(protoOutput)),
		}
		json.NewEncoder(w).Encode(response)
		return
	}

	response := ServiceResponse{
		Success: true,
		Message: fmt.Sprintf("Service '%s' removed successfully", serviceName),
	}
	json.NewEncoder(w).Encode(response)
}

func discoverServices() ([]Service, error) {
	var services []Service

	// Look for proto files in the proto directory
	protoDir := "../proto"
	files, err := os.ReadDir(protoDir)
	if err != nil {
		return nil, fmt.Errorf("failed to read proto directory: %v", err)
	}

	for _, file := range files {
		if file.IsDir() || !strings.HasSuffix(file.Name(), ".proto") {
			continue
		}

		// Skip google API proto files
		if strings.Contains(file.Name(), "google") {
			continue
		}

		// Extract service name from filename
		serviceName := strings.TrimSuffix(file.Name(), ".proto")

		// Convert to PascalCase for display
		serviceName = strings.Title(serviceName)

		// Try to read the proto file to extract fields
		protoPath := filepath.Join(protoDir, file.Name())
		content, err := os.ReadFile(protoPath)
		if err != nil {
			continue
		}

		fields := extractFieldsFromProto(string(content))

		service := Service{
			Name:   serviceName,
			Fields: fields,
		}

		services = append(services, service)
	}

	return services, nil
}

func extractFieldsFromProto(content string) []string {
	var fields []string
	var inMessage bool

	lines := strings.Split(content, "\n")
	for _, line := range lines {
		line = strings.TrimSpace(line)

		// Check if we're entering a message definition
		if strings.HasPrefix(line, "message ") && strings.Contains(line, "{") {
			inMessage = true
			continue
		}

		// Check if we're leaving a message definition
		if inMessage && line == "}" {
			inMessage = false
			continue
		}

		// Only process lines inside message definitions
		if !inMessage {
			continue
		}

		// Look for field definitions (lines with type and field name)
		if strings.Contains(line, " = ") && !strings.HasPrefix(line, "//") && !strings.HasPrefix(line, "option") {
			// Extract field name and type
			parts := strings.Fields(line)
			if len(parts) >= 3 {
				fieldType := parts[0]
				fieldName := parts[1]

				// Skip the "id" field as it's always present
				if fieldName == "id" {
					continue
				}

				// Skip fields that don't look like proper field definitions
				if strings.Contains(fieldName, "(") || strings.Contains(fieldName, ")") {
					continue
				}

				// Clean up field name (remove trailing comma, semicolon, etc.)
				fieldName = strings.TrimRight(fieldName, ",;")

				// Only add if it looks like a valid field
				if fieldName != "" && fieldType != "" && !strings.Contains(fieldName, ":") {
					fields = append(fields, fmt.Sprintf("%s:%s", fieldName, fieldType))
				}
			}
		}
	}

	return fields
}
