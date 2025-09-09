package store

import (
	"database/sql/driver"
	"encoding/json"
	"fmt"
	"time"

	"strings"

	"github.com/jmoiron/sqlx"
	_ "github.com/lib/pq"
)

// StringArray is a custom type for []string that implements sql.Scanner and driver.Valuer
type StringArray []string

// Scan implements the sql.Scanner interface.
func (sa *StringArray) Scan(value interface{}) error {
	if value == nil {
		*sa = nil
		return nil
	}

	s, ok := value.([]byte)
	if !ok {
		return fmt.Errorf("Scan source was not []byte")
	}

	// Raw value in Scan: {OVB,KHV,IKT,VVOOVB}
	// Parse PostgreSQL array literal
	strValue := string(s)
	strValue = strings.TrimPrefix(strValue, "{")
	strValue = strings.TrimSuffix(strValue, "}")
	
	if strValue == "" { // Handle empty array {}
		*sa = []string{}
		return nil
	}

	*sa = strings.Split(strValue, ",")

	return nil // No JSON unmarshal needed
}

// Value implements the driver.Valuer interface.
func (sa StringArray) Value() (driver.Value, error) {
	if sa == nil {
		return nil, nil
	}
	return json.Marshal(sa)
}

// Segment corresponds to the segments table

type Segment struct {
	ID              int       `db:"id"`
	Airline         string    `db:"airline"`
	SegmentNumber   string    `db:"segment_number"`
	OriginIATA      string    `db:"origin_iata"`
	DestinationIATA string    `db:"destination_iata"`
	STD             time.Time `db:"std"`
	STA             time.Time `db:"sta"`
	CreatedAt       time.Time `db:"created_at"`
	UpdatedAt       time.Time `db:"updated_at"`
}

// PermittedRoute corresponds to the permitted_routes table

type PermittedRoute struct {
	ID                int64    `db:"id"`
	Carrier           string   `db:"carrier"`
	OriginIATA        string   `db:"origin_iata"`
	DestinationIATA   string   `db:"destination_iata"`
	Direct            bool     `db:"direct"`
	TransferIATACodes StringArray `db:"transfer_iata_codes"` // Use custom type
	CreatedAt         time.Time `db:"created_at"`
	UpdatedAt         time.Time `db:"updated_at"`
}

// DB holds the database connection

type DB struct {
	*sqlx.DB
}

// NewDB creates a new database connection

func NewDB(dataSourceName string) (*DB, error) {
	db, err := sqlx.Connect("postgres", dataSourceName)
	if err != nil {
		return nil, err
	}
	return &DB{db}, nil
}

// FindPermittedRoute finds a single permitted route

func (db *DB) FindPermittedRoute(carrier, origin, destination string) (*PermittedRoute, error) {
	var route PermittedRoute
	query := `SELECT * FROM permitted_routes WHERE carrier=$1 AND origin_iata=$2 AND destination_iata=$3 LIMIT 1`
	err := db.Get(&route, query, carrier, origin, destination)
	if err != nil {
		return nil, err
	}
	return &route, nil
}

// FindSegmentsIn finds all segments matching the criteria

func (db *DB) FindSegmentsIn(carrier string, airports []string, from, to time.Time) ([]Segment, error) {
	var segments []Segment
	query, args, err := sqlx.In(`SELECT * FROM segments WHERE airline=? AND origin_iata IN (?) AND std BETWEEN ? AND ?`, carrier, airports, from, to)
	if err != nil {
		return nil, err
	}
	query = db.Rebind(query)
	err = db.Select(&segments, query, args...)
	if err != nil {
		return nil, err
	}
	return segments, nil
}


