package services

import (
	"context"
	"grpc_anotation_sample/pb"
)

type BookService struct {
	pb.UnimplementedBookServiceServer
}

func NewBookService() *BookService {
	return &BookService{}
}

func (s *BookService) CreateBook(ctx context.Context, req *pb.CreateBookRequest) (*pb.CreateBookResponse, error) {
	return &pb.CreateBookResponse{}, nil
}

func (s *BookService) GetBook(ctx context.Context, req *pb.GetBookRequest) (*pb.GetBookResponse, error) {
	return &pb.GetBookResponse{}, nil
}

func (s *BookService) UpdateBook(ctx context.Context, req *pb.UpdateBookRequest) (*pb.UpdateBookResponse, error) {
	return &pb.UpdateBookResponse{}, nil
}

func (s *BookService) DeleteBook(ctx context.Context, req *pb.DeleteBookRequest) (*pb.DeleteBookResponse, error) {
	return &pb.DeleteBookResponse{}, nil
}

func (s *BookService) ListBooks(ctx context.Context, req *pb.ListBooksRequest) (*pb.ListBooksResponse, error) {
	return &pb.ListBooksResponse{}, nil
}
