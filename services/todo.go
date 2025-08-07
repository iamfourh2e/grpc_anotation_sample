package services

import (
	"context"
	"grpc_anotation_sample/pb"
	"log"
	"sync"
	"time"

	"github.com/google/uuid"
	"go.mongodb.org/mongo-driver/mongo"
)

type TodoService struct {
	pb.UnimplementedTodoServiceServer
	mu      sync.Mutex
	todos   []*pb.Todo
	streams []chan *pb.Todo
	Client  *mongo.Client
}

func NewTodoService() *TodoService {
	return &TodoService{
		todos:   []*pb.Todo{},
		streams: []chan *pb.Todo{},
	}
}

func (s *TodoService) CreateTodo(ctx context.Context, req *pb.CreateTodoRequest) (*pb.CreateTodoResponse, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	todo := &pb.Todo{
		Id:        uuid.New().String(),
		Title:     req.GetTitle(),
		Completed: false,
	}
	s.todos = append(s.todos, todo)

	for _, stream := range s.streams {
		stream <- todo
	}

	return &pb.CreateTodoResponse{Todo: todo}, nil
}

func (s *TodoService) StreamTodos(req *pb.StreamTodosRequest, stream pb.TodoService_StreamTodosServer) error {
	s.mu.Lock()
	ch := make(chan *pb.Todo, 10) // Buffered channel
	s.streams = append(s.streams, ch)
	s.mu.Unlock()

	defer func() {
		s.mu.Lock()
		// Remove the channel from the streams slice
		for i, c := range s.streams {
			if c == ch {
				s.streams = append(s.streams[:i], s.streams[i+1:]...)
				break
			}
		}
		close(ch)
		s.mu.Unlock()
		log.Println("Closing stream")
	}()

	// Send existing todos
	for _, todo := range s.todos {
		if err := stream.Send(todo); err != nil {
			log.Printf("Error sending existing todo to stream: %v", err)
			return err
		}
	}

	for {
		select {
		case <-stream.Context().Done():
			log.Println("Stream context done")
			return nil
		case todo := <-ch:
			log.Printf("Sending new todo to stream: %v", todo.Title)
			if err := stream.Send(todo); err != nil {
				log.Printf("Error sending new todo to stream: %v", err)
				return err
			}
		case <-time.After(30 * time.Second):
			// Keep alive
			if err := stream.Send(&pb.Todo{}); err != nil {
				log.Printf("Failed to send keep-alive: %v, closing stream", err)
				return err
			}
		}
	}
}
