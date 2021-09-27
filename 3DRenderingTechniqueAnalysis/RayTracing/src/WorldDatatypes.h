#pragma once
#include "olcPixelGameEngine.h"
#include "MathUtilities.cuh"

struct Player
{
	Vec3D coords;
	Quaternion q_orientation;
	float FOV;
};

enum MaterialType
{
	LAMBERTIAN,
	GLOSSY
};

struct MaterialProperties
{
	MaterialType materialType;
	float emittance; // Measured from 0 to infinity
	float reflectance; // Measured from 0 to infinity
	float roughness = 0; // Measured from 0 to 1
};

struct Sphere
{
	Vec3D coords;
	float radius;
	Vec3D tint; // Measured from { 0, 0, 0 } to { 1, 1, 1 }
	MaterialProperties material;
	olc::Sprite* texture = nullptr;
	olc::Sprite* normalMap = nullptr;
	Vec2D textureCorner1 = { 0, 0 };
	Vec2D textureCorner2 = { 1, 1 };
	Vec2D normalMapCorner1 = { 0, 0 };
	Vec2D normalMapCorner2 = { 1, 1 };
	Quaternion rotQuaternion = IDENTITY_QUATERNION;
};

struct Triangle
{
	Vec3D vertices[3];
	Vec3D tint; // Measured from { 0, 0, 0 } to { 1, 1, 1 }
	MaterialProperties material;
	olc::Sprite* texture = nullptr;
	olc::Sprite* normalMap = nullptr;
	Vec2D textureVertices[3] = { { 0, 1 }, { 0, 0 }, { 1, 0 } };
	Vec2D normalMapVertices[3] = { { 0, 1 }, { 0, 0 }, { 1, 0 } };
};

struct Ground
{
	float level;
	Vec3D tint; // Measured from { 0, 0, 0 } to { 1, 1, 1 }
	MaterialProperties material;
	olc::Sprite* texture = nullptr;
	olc::Sprite* normalMap = nullptr;
	Vec2D textureCorner1 = { 0, 0 };
	Vec2D textureCorner2 = { 1, 1 };
	Vec2D normalMapCorner1 = { 0, 0 };
	Vec2D normalMapCorner2 = { 1, 1 };
	float textureScalar = 1;
};