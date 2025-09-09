package service

import (
	"context"
	"log"
	"regexp"
	"time"

	pb "github.com/ruuke/flight_booking/flight_search_go/pkg/proto"
	"github.com/ruuke/flight_booking/flight_search_go/internal/store"
	"google.golang.org/protobuf/types/known/timestamppb"
)

const (
	minConnectionTime = 8 * time.Hour
	maxConnectionTime = 48 * time.Hour
)

// Server implements the gRPC server

type Server struct {
	pb.UnimplementedFlightSearchServiceServer
	db *store.DB
}

// NewServer creates a new server

func NewServer(db *store.DB) *Server {
	return &Server{db: db}
}

// SearchRoutes performs the flight search

func (s *Server) SearchRoutes(ctx context.Context, req *pb.SearchRequest) (*pb.SearchResponse, error) {
	log.Printf("SearchRoutes received: Carrier=%s, Origin=%s, Destination=%s, DepartureFrom=%s, DepartureTo=%s",
		req.Carrier, req.OriginIata, req.DestinationIata, req.DepartureFrom, req.DepartureTo)

	// 1. Find Permitted Route
	permittedRoute, err := s.db.FindPermittedRoute(req.Carrier, req.OriginIata, req.DestinationIata)
	if err != nil {
		log.Printf("FindPermittedRoute error: %v", err)
		// Handle not found as empty response, not an error
		return &pb.SearchResponse{}, nil
	}
	if permittedRoute == nil {
		log.Printf("No permitted route found for Carrier=%s, Origin=%s, Destination=%s", req.Carrier, req.OriginIata, req.DestinationIata)
		return &pb.SearchResponse{}, nil
	}
	log.Printf("Found permitted route: %+v", permittedRoute)

	// 2. Parse blueprint paths
	blueprintPaths := parseBlueprintPaths(permittedRoute)
	log.Printf("Generated blueprint paths: %+v", blueprintPaths)
	if len(blueprintPaths) == 0 {
		log.Println("No blueprint paths generated.")
		return &pb.SearchResponse{}, nil
	}

	// 3. Preload Segments
	segments, err := s.preloadSegments(req, blueprintPaths)
	if err != nil {
		log.Printf("PreloadSegments error: %v", err)
		return nil, err // Internal error
	}
	log.Printf("Preloaded %d segments.", len(segments))
	segmentsByOrigin := groupSegmentsByOrigin(segments)

	// 4. Build Itineraries
	itineraries := buildItineraries(req, blueprintPaths, segmentsByOrigin)
	log.Printf("Built %d itineraries.", len(itineraries))

	// 5. Format Response
	return formatResponse(itineraries), nil
}

func parseBlueprintPaths(route *store.PermittedRoute) [][]string {
	var paths [][]string
	if route.Direct {
		paths = append(paths, []string{route.OriginIATA, route.DestinationIATA})
	}
	re := regexp.MustCompile(`.{3}`)
	for _, code := range route.TransferIATACodes {
		if len(code)%3 == 0 {
			transfers := re.FindAllString(code, -1)
			if len(transfers) > 0 {
				path := []string{route.OriginIATA}
				path = append(path, transfers...)
				path = append(path, route.DestinationIATA)
				paths = append(paths, path)
			}
		}
	}
	return paths
}

func (s *Server) preloadSegments(req *pb.SearchRequest, blueprintPaths [][]string) ([]store.Segment, error) {
	airports := make(map[string]struct{})
	for _, path := range blueprintPaths {
		for _, airport := range path {
			airports[airport] = struct{}{}
		}
	}
	uniqueAirports := make([]string, 0, len(airports))
	for airport := range airports {
		uniqueAirports = append(uniqueAirports, airport)
	}

	from, _ := time.Parse("2006-01-02", req.DepartureFrom)
	to, _ := time.Parse("2006-01-02", req.DepartureTo)
	endDate := to.Add(48 * time.Hour)

	log.Printf("Preloading segments for Carrier=%s, Airports=%+v, From=%s, To=%s", req.Carrier, uniqueAirports, from.Format("2006-01-02"), endDate.Format("2006-01-02"))
	segments, err := s.db.FindSegmentsIn(req.Carrier, uniqueAirports, from, endDate)
	if err != nil {
		log.Printf("FindSegmentsIn error: %v", err)
		return nil, err
	}
	return segments, nil
}

