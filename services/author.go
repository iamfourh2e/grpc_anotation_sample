package services

import (
	"context"
	"grpc_anotation_sample/pb"
)

type AuthorService struct {
	pb.UnimplementedAuthorServiceServer
}

func NewAuthorService() *AuthorService {
	return &AuthorService{}
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
