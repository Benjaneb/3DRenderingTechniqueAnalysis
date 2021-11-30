#define OLC_PGE_APPLICATION
#define RASTERIZER

#define SCREEN_WIDTH 1280
#define SCREEN_HEIGHT 720

#include <iostream>
#include <vector>
#include <algorithm>

#include "olcPixelGameEngine.h"

#include "MathUtilities.cuh"
#include "WorldDatatypes.h"
//#include "ParseOBJ.h"

// Global variables
std::vector<Triangle> g_triangles;

Vec3D g_pixels[SCREEN_WIDTH * SCREEN_HEIGHT]; // All pixels that'll be drawn
float g_depthbuffer[SCREEN_WIDTH * SCREEN_HEIGHT]; // Distance toward the object drawn on each pixel

// Textures
olc::Sprite* g_planks_texture;
olc::Sprite* g_concrete_texture;
olc::Sprite* g_tiledfloor_texture;
olc::Sprite* g_worldmap_texture;
olc::Sprite* g_gold_texture;
olc::Sprite* g_bricks_texture;

olc::Sprite* g_planks_normalmap;
olc::Sprite* g_concrete_normalmap;
olc::Sprite* g_tiledfloor_normalmap;
olc::Sprite* g_bricks_normalmap;

namespace Options
{
	bool mcControls = true;
}

class Engine : public olc::PixelGameEngine
{
public:
	Engine()
	{
		sAppName = "Rasterization_Engine";
	}

	bool OnUserCreate() override
	{
		g_planks_texture = new olc::Sprite("../Assets/planks.png");
		//g_concrete_texture = new olc::Sprite("../Assets/concrete.png");
		//g_tiledfloor_texture = new olc::Sprite("../Assets/tiledfloor.png");
		//g_worldmap_texture = new olc::Sprite("../Assets/worldmap.png");
		//g_gold_texture = new olc::Sprite("../Assets/gold.png");
		//g_bricks_texture = new olc::Sprite("../Assets/bricks.png");

		//g_planks_normalmap = new olc::Sprite("../Assets/planks_normalmap.png");
		//g_concrete_normalmap = new olc::Sprite("../Assets/concrete_normalmap.png");
		//g_tiledfloor_normalmap = new olc::Sprite("../Assets/tiledfloor_normalmap.png");
		//g_bricks_normalmap = new olc::Sprite("../Assets/bricks_normalmap.png");

		g_triangles =
		{
			// Box back face
			{ { { 0, 1, 4 }, { 1, 2, 4 }, { 0, 2, 4 } }, { 1, 1, 1 }, "", g_planks_texture, { { 0, 1 }, { 0, 0 }, { 1, 0 } }, g_planks_normalmap },
			{ { { 0, 1, 4 }, { 1, 1, 4 }, { 1, 2, 4 } }, { 1, 1, 1 }, "", g_planks_texture, { { 0, 1 }, { 1, 0 }, { 1, 1 } }, g_planks_normalmap },
			// Box front face
			{ { { 0, 1, 3 }, { 0, 2, 3 }, { 1, 2, 3 } }, { 1, 1, 1 }, "", g_planks_texture, { { 0, 1 }, { 0, 0 }, { 1, 0 } }, g_planks_normalmap },
			{ { { 0, 1, 3 }, { 1, 2, 3 }, { 1, 1, 3 } }, { 1, 1, 1 }, "", g_planks_texture, { { 0, 1 }, { 1, 0 }, { 1, 1 } }, g_planks_normalmap },
			// Box left face
			{ { { 0, 1, 3 }, { 0, 2, 4 }, { 0, 2, 3 } }, { 1, 1, 1 }, "", g_planks_texture, { { 0, 1 }, { 0, 0 }, { 1, 0 } }, g_planks_normalmap },
			{ { { 0, 1, 3 }, { 0, 1, 4 }, { 0, 2, 4 } }, { 1, 1, 1 }, "", g_planks_texture, { { 0, 1 }, { 1, 0 }, { 1, 1 } }, g_planks_normalmap },
			// Box right face							   
			{ { { 1, 1, 3 }, { 1, 2, 3 }, { 1, 2, 4 } }, { 1, 1, 1 }, "", g_planks_texture, { { 0, 1 }, { 0, 0 }, { 1, 0 } }, g_planks_normalmap },
			{ { { 1, 1, 3 }, { 1, 2, 4 }, { 1, 1, 4 } }, { 1, 1, 1 }, "", g_planks_texture, { { 0, 1 }, { 1, 0 }, { 1, 1 } }, g_planks_normalmap },
			// Box top face							   
			{ { { 0, 2, 3 }, { 0, 2, 4 }, { 1, 2, 4 } }, { 1, 1, 1 }, "", g_planks_texture, { { 0, 1 }, { 0, 0 }, { 1, 0 } }, g_planks_normalmap },
			{ { { 0, 2, 3 }, { 1, 2, 4 }, { 1, 2, 3 } }, { 1, 1, 1 }, "", g_planks_texture, { { 0, 1 }, { 1, 0 }, { 1, 1 } }, g_planks_normalmap },
			// Box bottom face							   
			{ { { 0, 1, 3 }, { 0, 1, 4 }, { 1, 1, 4 } }, { 1, 1, 1 }, "", g_planks_texture, { { 0, 1 }, { 0, 0 }, { 1, 0 } }, g_planks_normalmap },
			{ { { 0, 1, 3 }, { 1, 1, 4 }, { 1, 1, 3 } }, { 1, 1, 1 }, "", g_planks_texture, { { 0, 1 }, { 1, 0 }, { 1, 1 } }, g_planks_normalmap }
		};

		return true;
	}

