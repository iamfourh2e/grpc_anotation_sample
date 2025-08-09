package server

import (
	"context"
	"fmt"
	"grpc_anotation_sample/internal/handler"
	"grpc_anotation_sample/pb"
	"log"
	"net/http"
	"strings"

	"github.com/grpc-ecosystem/grpc-gateway/v2/runtime"
	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials/insecure"
)

func StartGatewayServer(grpcPort, gatewayAddress string) error {
	ctx := context.Background()
	ctx, cancel := context.WithCancel(ctx)
	defer cancel()

	mux := runtime.NewServeMux()
	opts := []grpc.DialOption{grpc.WithTransportCredentials(insecure.NewCredentials())}
	ip := fmt.Sprintf("%s%s", gatewayAddress, grpcPort)
	conn, err := grpc.NewClient(ip, opts...)
	if err != nil {
		return err
	}
	defer conn.Close()

	if err = pb.RegisterAuthorServiceHandler(ctx, mux, conn); err != nil {
		return err
	}



	if err = pb.RegisterCategoryServiceHandler(ctx, mux, conn); err != nil {
		return err
	}

	if err = pb.RegisterPostServiceHandler(ctx, mux, conn); err != nil {
		return err
	}

	if err = pb.RegisterTodoServiceHandler(ctx, mux, conn); err != nil {
		return err
	}
	if err = pb.RegisterBookServiceHandler(ctx, mux, conn); err != nil {
		return err
	}
	if err = pb.RegisterHealthHandler(ctx, mux, conn); err != nil {
		return err
	}

	// Serve the swagger-ui
	httpMux := http.NewServeMux()
	httpMux.Handle("/", mux)
	httpMux.HandleFunc("/v1/todos/stream", func(w http.ResponseWriter, r *http.Request) {
		handler.TodoStreamHandler(w, r, conn)
	})
	// Add HTTP health check endpoint
	httpMux.HandleFunc("/healthz", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		w.Write([]byte("ok"))
	})

	log.Printf("HTTP gateway server listening at %v", gatewayAddress+":8080")
	return http.ListenAndServe(gatewayAddress+":8080", allowCORS(httpMux))
}

func allowCORS(h http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		// if origin := r.Header.Get("Origin"); origin != "" {
		//     w.Header().Set("Access-Control-Allow-Origin", origin)
		//     if r.Method == "OPTIONS" && r.Header.Get("Access-Control-Request-Method") != "" {
		//         preflightHandler(w, r)
		//         return
		//     }
		w.Header().Set("Access-Control-Allow-Origin", "*")
		if r.Method == "OPTIONS" && r.Header.Get("Access-Control-Request-Method") != "" {
			preflightHandler(w, r)
			return
		}
		h.ServeHTTP(w, r)
	})
}

func preflightHandler(w http.ResponseWriter, _ *http.Request) {
	headers := []string{"Content-Type", "Accept", "Authorization"}
	w.Header().Set("Access-Control-Allow-Headers", strings.Join(headers, ","))
	methods := []string{"GET", "HEAD", "POST", "PUT", "DELETE"}
	w.Header().Set("Access-Control-Allow-Methods", strings.Join(methods, ","))
}
