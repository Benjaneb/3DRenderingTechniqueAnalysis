#pragma once

#include <chrono>
#include "MathUtilities.cuh"
#include "olcPixelGameEngine.h"

struct Player
{
	Vec3D coords;
	Quaternion q_orientation;
	float FOV;
};

struct Material
{
	Vec3D emittance; // Measured from { 0, 0, 0 } to { infinity, infinity, infinity }
	Vec3D diffuseTint; // Measured from { 0, 0, 0 } to { 1, 1, 1 }
	Vec3D specularTint; // Measured from { 0, 0, 0 } to { 1, 1, 1 }
	float roughness; // Measured from 0 to 1
	float refractionIndex; // Measured from 0 to infinity
	Vec3D attenuation; // Measured from { 0, 0, 0 } to { infinity, infinity, infinity }
};

struct Sphere
{
	Vec3D coords;
	float radius;
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
	Material material;
	std::string meshPartName = "";
	olc::Sprite* texture = nullptr;
	Vec2D textureVertices[3] = { ZERO_VEC2D, ZERO_VEC2D, ZERO_VEC2D };
	olc::Sprite* normalMap = nullptr;
};

struct Ground
{
	float level;
	Material material;
	olc::Sprite* texture = nullptr;
	Vec2D textureCorner1 = ZERO_VEC2D;
	Vec2D textureCorner2 = ZERO_VEC2D;
	float textureScalar = 1;
	olc::Sprite* normalMap = nullptr;
};

struct Light // Only for distribution ray tracing
{
	Vec3D coords;
	float radius;
	Vec3D emittance;
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