package main

import (
	"fmt"
	"log"
	"net"
	"os"

	"google.golang.org/grpc"
	"github.com/ruuke/flight_booking/flight_search_go/internal/service"
	"github.com/ruuke/flight_booking/flight_search_go/internal/store"
	pb "github.com/ruuke/flight_booking/flight_search_go/pkg/proto"
)

func main() {
	// Get config from environment variables
	dbURL := os.Getenv("DATABASE_URL")
	if dbURL == "" {
		log.Fatal("DATABASE_URL environment variable is not set")
	}
	grpcPort := os.Getenv("GRPC_PORT")
	if grpcPort == "" {
		grpcPort = "50051"
	}

	// Set up database connection
	db, err := store.NewDB(dbURL)
	if err != nil {
		log.Fatalf("failed to connect to database: %v", err)
	}

	// Set up gRPC server
	lis, err := net.Listen("tcp", fmt.Sprintf(":%s", grpcPort))
	if err != nil {
		log.Fatalf("failed to listen: %v", err)
	}

	s := grpc.NewServer()
	flightServer := service.NewServer(db)
	pb.RegisterFlightSearchServiceServer(s, flightServer)

	log.Printf("gRPC server listening at %v", lis.Addr())
	if err := s.Serve(lis); err != nil {
		log.Fatalf("failed to serve: %v", err)
	}
}