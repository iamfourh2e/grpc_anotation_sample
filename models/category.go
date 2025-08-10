package models

import (
	"grpc_anotation_sample/pb"
	"time"

	"go.mongodb.org/mongo-driver/bson/primitive"
)

// Category represents the category entity in the database
type Category struct {
	ID        string    `json:"id" bson:"_id"`
	Name      string    `json:"name" bson:"name"`
	Parents   []string  `json:"parents" bson:"parents"`
	Desc      string    `json:"desc" bson:"desc"`
	CreatedAt time.Time `json:"created_at" bson:"created_at"`
	UpdatedAt time.Time `json:"updated_at" bson:"updated_at"`
}

// NewCategory creates a new Category instance with default values
func NewCategory() *Category {
	return &Category{
		ID:        primitive.NewObjectID().Hex(),
		CreatedAt: time.Now(),
		UpdatedAt: time.Now(),
	}
}

// ToProto converts the model to a protobuf message
func (m *Category) ToProto() *pb.Category {
	proto := &pb.Category{
		Id:      m.ID,
		Name:    m.Name,
		Parents: m.Parents,
		Desc:    m.Desc,
	}
	return proto
}

// FromProto creates a model from a protobuf message
func CategoryFromProto(p *pb.Category) *Category {
	if p == nil {
		return nil
	}

	m := &Category{
		ID:        p.Id,
		Name:      p.Name,
		Parents:   p.Parents,
		Desc:      p.Desc,
		CreatedAt: time.Now(),
		UpdatedAt: time.Now(),
	}

	return m
}

// CollectionName returns the MongoDB collection name for this model
func (Category) CollectionName() string {
	return "categories"
}
