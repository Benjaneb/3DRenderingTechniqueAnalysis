#pragma once

#define FUCK_SHIT
#define STANDARD_MATERIAL { LAMBERTIAN, 0.1, 0.3 }

#include <chrono>
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

struct Material
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
	Material material;
	olc::Sprite* texture = nullptr;
	Vec2D textureCorner1 = ZERO_VEC2D;
	Vec2D textureCorner2 = ZERO_VEC2D;
	Quaternion rotQuaternion = IDENTITY_QUATERNION;
	olc::Sprite* normalMap = nullptr;
};

struct Triangle
{
	Vec3D vertices[3];
	Vec3D tint; // Measured from { 0, 0, 0 } to { 1, 1, 1 }
	Material material;
	std::string meshPartName = "";
	olc::Sprite* texture = nullptr;
	Vec2D textureVertices[3] = { ZERO_VEC2D, ZERO_VEC2D, ZERO_VEC2D };
	olc::Sprite* normalMap = nullptr;
};

struct Ground
{
	float level;
	Vec3D tint; // Measured from { 0, 0, 0 } to { 1, 1, 1 }
	Material material;
	olc::Sprite* texture = nullptr;
	Vec2D textureCorner1 = ZERO_VEC2D;
	Vec2D textureCorner2 = ZERO_VEC2D;
	float textureScalar = 1;
	olc::Sprite* normalMap = nullptr;
};

struct Timer
{
	std::chrono::time_point<std::chrono::steady_clock> start, end;
	std::chrono::duration<float> duration;
	std::string task;

	Timer(std::string _task)
	{
		start = std::chrono::high_resolution_clock::now();
		task = _task;
	}

	~Timer()
	{
		end = std::chrono::high_resolution_clock::now();
		duration = end - start;
		float ms = duration.count() * 1000.0f;
		std::cout << task << " took: " << ms << "ms" << std::endl;
	}
};