func groupSegmentsByOrigin(segments []store.Segment) map[string][]store.Segment {
	grouped := make(map[string][]store.Segment)
	for _, s := range segments {
		grouped[s.OriginIATA] = append(grouped[s.OriginIATA], s)
	}
	return grouped
}

func buildItineraries(req *pb.SearchRequest, blueprintPaths [][]string, segmentsByOrigin map[string][]store.Segment) [][]*store.Segment {
	var finalItineraries [][]*store.Segment
	from, _ := time.Parse("2006-01-02", req.DepartureFrom)
	to, _ := time.Parse("2006-01-02", req.DepartureTo)

	log.Printf("Building itineraries for DepartureFrom=%s, DepartureTo=%s", from.Format("2006-01-02"), to.Format("2006-01-02"))
	for _, path := range blueprintPaths {
		log.Printf("  Processing blueprint path: %+v", path)
		findInitialSegments(path, segmentsByOrigin, from, to, &finalItineraries)
	}
	return finalItineraries
}

func findInitialSegments(path []string, segmentsByOrigin map[string][]store.Segment, from, to time.Time, finalItineraries *[][]*store.Segment) {
	if len(path) < 2 {
		return
	}
	origin := path[0]
	firstDest := path[1]

	log.Printf("  Finding initial segments from %s to %s, between %s and %s", origin, firstDest, from.Format("2006-01-02"), to.Format("2006-01-02"))
	for _, segment := range segmentsByOrigin[origin] {
		if segment.DestinationIATA == firstDest && (segment.STD.After(from) || segment.STD.Equal(from)) && (segment.STD.Before(to) || segment.STD.Equal(to)) {
			log.Printf("    Found initial segment: %+v", segment)
			findNextSegments(path[2:], []*store.Segment{&segment}, segmentsByOrigin, finalItineraries)
		}
	}
}

func findNextSegments(remainingAirports []string, currentItinerary []*store.Segment, segmentsByOrigin map[string][]store.Segment, finalItineraries *[][]*store.Segment) {
	if len(remainingAirports) == 0 {
		log.Printf("    Found complete itinerary: %+v", currentItinerary)
		*finalItineraries = append(*finalItineraries, currentItinerary)
		return
	}

	lastSegment := currentItinerary[len(currentItinerary)-1]
	nextOrigin := lastSegment.DestinationIATA
	nextDest := remainingAirports[0]

	log.Printf("    Finding next segments from %s to %s, after segment ending at %s", nextOrigin, nextDest, lastSegment.STA.Format("2006-01-02 15:04:05"))
	for _, segment := range segmentsByOrigin[nextOrigin] {
		if segment.DestinationIATA == nextDest {
			connectionTime := segment.STD.Sub(lastSegment.STA)
			log.Printf("      Checking connection time for segment %+v: %v (min: %v, max: %v)", segment, connectionTime, minConnectionTime, maxConnectionTime)
			if connectionTime >= minConnectionTime && connectionTime <= maxConnectionTime {
				newItinerary := append([]*store.Segment{}, currentItinerary...)
				newItinerary = append(newItinerary, &segment)
				findNextSegments(remainingAirports[1:], newItinerary, segmentsByOrigin, finalItineraries)
			}
		}
	}
}

func formatResponse(itineraries [][]*store.Segment) *pb.SearchResponse {
	resp := &pb.SearchResponse{}
	for _, itinerary := range itineraries {
		first := itinerary[0]
		last := itinerary[len(itinerary)-1]
		pbItinerary := &pb.Itinerary{
			OriginIata:      first.OriginIATA,
			DestinationIata: last.DestinationIATA,
			DepartureTime:   timestamppb.New(first.STD),
			ArrivalTime:     timestamppb.New(last.STA),
		}
		for _, s := range itinerary {
			pbItinerary.Segments = append(pbItinerary.Segments, &pb.Segment{
				Carrier:        s.Airline,
				SegmentNumber:  s.SegmentNumber,
				OriginIata:     s.OriginIATA,
				DestinationIata: s.DestinationIATA,
				Std:            timestamppb.New(s.STD),
				Sta:            timestamppb.New(s.STA),
			})
		}
		resp.Itineraries = append(resp.Itineraries, pbItinerary)
	}
	return resp
}