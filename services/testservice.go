package services

import (
	"context"
	"grpc_anotation_sample/pb"
)

type TestserviceService struct {
	pb.UnimplementedTestserviceServiceServer
}

func NewTestserviceService() *TestserviceService {
	return &TestserviceService{}
}

func (s *TestserviceService) CreateTestservice(ctx context.Context, req *pb.CreateTestserviceRequest) (*pb.CreateTestserviceResponse, error) {
	return &pb.CreateTestserviceResponse{}, nil
}

func (s *TestserviceService) GetTestservice(ctx context.Context, req *pb.GetTestserviceRequest) (*pb.GetTestserviceResponse, error) {
	return &pb.GetTestserviceResponse{}, nil
}

func (s *TestserviceService) UpdateTestservice(ctx context.Context, req *pb.UpdateTestserviceRequest) (*pb.UpdateTestserviceResponse, error) {
	return &pb.UpdateTestserviceResponse{}, nil
}

func (s *TestserviceService) DeleteTestservice(ctx context.Context, req *pb.DeleteTestserviceRequest) (*pb.DeleteTestserviceResponse, error) {
	return &pb.DeleteTestserviceResponse{}, nil
}

func (s *TestserviceService) ListTestservices(ctx context.Context, req *pb.ListTestservicesRequest) (*pb.ListTestservicesResponse, error) {
	return &pb.ListTestservicesResponse{}, nil
}
