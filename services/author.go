package services

import (
	"context"
	"grpc_anotation_sample/pb"

	"go.mongodb.org/mongo-driver/mongo"
)

type AuthorService struct {
	pb.UnimplementedAuthorServiceServer
	Client  *mongo.Client
	AuthCol *mongo.Collection
}

func NewAuthorService(client *mongo.Client, dbName string) *AuthorService {
	col := client.Database(dbName).Collection("authors")
	return &AuthorService{
		Client:  client,
		AuthCol: col,
	}
}

func (s *AuthorService) CreateAuthor(ctx context.Context, req *pb.CreateAuthorRequest) (*pb.CreateAuthorResponse, error) {
	return &pb.CreateAuthorResponse{}, nil
}

func (s *AuthorService) GetAuthor(ctx context.Context, req *pb.GetAuthorRequest) (*pb.GetAuthorResponse, error) {
	return &pb.GetAuthorResponse{}, nil
}

func (s *AuthorService) UpdateAuthor(ctx context.Context, req *pb.UpdateAuthorRequest) (*pb.UpdateAuthorResponse, error) {
	return &pb.UpdateAuthorResponse{}, nil
}

func (s *AuthorService) DeleteAuthor(ctx context.Context, req *pb.DeleteAuthorRequest) (*pb.DeleteAuthorResponse, error) {
	return &pb.DeleteAuthorResponse{}, nil
}

func (s *AuthorService) ListAuthors(ctx context.Context, req *pb.ListAuthorsRequest) (*pb.ListAuthorsResponse, error) {
	return &pb.ListAuthorsResponse{}, nil
}
