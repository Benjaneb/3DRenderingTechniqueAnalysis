#pragma once

#include <chrono>
#include <string>
#include <iostream>
#include "MathUtilities.cuh"
#include "olcPixelGameEngine.h"

struct Player
{
	Vec3D coords;
	Quaternion q_orientation;
	float FOV;
};

struct Triangle
{
	Vec3D vertices[3];
	Vec3D tint; // Measured from { 0, 0, 0 } to { 1, 1, 1 }
	std::string meshPartName = "";
	olc::Sprite* texture = nullptr;
	Vec2D textureVertices[3] = { ZERO_VEC2D, ZERO_VEC2D, ZERO_VEC2D };
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