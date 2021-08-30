#pragma once
#include "olcPixelGameEngine.h"
#include "MathUtilities.h"

struct ColorPoint
{
	Vec3d coords;
	olc::Pixel color;
};

struct Sphere
{
	Vec3D midPoint;
	float radius;
	olc::Pixel color;
}

struct Triangle
{
	Vec3D vertices[3];
	olc::Sprite* texture;
}