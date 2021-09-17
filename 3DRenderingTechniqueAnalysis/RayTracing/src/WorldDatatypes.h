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
	Vec3D tint;
	float emittance;
	float reflectance;
	// we'll put this in back later:    olc::Sprite* texture;
};

struct Triangle
{
	Vec3D vertices[3];
	Vec3D tint;
	float emittance;
	float reflectance;
	olc::Sprite* texture = nullptr;
	Vec2D textureVertices[3] = { { 0, 1 }, { 0, 0 }, { 1, 0 } };
};

struct Ground
{
	float level;
	Vec3D tint;
	float emittance;
	float reflectance;
	olc::Sprite* texture = nullptr;
	Vec2D textureCorner1 = { 0, 0 };
	Vec2D textureCorner2 = { 1, 1 };
	float textureScalar = 1;
};
