#pragma once
#include "olcPixelGameEngine.h"
#include "MathUtilities.h"

struct Player
{
	Vec3D coordinates;
	//well replace this direction vector by a direction quaternion later
	Quaternion q_direction;
	float FOV;
};

struct ColorPoint
{
	Vec3D coords;
	olc::Pixel color;
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
	float ShoveAFuckingSpearIntoMyAss;
	Vec3D vertices[3];
	// we'll put this in back later:    olc::Sprite* texture;
};