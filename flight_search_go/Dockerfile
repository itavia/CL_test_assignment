# Stage 1: Build the application
FROM golang:1.19-alpine AS builder

WORKDIR /app

# Install gRPC tools
RUN apk add --no-cache protobuf-dev
RUN go install google.golang.org/protobuf/cmd/protoc-gen-go@v1.28
RUN go install google.golang.org/grpc/cmd/protoc-gen-go-grpc@v1.2
ENV PATH="$PATH:/go/bin"

# Copy proto file and generate Go gRPC code
COPY pkg/proto/flight_search.proto pkg/proto/flight_search.proto
RUN protoc --go_out=. --go_opt=paths=source_relative \
    --go-grpc_out=. --go-grpc_opt=paths=source_relative \
    pkg/proto/flight_search.proto

# Copy go.mod and go.sum files
COPY go.mod ./
# Download all dependencies and populate go.sum
RUN go mod download

# Copy the rest of the source code
COPY . .

# Build the application
RUN CGO_ENABLED=0 GOOS=linux go build -mod=mod -a -installsuffix cgo -o main ./cmd/server


# Stage 2: Create the final, small image
FROM alpine:latest

RUN apk --no-cache add ca-certificates

WORKDIR /root/

# Copy the pre-built binary from the builder stage
COPY --from=builder /app/main .

# Expose port for the gRPC server
EXPOSE 50051

# Command to run the executable
CMD ["./main"]
