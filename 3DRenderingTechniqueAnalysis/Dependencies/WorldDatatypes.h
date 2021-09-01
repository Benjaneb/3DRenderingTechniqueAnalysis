#pragma once
#include "olcPixelGameEngine.h"
#include "MathUtilities.h"

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
	// we'll put this in back later:    olc::Sprite* texture;
};

struct Triangle
{
	Vec3D vertices[3];
	// we'll put this in back later:    olc::Sprite* texture;
};

struct Light
{
	Vec3D coords;
	olc::Pixel color;
};