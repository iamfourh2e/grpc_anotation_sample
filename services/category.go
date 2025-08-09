package services

import (
	"context"
	"grpc_anotation_sample/pb"
)

type CategoryService struct {
	pb.UnimplementedCategoryServiceServer
}

func NewCategoryService() *CategoryService {
	return &CategoryService{}
}

func (s *CategoryService) CreateCategory(ctx context.Context, req *pb.CreateCategoryRequest) (*pb.CreateCategoryResponse, error) {
	return &pb.CreateCategoryResponse{}, nil
}

func (s *CategoryService) GetCategory(ctx context.Context, req *pb.GetCategoryRequest) (*pb.GetCategoryResponse, error) {
	return &pb.GetCategoryResponse{}, nil
}

func (s *CategoryService) UpdateCategory(ctx context.Context, req *pb.UpdateCategoryRequest) (*pb.UpdateCategoryResponse, error) {
	return &pb.UpdateCategoryResponse{}, nil
}

func (s *CategoryService) DeleteCategory(ctx context.Context, req *pb.DeleteCategoryRequest) (*pb.DeleteCategoryResponse, error) {
	return &pb.DeleteCategoryResponse{}, nil
}

func (s *CategoryService) ListCategorys(ctx context.Context, req *pb.ListCategorysRequest) (*pb.ListCategorysResponse, error) {
	return &pb.ListCategorysResponse{}, nil
}
