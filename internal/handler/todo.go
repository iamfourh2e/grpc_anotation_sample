package handler

import (
	"context"
	"grpc_anotation_sample/pb"
	"io"
	"log"
	"net/http"

	"github.com/gorilla/websocket"
	"google.golang.org/grpc"
)

var upgrader = websocket.Upgrader{
	CheckOrigin: func(r *http.Request) bool {
		return true
	},
}

func TodoStreamHandler(w http.ResponseWriter, r *http.Request, conn *grpc.ClientConn) {
	ws, err := upgrader.Upgrade(w, r, nil)
	if err != nil {
		log.Printf("failed to upgrade to websocket: %v", err)
		return
	}
	defer ws.Close()

	client := pb.NewTodoServiceClient(conn)
	stream, err := client.StreamTodos(context.Background(), &pb.StreamTodosRequest{})
	if err != nil {
		log.Printf("failed to create todo stream: %v", err)
		return
	}

	go func() {
		for {
			todo, err := stream.Recv()
			if err == io.EOF {
				return
			}
			if err != nil {
				log.Printf("failed to receive todo from stream: %v", err)
				return
			}
			if err := ws.WriteJSON(todo); err != nil {
				log.Printf("failed to write todo to websocket: %v", err)
				return
			}
		}
	}()

	for {
		_, _, err := ws.ReadMessage()
		if err != nil {
			if websocket.IsUnexpectedCloseError(err, websocket.CloseGoingAway, websocket.CloseAbnormalClosure) {
				log.Printf("error reading from websocket: %v", err)
			}
			break
		}
	}
}
