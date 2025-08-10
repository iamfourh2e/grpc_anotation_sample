package server

import (
	"context"
	"grpc_anotation_sample/pb"
	"grpc_anotation_sample/services"
	"log"
	"net"
	"os"

	"github.com/joho/godotenv"
	"go.mongodb.org/mongo-driver/mongo"
	"go.mongodb.org/mongo-driver/mongo/options"
	"google.golang.org/grpc"
)

func StartGRPCServer(port string) error {
	//load env
	err := godotenv.Load()
	if err != nil {
		log.Printf("Failed to load env: %v", err)
		return err
	}
	mongoUrl := os.Getenv("MONGO_URL")
	dbName := os.Getenv("DB_NAME")
	//load mongo client
	client, err := mongo.Connect(context.Background(), options.Client().ApplyURI(mongoUrl))
	if err != nil {
		log.Printf("Failed to connect to mongo: %v", err)
		return err
	}

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
	pb.RegisterCategoryServiceServer(grpcServer, services.NewCategoryService())
	pb.RegisterAuthorServiceServer(grpcServer, services.NewAuthorService())
	pb.RegisterBookServiceServer(grpcServer, services.NewBookService(client, dbName))

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
