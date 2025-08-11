package models

import (
	"time"
	"go.mongodb.org/mongo-driver/bson/primitive"
	"grpc_anotation_sample/pb"
)

// Product represents the product entity in the database
type Product struct {
	ID        string    `json:"id" bson:"_id"`
	Name string `json:"name" bson:"name"`
	Description string `json:"description" bson:"description"`
	Price float32 `json:"price" bson:"price"`
	Stock int32 `json:"stock" bson:"stock"`
	Categories []string `json:"categories" bson:"categories"`
	CreatedAt time.Time `json:"created_at" bson:"created_at"`
	UpdatedAt time.Time `json:"updated_at" bson:"updated_at"`
}

// NewProduct creates a new Product instance with default values
func NewProduct() *Product {
	return &Product{
		ID:        primitive.NewObjectID().Hex(),
		CreatedAt: time.Now(),
		UpdatedAt: time.Now(),
	}
}

// ToProto converts the model to a protobuf message
func (m *Product) ToProto() *pb.Product {
	proto := &pb.Product{
		Id: m.ID,
		Name: m.Name,
		Description: m.Description,
		Price: m.Price,
		Stock: m.Stock,
		Categories: m.Categories,
	}
	return proto
}

// FromProto creates a model from a protobuf message
func ProductFromProto(p *pb.Product) *Product {
	if p == nil {
		return nil
	}
	
	m := &Product{
		ID:        p.Id,
		Name: p.Name,
		Description: p.Description,
		Price: p.Price,
		Stock: p.Stock,
		Categories: p.Categories,
		CreatedAt: time.Now(),
		UpdatedAt: time.Now(),
	}
	
	return m
}

// CollectionName returns the MongoDB collection name for this model
func (Product) CollectionName() string {
	return "products"
}
