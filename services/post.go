package services

import (
	"context"
	"grpc_anotation_sample/pb"
)

type PostService struct {
	pb.UnimplementedPostServiceServer
}

func NewPostService() *PostService {
	return &PostService{}
}

func (s *PostService) CreatePost(ctx context.Context, req *pb.CreatePostRequest) (*pb.CreatePostResponse, error) {
	return &pb.CreatePostResponse{}, nil
}

func (s *PostService) GetPost(ctx context.Context, req *pb.GetPostRequest) (*pb.GetPostResponse, error) {
	return &pb.GetPostResponse{}, nil
}

func (s *PostService) UpdatePost(ctx context.Context, req *pb.UpdatePostRequest) (*pb.UpdatePostResponse, error) {
	return &pb.UpdatePostResponse{}, nil
}

func (s *PostService) DeletePost(ctx context.Context, req *pb.DeletePostRequest) (*pb.DeletePostResponse, error) {
	return &pb.DeletePostResponse{}, nil
}

func (s *PostService) ListPosts(ctx context.Context, req *pb.ListPostsRequest) (*pb.ListPostsResponse, error) {
	return &pb.ListPostsResponse{}, nil
}
