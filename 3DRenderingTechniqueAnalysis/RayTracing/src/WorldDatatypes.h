#pragma once
#include "olcPixelGameEngine.h"
#include "MathUtilities.cuh"

struct Player
{
	Vec3D coords;
	Quaternion q_direction;
	float FOV;
};

struct Sphere
{
	Vec3D coords;
	float radius;
	olc::Pixel color;
	float luminance = 0;
	// we'll put this in back later:    olc::Sprite* texture;
};

struct Triangle
{
	Vec3D vertices[3];
	Vec2D textureVertices[3];
	float luminance = 0;
};

// useful for texturing
struct VertexPair2D
{
	Vec2D vertices[2];
};

struct Light
{
	Vec3D coords;
	olc::Pixel color;
};