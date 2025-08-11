package models

import (
	"time"
	"go.mongodb.org/mongo-driver/bson/primitive"
	"grpc_anotation_sample/pb"
)

// Testservice represents the testservice entity in the database
type Testservice struct {
	ID        string    `json:"id" bson:"_id"`
	Name string `json:"name" bson:"name"`
	Age int32 `json:"age" bson:"age"`
	CreatedAt time.Time `json:"created_at" bson:"created_at"`
	UpdatedAt time.Time `json:"updated_at" bson:"updated_at"`
}

// NewTestservice creates a new Testservice instance with default values
func NewTestservice() *Testservice {
	return &Testservice{
		ID:        primitive.NewObjectID().Hex(),
		CreatedAt: time.Now(),
		UpdatedAt: time.Now(),
	}
}

// ToProto converts the model to a protobuf message
func (m *Testservice) ToProto() *pb.Testservice {
	proto := &pb.Testservice{
		Id: m.ID,
		Name: m.Name,
		Age: m.Age,
	}
	return proto
}

// FromProto creates a model from a protobuf message
func TestserviceFromProto(p *pb.Testservice) *Testservice {
	if p == nil {
		return nil
	}
	
	m := &Testservice{
		ID:        p.Id,
		Name: p.Name,
		Age: p.Age,
		CreatedAt: time.Now(),
		UpdatedAt: time.Now(),
	}
	
	return m
}

// CollectionName returns the MongoDB collection name for this model
func (Testservice) CollectionName() string {
	return "testservices"
}
