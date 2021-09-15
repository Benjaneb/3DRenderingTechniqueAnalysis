#pragma once
#include "olcPixelGameEngine.h"
#include "MathUtilities.cuh"

struct Player
{
	Vec3D coords;
	Quaternion q_orientation;
	float FOV;
};

struct Sphere
{
	Vec3D coords;
	float radius;
	Vec3D color;
	float emittance;
	float reflectance;
	// we'll put this in back later:    olc::Sprite* texture;
};

struct Triangle
{
	Vec3D vertices[3];
	Vec2D textureVertices[3];
	float emittance;
	float reflectance;
};

// useful for texturing
struct VertexPair2D
{
	Vec2D vertices[2];
};
