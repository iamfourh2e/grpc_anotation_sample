package main

import (
	"grpc_anotation_sample/server"
	"log"
)

const (
	grpcPort       = ":9090"
	gatewayAddress = "0.0.0.0"
)

// Health Check Endpoints:
// - gRPC: standard gRPC health check service (grpc_health_v1.Health)
// - HTTP: GET /healthz returns 200 OK with body 'ok'
func main() {
	go func() {
		err := server.StartGRPCServer(grpcPort)
		if err != nil {
			log.Fatalf("failed to start gRPC server: %v", err)
		}
	}()

	go func() {
		err := server.StartGatewayServer(grpcPort, gatewayAddress)
		if err != nil {
			log.Fatalf("failed to start gateway server: %v", err)
		}
	}()

	log.Printf("Servers started. gRPC at %s, Gateway at %s", grpcPort, gatewayAddress)
	select {}
}
