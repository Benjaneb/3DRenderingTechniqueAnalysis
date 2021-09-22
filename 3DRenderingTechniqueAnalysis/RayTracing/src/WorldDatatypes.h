#pragma once
#include "olcPixelGameEngine.h"
#include "MathUtilities.cuh"

struct Player
{
	Vec3D coords;
	Quaternion q_orientation;
	float FOV;
};

struct Material
{
	Vec3D tint;
	float emittance;
	float reflectance;
	std::string name = ""; // Used for scene grouping in OBJ-files
};

struct Sphere
{
	Vec3D coords;
	float radius;
	Material material;
	olc::Sprite* texture = nullptr;
	Vec2D textureCorner1 = { 0, 0 };
	Vec2D textureCorner2 = { 1, 1 };
	Quaternion rotQuaternion = IDENTITY_QUATERNION;
};

struct Triangle
{
	Vec3D vertices[3];
	Material material;
	olc::Sprite* texture = nullptr;
	Vec2D textureVertices[3] = { { 0, 1 }, { 0, 0 }, { 1, 0 } };
};

struct Ground
{
	float level;
	Material material;
	olc::Sprite* texture = nullptr;
	Vec2D textureCorner1 = { 0, 0 };
	Vec2D textureCorner2 = { 1, 1 };
	float textureScalar = 1;
};