	bool OnUserUpdate(float fElapsedTime) override
	{
		Controlls(fElapsedTime);
		Rasterization();

		return true;
	}

private:
	// Defined in Controlls.h
	void Controlls(float fElapsedTime);

	void Rasterization()
	{
		// Loop through all triangles and render them
		for (int i = 0; i < g_triangles.size(); i++)
		{
			Vec2D* projectedVertices = Projection(g_triangles[i]);
		}

		// Draw all pixels from the buffer on the screen
		for (int y = 0; y < SCREEN_HEIGHT; y++)
		{
			for (int x = 0; x < SCREEN_WIDTH; x++)
			{
				Vec3D pixelColor = g_pixels[y * SCREEN_WIDTH + x];

				Draw(x, y, { uint8_t(pixelColor.x), uint8_t(pixelColor.y), uint8_t(pixelColor.z) });

				g_pixels[y * SCREEN_WIDTH + x] = ZERO_VEC3D; // Clearing the buffer
			}
		}
	}

	Vec2D* Projection(Triangle triangle)
	{
		Vec2D projectedVertices[3];
		const float FOV = TAU * 0.2f;
		const float tanTheta = tan(FOV / 2);

		for (int i = 0; i < 3; i++)
		{
			// Project each vertex onto a point on the screen
			float screenX = (SCREEN_WIDTH / 2) * (triangle.vertices[i].x / (tanTheta * triangle.vertices[i].z));
			float screenY = (SCREEN_WIDTH / 2) * (triangle.vertices[i].y / (tanTheta * triangle.vertices[i].z));
			Vec2D screenCoords = { screenX + SCREEN_WIDTH / 2, SCREEN_HEIGHT - (screenY + SCREEN_HEIGHT / 2) };

			projectedVertices[i] = screenCoords;
		}

		// Sorting vertices in order of y-placement
		std::sort(projectedVertices, projectedVertices + 3, MaxY2D);

		// Draw lines between each point
		Line(projectedVertices[0], projectedVertices[1]);
		Line(projectedVertices[1], projectedVertices[2]);
		Line(projectedVertices[2], projectedVertices[0]);

		return projectedVertices;
	}

	void Line(Vec2D v1, Vec2D v2, Vec3D color = { 255, 255, 255 })
	{
		if (v2.x < v1.x)
			std::swap(v1, v2);

		int incrementY = (v2.y > v1.y) ? 1 : -1;

		if (v2.x < 0 || v1.x > SCREEN_WIDTH // Completely out of x-bounds
			|| (v1.y < 0 && incrementY == -1) || (v1.y > SCREEN_HEIGHT && incrementY == 1)) // Completely out of y-bounds
			return;

		if (v1.x != v2.x)
		{
			float lutning = (v2.y - v1.y) / (v2.x - v1.x);

			// Loops until end of line or at the edge of the screen
			for (int i = 0; i <= (int)(v2.x - v1.x) && (int)(v1.x + i) <= SCREEN_WIDTH; i++)
				for (int j = i * lutning; j != (int)((i + 1) * lutning) + incrementY; j += incrementY)
					// Only write to buffer if coordinates are within the screen
					if ((int)(v1.x + i) >= 0 && (int)(v1.x + i) < SCREEN_WIDTH && (int)(v1.y + j) >= 0 && (int)(v1.y + j) < SCREEN_HEIGHT)
						g_pixels[SCREEN_WIDTH * (int)(v1.y + j) + (int)(v1.x + i)] = color;
		}
		else
		{
			for (int i = 0; i != (int)(v2.y - v1.y); i += incrementY)
				// Only write to buffer if coordinates are within the screen
				if ((int)v1.x >= 0 && (int)v1.x < SCREEN_WIDTH && (int)(v1.y + i) >= 0 && (int)(v1.y + i) < SCREEN_HEIGHT)
					g_pixels[SCREEN_WIDTH * (int)(v1.y + i) + (int)v1.x] = color;
		}
	}
};

int main()
{
	Engine rasterizer;
	if (rasterizer.Construct(SCREEN_WIDTH, SCREEN_HEIGHT, 1, 1))
		rasterizer.Start();
	return 0;
}

#include "Controlls.h"