package server

import (
	"grpc_anotation_sample/pb"
	"grpc_anotation_sample/services"
	"log"
	"net"

	"google.golang.org/grpc"
)

func StartGRPCServer(port string) error {
	lis, err := net.Listen("tcp", port)
	if err != nil {
		log.Printf("Failed to listen: %v", err)
		return err
	}
	//call any client if needed
	//cc, err := CallClient("192.168.0.249:8000")

	// if err != nil {
	// 	log.Printf("Failed to call client: %v", err)
	// 	return err
	// }

	grpcServer := grpc.NewServer()

	pb.RegisterTodoServiceServer(grpcServer, services.NewTodoService())
	pb.RegisterHealthServer(grpcServer, services.NewHealthService())
	err = grpcServer.Serve(lis)
	if err != nil {
		log.Printf("Failed to serve: %v", err)
		return err
	}
	return nil
}

// func CallClient(ip string) (*grpc.ClientConn, error) {
// 	cc, err := grpc.NewClient(ip, grpc.WithTransportCredentials(insecure.NewCredentials()))
// 	if err != nil {
// 		return nil, err
// 	}
// 	return cc, nil
// }
