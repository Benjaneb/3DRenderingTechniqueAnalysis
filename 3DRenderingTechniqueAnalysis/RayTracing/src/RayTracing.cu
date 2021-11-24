#define OLC_PGE_APPLICATION
#define RAY_TRACER

// Build settings (cannot be changed during runtime)
#define PATH_TRACING 0
#define ASYNC 0
#define SCREEN_WIDTH 500
#define SCREEN_HEIGHT 375
#define RENDER_DISTANCE 30
#define TOUCHING_DISTANCE 0.01f
#define OFFSET_DISTANCE 0.00001f
#define MAX_BOUNCES 3
#define SAMPLES_PER_PIXEL 1 // for path tracing
#define SAMPLES_PER_RAY 5 // for distribution ray tracing
#define WHITE_COLOR { 255, 255, 255 }
#define REFRACTION_INDEX_AIR 1

#include <iostream>
#include <random>
#include <future>

#include <cuda_runtime.h>
#include <device_launch_parameters.h>

#include "olcPixelGameEngine.h"

#include "MathUtilities.cuh"
#include "WorldDatatypes.h"
#include "ParseOBJ.h"

// Global variables

Player g_player;

Vec3D g_pixels[SCREEN_HEIGHT * SCREEN_WIDTH]; // Pixel buffer that contains all pixels that'll be drawn on screen
float g_depthBuffer[SCREEN_HEIGHT * SCREEN_WIDTH]; // Contains the distance to each point represented by a pixel

std::vector<Sphere> g_spheres;
std::vector<Triangle> g_triangles;
std::vector<Light> g_lights;

Ground g_ground;

olc::Sprite* g_basketball_texture;
olc::Sprite* g_planks_texture;
olc::Sprite* g_concrete_texture;
olc::Sprite* g_tiledfloor_texture;
olc::Sprite* g_worldmap_texture;
olc::Sprite* g_gold_texture;
olc::Sprite* g_bricks_texture;

olc::Sprite* g_basketball_normalmap;
olc::Sprite* g_planks_normalmap;
olc::Sprite* g_concrete_normalmap;
olc::Sprite* g_tiledfloor_normalmap;
olc::Sprite* g_bricks_normalmap;

std::default_random_engine randEngine;

float b = 1.52;

// Ingame options (can be changed during runtime)
namespace Options
{
	bool mcControls = true;
}

class Engine : public olc::PixelGameEngine
{
public:
	Engine()
	{
		sAppName = "Ray_Tracing_Engine";
	}

	bool OnUserCreate() override
	{
		g_player = { { 1.5, 1.5, -2.064 }, { 1, ZERO_VEC3D }, TAU * 0.2f };

		g_basketball_texture = new olc::Sprite("../Assets/basketball.png");
		g_planks_texture = new olc::Sprite("../Assets/planks.png");
		g_concrete_texture = new olc::Sprite("../Assets/concrete.png");
		g_tiledfloor_texture = new olc::Sprite("../Assets/tiledfloor.png");
		g_worldmap_texture = new olc::Sprite("../Assets/worldmap.png");
		g_gold_texture = new olc::Sprite("../Assets/gold.png");
		g_bricks_texture = new olc::Sprite("../Assets/bricks.png");

		g_basketball_normalmap = new olc::Sprite("../Assets/basketball_normalmap.png");
		g_planks_normalmap = new olc::Sprite("../Assets/planks_normalmap.png");
		g_concrete_normalmap = new olc::Sprite("../Assets/concrete_normalmap.png");
		g_tiledfloor_normalmap = new olc::Sprite("../Assets/tiledfloor_normalmap.png");
		g_bricks_normalmap = new olc::Sprite("../Assets/bricks_normalmap.png");

		g_spheres =
		{
			// Lightsource
			//{ { 1.5, 3, 1.5 }, 0.5, { 0.965, 0.795, 0.3333 }, { 17, 0, 0, 1, 500, 6, 1 } },
			// Glossy ball
			//{ { 1.5, 1.4, 1.5 }, 0.4, { 0.965, 0.795, 0.3333 }, { 0.1, 0.6, 0.9, 0.05, 500, 6, 1 } },
			// Basket ball
			{ { 2.5, 0.5, 0.8 }, 0.5, { 1, 1, 1 }, { 0.15, 0.3, 0.6, 1, 500, 6, 1 }, g_basketball_texture, { 0, 0 }, { 1, 1 }, CreateRotationQuaternion(ReturnNormalizedVec3D({ 1, 0, 1 }), PI / 2), g_basketball_normalmap },
			// World atlas globe
			{ { 1.75, 0.3, 0.5 }, 0.3, { 1, 1, 1 }, { 0.15, 0.3, 0.5, 1, 500, 6, 1 }, g_worldmap_texture, { 0, 0 }, { 1, 1 }, CreateRotationQuaternion(ReturnNormalizedVec3D({ -1, 0.5, -2 }), PI / 2) },
			// Magenta lightsource
			{ { 0.5, 0.4, 0.8 }, 0.4, { 1, 0.2, 0.4157 }, { 9, 0, 0, 1, 500, 6, 1 } },
			// Another glossy ball
			//{ { 1.1, 0.3, 0.4 }, 0.3, { 0.6, 0.8, 0.9 }, { 0.1, 0.5, 0.9, 0.5, 500, 6, 1 } },
			// Refractibe BALLZ
			//{ { 1.1, 0.3, 0.4 }, 0.3, { 1, 1, 1 }, { 0.2, 0, 1, 0, 0.2, 1.3, 0 } },
			//{ { 1.1, 0.3, 0.4 }, 0.3, { 0.6, 0.8, 0.9 }, { 0.2, 0, 1, 0, 0.2, 1.3, 0 } },
			// Big green ball
			{ { 1.8, 0.8, 1.8 }, 0.8, { 0.2, 1, 0.4 }, { 0.1, 0.3, 0.4, 0, 500, 6, 1 } },
			// Big blue ball
			{ { -0.5, 1.2, 1.9 }, 1.2, { 0.3, 0.2, 1 }, { 0.1, 0.3, 0.4, 0.5, 500, 6, 1 } }
		};

		float a = 1;

		g_triangles =
		{
			//// Walls first face
			//{ { { 0, 0, 3 }, { 0, 3, 3 }, { 3, 3, 3 } }, { 1, 1, 1 }, STANDARD_MATERIAL, "", g_bricks_texture, { { 0, 1 }, { 0, 0 }, { 1, 0 } }, g_bricks_normalmap },
			//{ { { 0, 0, 3 }, { 3, 3, 3 }, { 3, 0, 3 } }, { 1, 1, 1 }, STANDARD_MATERIAL, "", g_bricks_texture, { { 0, 1 }, { 1, 0 }, { 1, 1 } }, g_bricks_normalmap },
			//// Walls second face
			//{ { { 0, 0, 0 }, { 0, 3, 0 }, { 0, 3, 3 } }, { 0.8, 1.1, 1.1 }, STANDARD_MATERIAL, "", g_concrete_texture, { { 0, 1 }, { 0, 0 }, { 1, 0 } }, g_concrete_normalmap},
			//{ { { 0, 0, 0 }, { 0, 3, 3 }, { 0, 0, 3 } }, { 0.8, 1.1, 1.1 }, STANDARD_MATERIAL, "", g_concrete_texture, { { 0, 1 }, { 1, 0 }, { 1, 1 } }, g_concrete_normalmap },
			//// Walls third face
			//{ { { 3, 0, 3 }, { 3, 3, 3 }, { 3, 3, 0 } }, { 1.1, 0.8, 1.1 }, STANDARD_MATERIAL, "", g_concrete_texture, { { 0, 1 }, { 0, 0 }, { 1, 0 } }, g_concrete_normalmap },
			//{ { { 3, 0, 3 }, { 3, 3, 0 }, { 3, 0, 0 } }, { 1.1, 0.8, 1.1 }, STANDARD_MATERIAL, "", g_concrete_texture, { { 0, 1 }, { 1, 0 }, { 1, 1 } }, g_concrete_normalmap },
			//// Walls fourth face
			//{ { { 0, 3, 0 }, { 3, 3, 3 }, { 0, 3, 3 } }, { 1, 1, 1 }, STANDARD_MATERIAL, "", g_concrete_texture, { { 0, 1 }, { 0, 0 }, { 1, 0 } }, g_concrete_normalmap },
			//{ { { 0, 3, 0 }, { 3, 3, 0 }, { 3, 3, 3 } }, { 1, 1, 1 }, STANDARD_MATERIAL, "", g_concrete_texture, { { 0, 1 }, { 1, 0 }, { 1, 1 } }, g_concrete_normalmap },

			//// Box first face
			//{ { { 1, 0, 2 }, { 2, 1, 2 }, { 1, 1, 2 } }, { 1, 1, 1 }, { 0.15, 0.3, 0.4, 1, 500, 6, 1 }, "", g_planks_texture, { { 0, 1 }, { 0, 0 }, { 1, 0 } }, g_planks_normalmap },
			//{ { { 1, 0, 2 }, { 2, 0, 2 }, { 2, 1, 2 } }, { 1, 1, 1 }, { 0.15, 0.3, 0.4, 1, 500, 6, 1 }, "", g_planks_texture, { { 0, 1 }, { 1, 0 }, { 1, 1 } }, g_planks_normalmap },
			//// Box second face
			//{ { { 1, 0, 1 }, { 1, 1, 1 }, { 2, 1, 1 } }, { 1, 1, 1 }, { 0.15, 0.3, 0.4, 1, 500, 6, 1 }, "", g_planks_texture, { { 0, 1 }, { 0, 0 }, { 1, 0 } }, g_planks_normalmap },
			//{ { { 1, 0, 1 }, { 2, 1, 1 }, { 2, 0, 1 } }, { 1, 1, 1 }, { 0.15, 0.3, 0.4, 1, 500, 6, 1 }, "", g_planks_texture, { { 0, 1 }, { 1, 0 }, { 1, 1 } }, g_planks_normalmap },
			//// Box third face
			//{ { { 1, 0, 1 }, { 1, 1, 2 }, { 1, 1, 1 } }, { 1, 1, 1 }, { 0.15, 0.3, 0.4, 1, 500, 6, 1 }, "", g_planks_texture, { { 0, 1 }, { 0, 0 }, { 1, 0 } }, g_planks_normalmap },
			//{ { { 1, 0, 1 }, { 1, 0, 2 }, { 1, 1, 2 } }, { 1, 1, 1 }, { 0.15, 0.3, 0.4, 1, 500, 6, 1 }, "", g_planks_texture, { { 0, 1 }, { 1, 0 }, { 1, 1 } }, g_planks_normalmap },
			//// Box fourth face							   
			//{ { { 2, 0, 1 }, { 2, 1, 1 }, { 2, 1, 2 } }, { 1, 1, 1 }, { 0.15, 0.3, 0.4, 1, 500, 6, 1 }, "", g_planks_texture, { { 0, 1 }, { 0, 0 }, { 1, 0 } }, g_planks_normalmap },
			//{ { { 2, 0, 1 }, { 2, 1, 2 }, { 2, 0, 2 } }, { 1, 1, 1 }, { 0.15, 0.3, 0.4, 1, 500, 6, 1 }, "", g_planks_texture, { { 0, 1 }, { 1, 0 }, { 1, 1 } }, g_planks_normalmap },
			//// Box fifth face							   
			//{ { { 1, 1, 1 }, { 1, 1, 2 }, { 2, 1, 2 } }, { 1, 1, 1 }, { 0.15, 0.3, 0.4, 1, 500, 6, 1 }, "", g_planks_texture, { { 0, 1 }, { 0, 0 }, { 1, 0 } }, g_planks_normalmap },
			//{ { { 1, 1, 1 }, { 2, 1, 2 }, { 2, 1, 1 } }, { 1, 1, 1 }, { 0.15, 0.3, 0.4, 1, 500, 6, 1 }, "", g_planks_texture, { { 0, 1 }, { 1, 0 }, { 1, 1 } }, g_planks_normalmap },

			// Refractive box first face
			/*{ { { 1, 0 + 1.25, 1 - 1 }, { 1, 1 + 1.25, 1 - 1 }, { 2, 1 + 1.25, 1 - 1 } }, { 0.8, 1, 1 }, { 0.2, 0, 0.9, 0.5, 0, b, 0 } },
			{ { { 1, 0 + 1.25, 1 - 1 }, { 2, 1 + 1.25, 1 - 1 }, { 2, 0 + 1.25, 1 - 1 } }, { 0.8, 1, 1 }, { 0.2, 0, 0.9, 0.5, 0, b, 0 } },
			// Refractive box second face
			{ { { 1, 0 + 1.25, 2 - 1 }, { 1 + a, 1 + 1.25, 3 - 1 - a }, { 1, 1 + 1.25, 2 - 1 } }, { 0.8, 1, 1 }, { 0.2, 0, 0.9, 0.5, 0, b, 0 } },
			{ { { 1, 0 + 1.25, 2 - 1 }, { 1 + a, 0 + 1.25, 3 - 1 - a }, { 1 + a, 1 + 1.25, 3 - 1 - a } }, { 0.8, 1, 1 }, { 0.2, 0, 0.9, 0.5, 0, b, 0 } },
			// Refractive ox third face
			{ { { 1, 0 + 1.25, 1 - 1 }, { 1, 1 + 1.25, 2 - 1 }, { 1, 1 + 1.25, 1 - 1 } }, { 0.8, 1, 1 }, { 0.2, 0, 0.9, 0.5, 0, b, 0 } },
			{ { { 1, 0 + 1.25, 1 - 1 }, { 1, 0 + 1.25, 2 - 1 }, { 1, 1 + 1.25, 2 - 1 } }, { 0.8, 1, 1 }, { 0.2, 0, 0.9, 0.5, 0, b, 0 } },
			// Refractive box fourth face							   
			{ { { 2, 0 + 1.25, 1 - 1 }, { 2, 1 + 1.25, 1 - 1 }, { 2, 1 + 1.25, 2 - 1 } }, { 0.8, 1, 1 }, { 0.2, 0, 0.9, 0.5, 0, b, 0 } },
			{ { { 2, 0 + 1.25, 1 - 1 }, { 2, 1 + 1.25, 2 - 1 }, { 2, 0 + 1.25, 2 - 1 } }, { 0.8, 1, 1 }, { 0.2, 0, 0.9, 0.5, 0, b, 0 } },
			// Refractive ox fifth face							   
			{ { { 1, 1 + 1.25, 1 - 1 }, { 1, 1 + 1.25, 2 - 1 }, { 2, 1 + 1.25, 2 - 1 } }, { 0.8, 1, 1 }, { 0.2, 0, 0.9, 0.5, 0, b, 0 } },
			{ { { 1, 1 + 1.25, 1 - 1 }, { 2, 1 + 1.25, 2 - 1 }, { 2, 1 + 1.25, 1 - 1 } }, { 0.8, 1, 1 }, { 0.2, 0, 0.9, 0.5, 0, b, 0 } },
			// Refractive ox sixth face
			{ { { 1, 0 + 1.25, 2 - 1 }, { 1, 0 + 1.25, 1 - 1 }, { 2, 0 + 1.25, 1 - 1 } }, { 0.8, 1, 1 }, { 0.2, 0, 0.9, 0.5, 0, b, 0 } },
			{ { { 1, 0 + 1.25, 2 - 1 }, { 2, 0 + 1.25, 1 - 1 }, { 2, 0 + 1.25, 2 - 1 } }, { 0.8, 1, 1 }, { 0.2, 0, 0.9, 0.5, 0, b, 0 } },*/

			//// refractive pyramid
			//{ { { 0.9, 0 + 0.01, 2.9 - 0.7 }, { 0.5, 1.4 + 0.01, 2.5 - 0.7 }, { 0.1, 0 + 0.01, 2.9 - 0.7 } }, { 1, 1, 1 }, { 0.2, 0, 1, 0, 0, 1.52, 0 } },
			//{ { { 0.1, 0 + 0.01, 2.9 - 0.7 }, { 0.5, 1.4 + 0.01, 2.5 - 0.7 }, { 0.1, 0 + 0.01, 2.1 - 0.7 } }, { 1, 1, 1 }, { 0.2, 0, 1, 0, 0, 1.52, 0 } },
			//{ { { 0.1, 0 + 0.01, 2.1 - 0.7 }, { 0.5, 1.4 + 0.01, 2.5 - 0.7 }, { 0.9, 0 + 0.01, 2.1 - 0.7 } }, { 1, 1, 1 }, { 0.2, 0, 1, 0, 0, 1.52, 0 } },
			//{ { { 0.9, 0 + 0.01, 2.1 - 0.7 }, { 0.5, 1.4 + 0.01, 2.5 - 0.7 }, { 0.9, 0 + 0.01, 2.9 - 0.7 } }, { 1, 1, 1 }, { 0.2, 0, 1, 0, 0, 1.52, 0 } },
			//{ { { 0.9, 0 + 0.01, 2.9 - 0.7 }, { 0.1, 0 + 0.01, 2.9 - 0.7 }, { 0.1, 0 + 0.01, 2.1 - 0.7 } }, { 1, 1, 1 }, { 0.2, 0, 1, 0, 0, 1.52, 0 } },
			//{ { { 0.9, 0 + 0.01, 2.9 - 0.7 }, { 0.9, 0 + 0.01, 2.1 - 0.7 }, { 0.1, 0 + 0.01, 2.1 - 0.7 } }, { 1, 1, 1 }, { 0.2, 0, 1, 0, 0, 1.52, 0 } },

			//// reflective gold pyramid
			//{ { { 0.9 + 2, 0, 2.9 }, { 0.5 + 2, 1.4, 2.5 }, { 0.1 + 2, 0, 2.9 } }, { 1, 1, 1 }, { 0.2, 0.4, 0.9, 0.2, 500, 6, 1 }, "", g_gold_texture, { { 0, 1 }, { 0, 0 }, { 1, 0 } } },
			//{ { { 0.1 + 2, 0, 2.9 }, { 0.5 + 2, 1.4, 2.5 }, { 0.1 + 2, 0, 2.1 } }, { 1, 1, 1 }, { 0.2, 0.4, 0.9, 0.2, 500, 6, 1 }, "", g_gold_texture, { { 0, 1 }, { 0, 0 }, { 1, 0 } } },
			//{ { { 0.1 + 2, 0, 2.1 }, { 0.5 + 2, 1.4, 2.5 }, { 0.9 + 2, 0, 2.1 } }, { 1, 1, 1 }, { 0.2, 0.4, 0.9, 0.2, 500, 6, 1 }, "", g_gold_texture, { { 0, 1 }, { 0, 0 }, { 1, 0 } } },
			//{ { { 0.9 + 2, 0, 2.1 }, { 0.5 + 2, 1.4, 2.5 }, { 0.9 + 2, 0, 2.9 } }, { 1, 1, 1 }, { 0.2, 0.4, 0.9, 0.2, 500, 6, 1 }, "", g_gold_texture, { { 0, 1 }, { 0, 0 }, { 1, 0 } } }
		};

		g_lights =
		{
			{ { 1.5, 3, 1.5 }, 0.5, 500, { 1, 0.8, 0.6 } }
		};

		for (int i = 0; i < g_lights.size(); i++)
			g_spheres.push_back({ g_lights[i].coords, g_lights[i].radius, g_lights[i].tint, { g_lights[i].emittance, 0, 0, 0, 0, 1, 0 } });

#if ASYNC == 1
		//std::async(std::launch::async, ImportScene, &g_triangles, "../Assets/RubberDuck.obj", 0.4, Vec3D({ 0.8, 0.5, 0.5 }));
#else
		//ImportScene(&g_triangles, "../Assets/RubberDuck.obj", 0.4, { 0.8, 0.5, 0.5 });
#endif
		g_ground = { 0, { 1, 1, 1 }, { 0.1, 0, 0, 1, 500, 6, 1 }, g_tiledfloor_texture, { 0, 0 }, { 1, 1 }, 1, g_tiledfloor_normalmap };

		return true;
	}

	bool OnUserUpdate(float fElapsedTime) override
	{
		Timer timer("Rendering");

		Controlls(fElapsedTime);

#if ASYNC == 1
		// Screen split up into 4 quadrants running in parallell on seperate threads
		std::async(std::launch::async, &Engine::RayTracing, this, Vec2D({ 0, 0 }), Vec2D({ SCREEN_WIDTH / 2, SCREEN_HEIGHT / 2 }));
		std::async(std::launch::async, &Engine::RayTracing, this, Vec2D({ SCREEN_WIDTH / 2, 0 }), Vec2D({ SCREEN_WIDTH, SCREEN_HEIGHT / 2 }));
		std::async(std::launch::async, &Engine::RayTracing, this, Vec2D({ 0, SCREEN_HEIGHT / 2 }), Vec2D({ SCREEN_WIDTH / 2, SCREEN_HEIGHT }));
		std::async(std::launch::async, &Engine::RayTracing, this, Vec2D({ SCREEN_WIDTH / 2, SCREEN_HEIGHT / 2 }), Vec2D({ SCREEN_WIDTH, SCREEN_HEIGHT }));
#else
		RayTracing({ 0, 0 }, { SCREEN_WIDTH, SCREEN_HEIGHT });
#endif
		return true;
	}

private:
	// Defined in Controlls.h
	void Controlls(float fElapsedTime);

	void RayTracing(Vec2D screenStart, Vec2D screenEnd)
	{
		const float zFar = (SCREEN_WIDTH * 0.5f) / tan(g_player.FOV * 0.5f);

		for (float y = screenStart.y - SCREEN_HEIGHT * 0.5f + 0.5f; y < screenEnd.y - SCREEN_HEIGHT * 0.5f + 0.5f; y++)
		{
			for (float x = screenStart.x - SCREEN_WIDTH * 0.5f + 0.5f; x < screenEnd.x - SCREEN_WIDTH * 0.5f + 0.5f; x++)
			{
				Vec3D v_direction = { x, y, zFar };
				NormalizeVec3D(&v_direction);

				Vec3D v_newDirection = QuaternionMultiplication(g_player.q_orientation, { 0, v_direction }, QuaternionConjugate(g_player.q_orientation)).vecPart;

				int screenX = x + SCREEN_WIDTH * 0.5f;
				int screenY = (SCREEN_HEIGHT - 1) - (y + SCREEN_HEIGHT * 0.5f);

				Vec3D pixelColor = ZERO_VEC3D;

				for (int i = 0; i < SAMPLES_PER_PIXEL; i++)
				{
					// Clearing the buffers
					g_pixels[SCREEN_WIDTH * screenY + screenX] = ZERO_VEC3D;
					g_depthBuffer[SCREEN_WIDTH * screenY + screenX] = INFINITY;

					RenderGround(g_player.coords, v_newDirection, screenX, screenY);

					RenderSpheres(g_player.coords, v_newDirection, screenX, screenY);

					RenderTriangles(g_player.coords, v_newDirection, screenX, screenY);

					AddToVec3D(&pixelColor, g_pixels[SCREEN_WIDTH * screenY + screenX]);
				}

				ScaleVec3D(&pixelColor, 1 / float(SAMPLES_PER_PIXEL));

				pixelColor.x = Min(pixelColor.x, 255.0f);
				pixelColor.y = Min(pixelColor.y, 255.0f);
				pixelColor.z = Min(pixelColor.z, 255.0f);

				Draw(screenX, screenY, { uint8_t(pixelColor.x), uint8_t(pixelColor.y), uint8_t(pixelColor.z) });
			}
#if PATH_TRACING == 1
			std::cout << ((y + SCREEN_HEIGHT * 0.5f) / SCREEN_HEIGHT) * 100 << "%" << std::endl;
#endif
		}
	}

	void RenderGround(Vec3D v_start, Vec3D v_direction, int screenX, int screenY)
	{
		Vec3D v_intersection = ZERO_VEC3D;
		Vec3D v_intersectionColor = ZERO_VEC3D;
		Quaternion q_surfaceNormal = IDENTITY_QUATERNION;
		float depth = 0;

		bool intersectionExists = GroundIntersection_RT(v_start, v_direction, &v_intersection, &v_intersectionColor, &q_surfaceNormal, &depth);

		if (intersectionExists && depth < g_depthBuffer[SCREEN_WIDTH * screenY + screenX])
		{
#if PATH_TRACING == 1
			v_intersectionColor = CalculateLighting_PathTracing(
				v_intersectionColor, g_ground.material, q_surfaceNormal, v_direction, v_intersection, 0
			);
#else
			v_intersectionColor = CalculateLighting_DistributionTracing(
				v_intersectionColor, g_ground.material, q_surfaceNormal.vecPart, v_direction, v_intersection, 0
			);
#endif

			g_pixels[SCREEN_WIDTH * screenY + screenX] = v_intersectionColor;
			g_depthBuffer[SCREEN_WIDTH * screenY + screenX] = depth;
		}
	}

	bool GroundIntersection_RT(Vec3D v_start, Vec3D v_direction,
		Vec3D* v_intersection = nullptr, Vec3D* v_intersectionColor = nullptr, Quaternion* q_surfaceNormal = nullptr, float* depth = nullptr)
	{
		if (v_direction.y >= 0 || v_start.y < g_ground.level)
		{
			return false;
		}

		ScaleVec3D(&v_direction, (g_ground.level - v_start.y) / v_direction.y);

		Vec3D rayGroundIntersection = AddVec3D(v_start, v_direction);

		if (v_intersection != nullptr)
		{
			*v_intersection = rayGroundIntersection;
		}

		if (depth != nullptr)
		{
			*depth = Distance3D(g_player.coords, rayGroundIntersection);
		}

		if (q_surfaceNormal != nullptr)
		{
			*q_surfaceNormal = { 1, { 0, 1, 0 } };
		}

		if (v_intersectionColor == nullptr)
		{
			// Don't return any color
			return true;
		}

		*v_intersectionColor = WHITE_COLOR;

		if (g_ground.texture != nullptr || g_ground.normalMap != nullptr)
		{
			float signedTextureWidth = (g_ground.textureCorner2.x - g_ground.textureCorner1.x) * g_ground.textureScalar;
			float signedTextureHeight = (g_ground.textureCorner2.y - g_ground.textureCorner1.y) * g_ground.textureScalar;

			float t1 = fmod(rayGroundIntersection.x, signedTextureWidth) / signedTextureWidth;
			float t2 = fmod(rayGroundIntersection.z, signedTextureHeight) / signedTextureHeight;

			// if the t values are negative, we need to flip them around the center of the texture and make them positive
			if (t1 < 0) t1 += 1;
			if (t2 < 0) t2 += 1;

			float textureX = Lerp(g_ground.textureCorner1.x, g_ground.textureCorner2.x, t1);
			float textureY = Lerp(g_ground.textureCorner1.y, g_ground.textureCorner2.y, t2);

			if (g_ground.texture != nullptr)
			{
				olc::Pixel texelColor = g_ground.texture->Sample(textureX, textureY);

				*v_intersectionColor = { float(texelColor.r), float(texelColor.g), float(texelColor.b) };
			}
			if (g_ground.normalMap != nullptr)
			{
				olc::Pixel normalMapColor = g_ground.normalMap->Sample(textureX, textureY);

				// Converting the color in the normalMap to an actual unit vector
				q_surfaceNormal->vecPart = ReturnNormalizedVec3D({ float(normalMapColor.r) * 2 - 255.0f, float(normalMapColor.b) * 2 - 255.0f, float(normalMapColor.g) * 2 - 255.0f });
			}
		}

		// Proof that the ConusProduct is the most useful function

		// Tint the color
		*v_intersectionColor = ConusProduct(*v_intersectionColor, g_ground.tint);

		return true;
	}

	/*bool GroundIntersection_RM(float groundLevel, VertexPair2D textureVertexPair, float textureScalar, Vec3D v_start, Vec3D v_direction, 
		Vec3D* v_intersection = nullptr, float* depth = nullptr, Vec3D* pixelColor = nullptr)
	{
		float totalDistanceTravelled = 0;

		while (totalDistanceTravelled < RENDER_DISTANCE)
		{
			float distanceToGround = abs(v_start.y - groundLevel);

			AddToVec3D(&v_start, VecScalarMultiplication3D(v_direction, distanceToGround));

			if (distanceToGround < TOUCHING_DISTANCE)
			{
				if (v_intersection == nullptr)
				{
					return true;
				}

				*v_intersection = v_start;
				*depth = Distance3D(g_player.coords, v_start);

				if (pixelColor == nullptr)
				{
					return true;
				}

				float signedTextureWidth = (textureVertexPair.vertices[1].x - textureVertexPair.vertices[0].x) * textureScalar;
				float signedTextureHeight = (textureVertexPair.vertices[1].y - textureVertexPair.vertices[0].y) * textureScalar;

				float textureX = fmod(v_start.x, signedTextureWidth) / signedTextureWidth;
				float textureY = fmod(v_start.z, signedTextureHeight) / signedTextureHeight;

				// if the textureCoordinates are negative, we need to flip them around the center of the texture and make them positive
				if (textureX < 0) textureX += 1;
				if (textureY < 0) textureY += 1;

				olc::Pixel texelColor = g_ground.texture->Sample(textureX, textureY);

				*pixelColor = { float(texelColor.r), float(texelColor.g), float(texelColor.b) };

				return true;
			}

			totalDistanceTravelled += distanceToGround;
		}

		return false;
	}*/

	void RenderSpheres(Vec3D v_start, Vec3D v_direction, int screenX, int screenY)
	{
		Vec3D v_intersection = ZERO_VEC3D;
		Vec3D v_intersectionColor = ZERO_VEC3D;
		Quaternion q_surfaceNormal = IDENTITY_QUATERNION;
		float depth = 0;

		for (int i = 0; i < g_spheres.size(); i++)
		{
			bool intersectionExists = SphereIntersection_RT(g_spheres[i], v_start, v_direction, &v_intersection, &v_intersectionColor, &q_surfaceNormal, &depth);

			//bool intersectionExists = SphereIntersection_RM(g_spheres[i], v_start, v_direction, &v_intersection, &depth);

			if (intersectionExists && depth < g_depthBuffer[SCREEN_WIDTH * screenY + screenX])
			{
#if PATH_TRACING == 1
				v_intersectionColor = CalculateLighting_PathTracing(
					v_intersectionColor, g_spheres[i].material, q_surfaceNormal, v_direction, v_intersection, 0
				);
#else
				v_intersectionColor = CalculateLighting_DistributionTracing(
					v_intersectionColor, g_spheres[i].material, q_surfaceNormal.vecPart, v_direction, v_intersection, 0
				);
#endif

				g_pixels[SCREEN_WIDTH * screenY + screenX] = v_intersectionColor;
				g_depthBuffer[SCREEN_WIDTH * screenY + screenX] = depth;
			}
		}
	}

	// Ray tracing for spheres
	bool SphereIntersection_RT(Sphere sphere, Vec3D v_start, Vec3D v_direction,
		Vec3D* v_intersection = nullptr, Vec3D* v_intersectionColor = nullptr, Quaternion* q_surfaceNormal = nullptr, float* depth = nullptr)
	{
		float dxdz = v_direction.x / v_direction.z;
		float dydz = v_direction.y / v_direction.z;

		float a = dxdz * dxdz + dydz * dydz + 1;
		
		float b = 
			2 * dxdz * (v_start.x - sphere.coords.x) +
			2 * dydz * (v_start.y - sphere.coords.y) +
			2 * (v_start.z - sphere.coords.z);

		float c = 
			(v_start.x - sphere.coords.x) * (v_start.x - sphere.coords.x) +
			(v_start.y - sphere.coords.y) * (v_start.y - sphere.coords.y) +
			(v_start.z - sphere.coords.z) * (v_start.z - sphere.coords.z) - sphere.radius * sphere.radius;

		// ISAK: There wasn't any need to recalculate this multiple times
		float rootContent = b * b - 4 * a * c;

		// There exists no intersections (no real answer)
		if (rootContent < 0) return false;

		float z1 = (-b + sqrt(rootContent)) / (2 * a);
		float z2 = (-b - sqrt(rootContent)) / (2 * a);

		Vec3D v_alternative1 = { z1 * dxdz, z1 * dydz, z1 };
		AddToVec3D(&v_alternative1, v_start);

		Vec3D v_alternative2 = { z2 * dxdz, z2 * dydz, z2 };
		AddToVec3D(&v_alternative2, v_start);

		// Check which intersection is the closest and choose that one
		float dist1 = DistanceSquared3D(v_alternative1, v_start);
		float dist2 = DistanceSquared3D(v_alternative2, v_start);

		bool dist1Closest = dist1 < dist2;

		Vec3D v_correctHit = dist1Closest ? v_alternative1 : v_alternative2;
		Vec3D v_otherHit = dist1Closest ? v_alternative2 : v_alternative1;

		// Check if the intersection is behind the ray. If so, choose the other one.
		if (DotProduct3D(SubtractVec3D(v_correctHit, v_start), v_direction) < 0)
		{
			v_correctHit = v_otherHit;

			// Check if the other intersection is behind the ray. If so, discard it.
			if (DotProduct3D(SubtractVec3D(v_correctHit, v_start), v_direction) < 0) return false;
		}

		// Checks whether or not to return the intersection
		if (v_intersection != nullptr)
		{
			*v_intersection = v_correctHit;
		}

		// Calculating the normal of the sphere (without normalmap)
		Vec3D v_normal = SubtractVec3D(v_correctHit, sphere.coords);
		NormalizeVec3D(&v_normal);

		if (depth != nullptr)
		{
			*depth = Distance3D(g_player.coords, v_correctHit);
		}

		if (q_surfaceNormal != nullptr)
		{
			q_surfaceNormal->vecPart = v_normal;
			q_surfaceNormal->realPart = 1;

			if (DistanceSquared3D(v_start, sphere.coords) < sphere.radius * sphere.radius)
			{
				q_surfaceNormal->realPart = -1;
			}

			ScaleVec3D(&(q_surfaceNormal->vecPart), q_surfaceNormal->realPart);
		}

		if (v_intersectionColor == nullptr)
		{
			// Don't return any color
			return true;
		}

		*v_intersectionColor = WHITE_COLOR;

		if (sphere.texture != nullptr || q_surfaceNormal != nullptr)
		{
			Vec3D i_Hat = { 1, 0, 0 };
			Vec3D j_Hat = { 0, 1, 0 };
			Vec3D k_Hat = { 0, 0, 1 };

			// Rotating axies by sphere rotation quaternion
			i_Hat = QuaternionMultiplication(sphere.rotQuaternion, { 0, i_Hat }, QuaternionConjugate(sphere.rotQuaternion)).vecPart;
			j_Hat = QuaternionMultiplication(sphere.rotQuaternion, { 0, j_Hat }, QuaternionConjugate(sphere.rotQuaternion)).vecPart;
			k_Hat = QuaternionMultiplication(sphere.rotQuaternion, { 0, k_Hat }, QuaternionConjugate(sphere.rotQuaternion)).vecPart;

			// Translate normal into new coordinate system
			v_normal = { DotProduct3D(v_normal, i_Hat), DotProduct3D(v_normal, j_Hat), DotProduct3D(v_normal, k_Hat) };

			// UV coordinates
			float u = 0.5 + atan2(v_normal.x, v_normal.z) / TAU;
			float v = 0.5 - asin(v_normal.y) / PI;

			float textureX = Lerp(sphere.textureCorner1.x, sphere.textureCorner2.x, u);
			float textureY = Lerp(sphere.textureCorner1.y, sphere.textureCorner2.y, v);

			if (sphere.texture != nullptr)
			{
				// Interpolating between assigned texture coordinates
				olc::Pixel texelColor = sphere.texture->Sample(textureX, textureY);

				*v_intersectionColor = { (float)texelColor.r, (float)texelColor.g, (float)texelColor.b };
			}
			if (sphere.normalMap != nullptr)
			{
				olc::Pixel normalMapColor = sphere.normalMap->Sample(textureX, textureY);

				// Converting the color in the normalMap to an actual unit vector
				Vec3D v_normalMapNormal = ReturnNormalizedVec3D({ float(normalMapColor.r) * 2 - 255.0f, float(normalMapColor.b) * 2 - 255.0f, float(normalMapColor.g) * 2 - 255.0f });

				// Calculating tangents of the sphere at the intersection point
				Vec3D v_sidewaysTangent = ReturnNormalizedVec3D({ -v_normal.z, 0, v_normal.x });
				Vec3D v_forwardTangent = ReturnNormalizedVec3D({ 0, -v_normal.z, v_normal.y });

				// Takes the normal in the normalMap and transforms it into the actual normal of the object
				Matrix3D normalMatrix =
				{
					v_sidewaysTangent,
					v_normal,
					v_forwardTangent
				};

				q_surfaceNormal->vecPart = VecScalarMultiplication3D(VecMatrixMultiplication3D(v_normalMapNormal, normalMatrix), q_surfaceNormal->realPart);
			}
		}
		
		// Tint the color
		*v_intersectionColor = ConusProduct(*v_intersectionColor, sphere.tint);

		return true;
	}

	// Ray marching for spheres
	/*bool SphereIntersection_RM(Sphere sphere, Vec3D v_start, Vec3D v_direction, 
		Vec3D* v_intersection = nullptr, float* depth = nullptr)
	{
		float distanceTravelled = 0;

		while (distanceTravelled < RENDER_DISTANCE)
		{
			float distance = Distance3D(v_start, sphere.coords) - sphere.radius;

			AddToVec3D(&v_start, VecScalarMultiplication3D(v_direction, distance));
			distanceTravelled += distance;

			if (distance < TOUCHING_DISTANCE)
			{
				if (v_intersection == nullptr) 
				{
					return true;
				}

				*v_intersection = v_start;
				*depth = Distance3D(g_player.coords, v_start);

				return true;
			}
		}

		return false;
	}*/

	void RenderTriangles(Vec3D v_start, Vec3D v_direction, int screenX, int screenY)
	{
		Vec3D v_intersection = ZERO_VEC3D;
		Vec3D v_intersectionColor = ZERO_VEC3D;
		Quaternion q_surfaceNormal = IDENTITY_QUATERNION;
		float depth = 0;

		for (int i = 0; i < g_triangles.size(); i++)
		{
			bool intersectionExists = TriangleIntersection_RT(g_triangles[i], v_start, v_direction, &v_intersection, &v_intersectionColor, &q_surfaceNormal, &depth);

			if (intersectionExists && depth < g_depthBuffer[SCREEN_WIDTH * screenY + screenX])
			{
#if PATH_TRACING == 1
				v_intersectionColor = CalculateLighting_PathTracing(
					v_intersectionColor, g_triangles[i].material, q_surfaceNormal, v_direction, v_intersection, 0
				);
#else
				v_intersectionColor = CalculateLighting_DistributionTracing(
					v_intersectionColor, g_triangles[i].material, q_surfaceNormal.vecPart, v_direction, v_intersection, 0
				);
#endif

				g_pixels[SCREEN_WIDTH * screenY + screenX] = v_intersectionColor;
				g_depthBuffer[SCREEN_WIDTH * screenY + screenX] = depth;
			}
		}
	}

	// Ray tracing for triangles
	bool TriangleIntersection_RT(Triangle triangle, Vec3D v_start, Vec3D v_direction,
		Vec3D* v_intersection = nullptr, Vec3D* v_intersectionColor = nullptr, Quaternion* q_surfaceNormal = nullptr, float* depth = nullptr)
	{
		Vec3D v_triangleEdge1 = SubtractVec3D(triangle.vertices[1], triangle.vertices[0]);
		Vec3D v_triangleEdge2 = SubtractVec3D(triangle.vertices[2], triangle.vertices[0]);

		Vec3D v_triangleNormal = CrossProduct(v_triangleEdge1, v_triangleEdge2);

		NormalizeVec3D(&v_triangleNormal);

		// how much the plane is offseted in the direction of the planeNormal
		// a negative value means it's offseted in the opposite direction of the planeNormal
		float f_trianglePlaneOffset = DotProduct3D(v_triangleNormal, triangle.vertices[0]);

		Vec3D v_trianglePlaneIntersection = LinePlaneIntersection(v_start, v_direction, v_triangleNormal, f_trianglePlaneOffset);

		if (DotProduct3D(SubtractVec3D(v_trianglePlaneIntersection, v_start), v_direction) < 0) return false;

		// these normals aren't actually normalized, but that doesn't matter for this use-case
		Vec3D v_triangleEdge1_normal = CrossProduct(SubtractVec3D(triangle.vertices[1], triangle.vertices[0]), v_triangleNormal);
		Vec3D v_triangleEdge2_normal = CrossProduct(SubtractVec3D(triangle.vertices[2], triangle.vertices[1]), v_triangleNormal);
		Vec3D v_triangleEdge3_normal = CrossProduct(SubtractVec3D(triangle.vertices[0], triangle.vertices[2]), v_triangleNormal);

		// check if the intersection is outside of the triangle
		if ((DotProduct3D(v_triangleEdge1_normal, SubtractVec3D(v_trianglePlaneIntersection, triangle.vertices[1])) > 0) ||
			(DotProduct3D(v_triangleEdge2_normal, SubtractVec3D(v_trianglePlaneIntersection, triangle.vertices[2])) > 0) ||
			(DotProduct3D(v_triangleEdge3_normal, SubtractVec3D(v_trianglePlaneIntersection, triangle.vertices[0])) > 0))
		{
			return false;
		}

		// Checks whether or not to return the intersection
		if (v_intersection != nullptr)
		{
			*v_intersection = v_trianglePlaneIntersection;
		}

		if (depth != nullptr)
		{
			*depth = Distance3D(g_player.coords, v_trianglePlaneIntersection);
		}

		if (q_surfaceNormal != nullptr)
		{
			q_surfaceNormal->vecPart = v_triangleNormal;

			q_surfaceNormal->realPart = 1;

			if (DotProduct3D(v_triangleNormal, v_direction) > 0)
			{
				// The triangle face is inside of the mesh, so the normal must be flipped
				q_surfaceNormal->realPart = -1;
			}

			ScaleVec3D(&(q_surfaceNormal->vecPart), q_surfaceNormal->realPart);
		}
		
		if (v_intersectionColor == nullptr)
		{
			// Don't return any color
			return true;
		}

		*v_intersectionColor = WHITE_COLOR;

		if (triangle.texture != nullptr || triangle.normalMap != nullptr)
		{
			// from here on we calculate the texture coordinates

			Vec3D v_intersectionRelativeToTriangle = SubtractVec3D(v_trianglePlaneIntersection, triangle.vertices[0]);

			Matrix3D triangleMatrix =
			{
				v_triangleEdge1,
				v_triangleEdge2,
				v_triangleNormal
			};

			Vec3D triangleEdgeScalars = VecMatrixMultiplication3D(v_intersectionRelativeToTriangle, InverseMatrix3D(triangleMatrix));

			Vec2D textureCoordinates = { 0, 0 };

			AddToVec2D(&textureCoordinates, VecScalarMultiplication2D(SubtractVec2D(triangle.textureVertices[1], triangle.textureVertices[0]), triangleEdgeScalars.x));
			AddToVec2D(&textureCoordinates, VecScalarMultiplication2D(SubtractVec2D(triangle.textureVertices[2], triangle.textureVertices[0]), triangleEdgeScalars.y));
			AddToVec2D(&textureCoordinates, triangle.textureVertices[0]);

			if (triangle.texture != nullptr)
			{
				olc::Pixel texelColor = triangle.texture->Sample(textureCoordinates.x, textureCoordinates.y);

				*v_intersectionColor = { float(texelColor.r), float(texelColor.g), float(texelColor.b) };
			}
			if (triangle.normalMap != nullptr)
			{
				olc::Pixel normalMapColor = triangle.normalMap->Sample(textureCoordinates.x, textureCoordinates.y);

				// Converting the color in the normalMap to an actual unit vector
				Vec3D v_normalMapNormal = ReturnNormalizedVec3D({ float(normalMapColor.r) * 2 - 255.0f, float(normalMapColor.b) * 2 - 255.0f, float(normalMapColor.g) * 2 - 255.0f });

				// Calculating tangents of the triangle for finding the normal in object space

				// { u1, v1 }, { u2, v2 }, { u3, v3 } are the normalMapVertices
				// T is the tangent
				// B is the bitangent
				
				//                       | T.x  B.x  0 |   
				// { v_triangleEdge1 } = | T.y  B.y  0 | * { u2 - u1, v2 - v1, 0 }
				//                       | T.z  B.z  0 |   

				//                       | T.x  B.x  0 |   
				// { v_triangleEdge2 } = | T.y  B.y  0 | * { u3 - u1, v3 - v1, 0 }
				//                       | T.z  B.z  0 |   

				// | v_triangleEdge1.x  v_triangleEdge2.x  0 |   | T.x  B.x  0 |   | u2 - u1  u3 - u1  0 |
				// | v_triangleEdge1.y  v_triangleEdge2.y  0 | = | T.y  B.y  0 | * | v2 - v1  v3 - v1  0 |
				// | v_triangleEdge1.z  v_triangleEdge2.z  0 |   | T.z  B.z  0 |   |    0        0     1 |

				//                                                                                       -1
				// | T.x  B.x  0 |   | v_triangleEdge1.x  v_triangleEdge2.x  0 |   | u2 - u1  u3 - u1  0 |
				// | T.y  B.y  0 | = | v_triangleEdge1.y  v_triangleEdge2.y  0 | * | v2 - v1  v3 - v1  0 |
				// | T.z  B.z  0 |	 | v_triangleEdge1.z  v_triangleEdge2.z  0 |   |    0        0     1 |

				Matrix3D m1 =
				{
					v_triangleEdge1,
					v_triangleEdge2,
					ZERO_VEC3D
				};

				Matrix3D m2 =
				{
					{ triangle.textureVertices[1].x - triangle.textureVertices[0].x, triangle.textureVertices[1].y - triangle.textureVertices[0].y, 0 },
					{ triangle.textureVertices[2].x - triangle.textureVertices[0].x, triangle.textureVertices[2].y - triangle.textureVertices[0].y, 0 },
					{ 0, 0, 1 }
				};

				Matrix3D tangentsMatrix = MatrixMultiplication3D(InverseMatrix3D(m2), m1);

				// Takes the normal in the normalMap and transforms it into the actual normal of the object
				Matrix3D normalMatrix =
				{
					ReturnNormalizedVec3D(tangentsMatrix.i_Hat),
					v_triangleNormal,
					ReturnNormalizedVec3D(tangentsMatrix.j_Hat)
				};

				q_surfaceNormal->vecPart = VecScalarMultiplication3D(VecMatrixMultiplication3D(v_normalMapNormal, normalMatrix), q_surfaceNormal->realPart);
			}
		}
		
		// Tint the color
		*v_intersectionColor = ConusProduct(*v_intersectionColor, triangle.tint);
		
		return true;
	}

	Vec3D LinePlaneIntersection(Vec3D v_start, Vec3D v_direction, Vec3D v_planeNormal, float f_planeOffset)
	{
		float f_deltaOffset = DotProduct3D(v_start, v_planeNormal);

		f_planeOffset -= f_deltaOffset;

		float f_scalingFactor = f_planeOffset / DotProduct3D(v_direction, v_planeNormal);

		return AddVec3D(VecScalarMultiplication3D(v_direction, f_scalingFactor), v_start);
	}

	/*bool TriangleIntersection_RM(Triangle triangle, Vec3D v_start, Vec3D v_direction, Vec3D* v_intersection = nullptr, float* depth = nullptr, Vec3D* pixelColor = nullptr)
	{
		Vec3D v_triangleEdge1 = SubtractVec3D(triangle.vertices[1], triangle.vertices[0]);
		Vec3D v_triangleEdge2 = SubtractVec3D(triangle.vertices[2], triangle.vertices[0]);

		Vec3D v_triangleNormal = CrossProduct(v_triangleEdge1, v_triangleEdge2);
		NormalizeVec3D(&v_triangleNormal);

		// the triangle is facing away from the ray, so we return no intersection
		if (DotProduct3D(v_triangleNormal, v_direction) > 0) return false;

		// how much the plane is offseted in the direction of the planeNormal
		// a negative value means it's offseted in the opposite direction of the planeNormal
		float f_trianglePlaneOffset = DotProduct3D(v_triangleNormal, triangle.vertices[0]);

		Vec3D v_triangleEdge1_normal = CrossProduct(SubtractVec3D(triangle.vertices[1], triangle.vertices[0]), v_triangleNormal);
		Vec3D v_triangleEdge2_normal = CrossProduct(SubtractVec3D(triangle.vertices[2], triangle.vertices[1]), v_triangleNormal);
		Vec3D v_triangleEdge3_normal = CrossProduct(SubtractVec3D(triangle.vertices[0], triangle.vertices[2]), v_triangleNormal);

		float f_totalDistanceTravelled = 0;

		while (f_totalDistanceTravelled < RENDER_DISTANCE)
		{
			float f_signedDistanceToPlane = f_trianglePlaneOffset - DotProduct3D(v_start, v_triangleNormal);

			// the start vector projected onto the trianglePlane
			Vec3D vecProjectedOnPlane = AddVec3D(v_start, VecScalarMultiplication3D(v_triangleNormal, f_signedDistanceToPlane));

			float f_distanceToTriangle;

			// If the projectedPoint is inside the triangle then the distance to the triangle is just the distance to the plane
			if (DotProduct3D(v_triangleEdge1_normal, SubtractVec3D(vecProjectedOnPlane, triangle.vertices[0])) <= 0 &&
				DotProduct3D(v_triangleEdge2_normal, SubtractVec3D(vecProjectedOnPlane, triangle.vertices[1])) <= 0 &&
				DotProduct3D(v_triangleEdge3_normal, SubtractVec3D(vecProjectedOnPlane, triangle.vertices[2])) <= 0)
			{
				f_distanceToTriangle = abs(f_signedDistanceToPlane);
			}
			// Otherwise, the distance to the triangle is the distance to the closest edge of the triangle
			else
			{
				float distanceToEdge1 = DistanceToEdge(v_start, triangle.vertices[1], triangle.vertices[0]);
				float distanceToEdge2 = DistanceToEdge(v_start, triangle.vertices[2], triangle.vertices[1]);
				float distanceToEdge3 = DistanceToEdge(v_start, triangle.vertices[0], triangle.vertices[2]);

				float minDistance = distanceToEdge1;

				if (distanceToEdge2 < minDistance) minDistance = distanceToEdge2;
				if (distanceToEdge3 < minDistance) minDistance = distanceToEdge3;

				f_distanceToTriangle = minDistance;
			}
			
			AddToVec3D(&v_start, VecScalarMultiplication3D(v_direction, f_distanceToTriangle));

			if (f_distanceToTriangle < TOUCHING_DISTANCE)
			{
				if (v_intersection == nullptr)
				{
					return true;
				}

				*v_intersection = v_start;
				*depth = Distance3D(g_player.coords, v_start);

				if (pixelColor == nullptr)
				{
					return true;
				}

				// Calculating the texture coordinates

				Vec2D v_textureTriangleEdge1 = SubtractVec2D(triangle.textureVertices[1], triangle.textureVertices[0]);
				Vec2D v_textureTriangleEdge2 = SubtractVec2D(triangle.textureVertices[2], triangle.textureVertices[0]);

				Vec3D v_intersectionRelativeToTriangle = SubtractVec3D(v_start, triangle.vertices[0]);

				Matrix3D triangleMatrix =
				{
					v_triangleEdge1,
					v_triangleEdge2,
					v_triangleNormal
				};

				Vec3D triangleEdgeScalars = VecMatrixMultiplication3D(v_intersectionRelativeToTriangle, InverseMatrix3D(triangleMatrix));

				Vec2D textureCoordinates = { 0, 0 };

				AddToVec2D(&textureCoordinates, VecScalarMultiplication2D(v_textureTriangleEdge1, triangleEdgeScalars.x));
				AddToVec2D(&textureCoordinates, VecScalarMultiplication2D(v_textureTriangleEdge2, triangleEdgeScalars.y));
				AddToVec2D(&textureCoordinates, triangle.textureVertices[0]);

				olc::Pixel texelColor = triangle.texture->Sample(textureCoordinates.x, textureCoordinates.y);

				*pixelColor = { float(texelColor.r), float(texelColor.g), float(texelColor.b) };

				return true;
			}
			
			f_totalDistanceTravelled += f_distanceToTriangle;
		}

		return false;
	}

	float DistanceToEdge(Vec3D v_point, Vec3D v_vertex1, Vec3D v_vertex2)
	{
		Vec3D v_edgeDirection = SubtractVec3D(v_vertex2, v_vertex1);
		NormalizeVec3D(&v_edgeDirection);
		float f_edgeLength = Distance3D(v_vertex1, v_vertex2);

		float f_projectedPointOnEdgelength = DotProduct3D(SubtractVec3D(v_point, v_vertex1), v_edgeDirection);

		Vec3D v_closestPoint = VecScalarMultiplication3D(v_edgeDirection, Clamp(f_projectedPointOnEdgelength, 0, f_edgeLength));

		return Distance3D(v_point, v_closestPoint);
	}*/

	Vec3D CalculateLighting_PathTracing(Vec3D v_objectColor, Material material, Quaternion q_surfaceNormal, Vec3D v_incomingDirection, Vec3D v_intersection, int i_bounceCount)
	{
		Vec3D v_outgoingLightColor = VecScalarMultiplication3D(v_objectColor, material.emittance);

		float refractionIndex1 = REFRACTION_INDEX_AIR;
		float refractionIndex2 = material.refractionIndex;
		float attenuation = 0;

		if (q_surfaceNormal.realPart == -1)
		{
			refractionIndex1 = material.refractionIndex;
			refractionIndex2 = REFRACTION_INDEX_AIR;
			v_outgoingLightColor = ZERO_VEC3D;
		}

		if (i_bounceCount > MAX_BOUNCES)
		{
			return v_outgoingLightColor;
		}

		Vec3D v_outgoingDirection;
 
		float cosIncomingAngle = -(DotProduct3D(v_incomingDirection, q_surfaceNormal.vecPart));

		// Tangent inside of the plane defined by v_surfaceNormal and v_incomingDirection
		Vec3D v_surfaceTangent = CrossProduct(ReturnNormalizedVec3D(CrossProduct(q_surfaceNormal.vecPart, v_incomingDirection)), q_surfaceNormal.vecPart);

		float sinIncomingAngle = DotProduct3D(v_incomingDirection, v_surfaceTangent);

		float sinRefractedAngle = Min(refractionIndex1 * sinIncomingAngle / refractionIndex2, 1.0f);

		// Pythagorean identity
		float cosRefractedAngle = sqrt(1 - sinRefractedAngle * sinRefractedAngle);

		// Average of the s-polarized reflectance and p-polarized reflectance probabilities
		float reflectanceProbability = (
			Square((refractionIndex1 * cosIncomingAngle - refractionIndex2 * cosRefractedAngle) / (refractionIndex1 * cosIncomingAngle + refractionIndex2 * cosRefractedAngle)) +
			Square((refractionIndex1 * cosRefractedAngle - refractionIndex2 * cosIncomingAngle) / (refractionIndex1 * cosRefractedAngle + refractionIndex2 * cosIncomingAngle))
		) * 0.5f;

		float reflectance = Lerp(material.minReflectance, material.maxReflectance, reflectanceProbability);

		bool reflectRay = (float(int64_t(randEngine())) / float(int64_t(randEngine.max()))) < reflectanceProbability;

		float weight = 1 / reflectanceProbability;

		if (reflectRay)
		{
			Vec3D v_lambertianRay = ReturnNormalizedVec3D(RandomVec_InUnitSphere());

			if (DotProduct3D(v_lambertianRay, q_surfaceNormal.vecPart) < 0)
			{
				// The vector is in the wrong hemisphere, so we flip it
				ScaleVec3D(&v_lambertianRay, -1);
			}

			Vec3D v_specularRay = SubtractVec3D(v_incomingDirection, VecScalarMultiplication3D(q_surfaceNormal.vecPart, 2 * DotProduct3D(v_incomingDirection, q_surfaceNormal.vecPart)));

			v_outgoingDirection = ReturnNormalizedVec3D(Lerp3D(v_specularRay, v_lambertianRay, material.reflectiveRoughness));

			AddToVec3D(&v_intersection, VecScalarMultiplication3D(v_outgoingDirection, OFFSET_DISTANCE));

			if (q_surfaceNormal.realPart == -1)
			{
				// The ray is reflecting into the object
				attenuation = material.attenuation;
			}
		}
		else
		{
			Vec3D v_lambertianRay = ReturnNormalizedVec3D(RandomVec_InUnitSphere());

			if (DotProduct3D(v_lambertianRay, q_surfaceNormal.vecPart) > 0)
			{
				// The vector is in the wrong hemisphere, so we flip it
				ScaleVec3D(&v_lambertianRay, -1);
			}

			Vec3D v_refractiveRay = AddVec3D(VecScalarMultiplication3D(q_surfaceNormal.vecPart, -cosRefractedAngle), VecScalarMultiplication3D(v_surfaceTangent, sinRefractedAngle));

			v_outgoingDirection = ReturnNormalizedVec3D(Lerp3D(v_refractiveRay, v_lambertianRay, material.refractiveRoughness));

			AddToVec3D(&v_intersection, VecScalarMultiplication3D(v_outgoingDirection, OFFSET_DISTANCE));

			if (q_surfaceNormal.realPart == 1)
			{
				// The ray is refracting into the object
				attenuation = material.attenuation;
			}

			weight = 1 / (1 - reflectanceProbability);
		}

		Vec3D v_nextIntersection = ZERO_VEC3D;
		Vec3D v_intersectionColor = ZERO_VEC3D;
		Quaternion q_normal = IDENTITY_QUATERNION;

		// Checking for an intersection with any of the spheres

		for (int i = 0; i < g_spheres.size(); i++)
		{
			bool intersectionExists = SphereIntersection_RT(g_spheres[i], v_intersection, v_outgoingDirection, &v_nextIntersection, &v_intersectionColor, &q_normal);

			bool b_rayIsBlocked = false;

			if (intersectionExists)
			{
				b_rayIsBlocked = IsRayBlocked(v_intersection, v_outgoingDirection, v_nextIntersection);
			}

			if (intersectionExists && b_rayIsBlocked == false)
			{
				Vec3D v_incomingLightColor = CalculateLighting_PathTracing(
					v_intersectionColor, g_spheres[i].material, q_normal, v_outgoingDirection, v_nextIntersection, i_bounceCount + 1
				);

				float attenuationFactor = exp(-attenuation * Distance3D(v_intersection, v_nextIntersection));

				if (reflectRay)
				{
					AddToVec3D(
						&v_outgoingLightColor,
						VecScalarMultiplication3D(v_incomingLightColor, 2 * reflectance * DotProduct3D(v_outgoingDirection, q_surfaceNormal.vecPart) * attenuationFactor * weight)
					);
				}
				else
				{
					AddToVec3D(
						&v_outgoingLightColor,
						VecScalarMultiplication3D(v_incomingLightColor, attenuationFactor * weight)
					);
				}

				return v_outgoingLightColor;
			}
		}

		// Checking for an intersection with any of the triangles

		for (int i = 0; i < g_triangles.size(); i++)
		{
			bool intersectionExists = TriangleIntersection_RT(g_triangles[i], v_intersection, v_outgoingDirection, &v_nextIntersection, &v_intersectionColor, &q_normal);

			bool b_rayIsBlocked = false;

			if (intersectionExists)
			{
				b_rayIsBlocked = IsRayBlocked(v_intersection, v_outgoingDirection, v_nextIntersection);
			}

			if (intersectionExists && b_rayIsBlocked == false)
			{
				Vec3D v_incomingLightColor = CalculateLighting_PathTracing(
					v_intersectionColor, g_triangles[i].material, q_normal, v_outgoingDirection, v_nextIntersection, i_bounceCount + 1
				);

				float attenuationFactor = exp(-attenuation * Distance3D(v_intersection, v_nextIntersection));

				if (reflectRay)
				{
					AddToVec3D(
						&v_outgoingLightColor,
						VecScalarMultiplication3D(v_incomingLightColor, 2 * reflectance * DotProduct3D(v_outgoingDirection, q_surfaceNormal.vecPart) * attenuationFactor * weight)
					);
				}
				else
				{
					AddToVec3D(
						&v_outgoingLightColor,
						VecScalarMultiplication3D(v_incomingLightColor, attenuationFactor * weight)
					);
				}

				return v_outgoingLightColor;
			}
		}

		// Checking for an intersection with the ground

		bool intersectionExists = GroundIntersection_RT(v_intersection, v_outgoingDirection, &v_nextIntersection, &v_intersectionColor, &q_normal);

		bool b_rayIsBlocked = false;

		if (intersectionExists)
		{
			b_rayIsBlocked = IsRayBlocked(v_intersection, v_outgoingDirection, v_nextIntersection);
		}

		if (intersectionExists && b_rayIsBlocked == false)
		{
			Vec3D v_incomingLightColor = CalculateLighting_PathTracing(
				v_intersectionColor, g_ground.material, q_normal, v_outgoingDirection, v_nextIntersection, i_bounceCount + 1
			);

			float attenuationFactor = exp(-attenuation * Distance3D(v_intersection, v_nextIntersection));

			if (reflectRay)
			{
				AddToVec3D(
					&v_outgoingLightColor,
					VecScalarMultiplication3D(v_incomingLightColor, 2 * reflectance * DotProduct3D(v_outgoingDirection, q_surfaceNormal.vecPart) * attenuationFactor * weight)
				);
			}
			else
			{
				AddToVec3D(
					&v_outgoingLightColor,
					VecScalarMultiplication3D(v_incomingLightColor, attenuationFactor * weight)
				);
			}

			return v_outgoingLightColor;
		}

		// Nothing was hit
		return v_outgoingLightColor;
	}

	Vec3D CalculateLighting_DistributionTracing(Vec3D v_objectColor, Material material, Vec3D v_surfaceNormal, Vec3D v_incomingDirection, Vec3D v_intersection, int i_bounceCount)
	{
		Vec3D v_pixelColor = ZERO_VEC3D;

		if (i_bounceCount > MAX_BOUNCES)
			return v_pixelColor;

		// Temporary until refraction (it'll need to decide whether to offset in or out)
		AddToVec3D(&v_intersection, VecScalarMultiplication3D(v_surfaceNormal, OFFSET_DISTANCE));

		// Soft shadows
		for (int i = 0; i < g_lights.size(); i++)
		{
			float notBlockedProportion = 0;

			for (int j = 0; j < SAMPLES_PER_RAY; j++)
			{
				Vec3D v_displacement = ReturnNormalizedVec3D(RandomVec_InUnitSphere());
				v_displacement = VecScalarMultiplication3D(v_displacement, g_lights[i].radius);
				Vec3D randomPointLight = AddVec3D(g_lights[i].coords, v_displacement);

				Vec3D v_newDirection = ReturnNormalizedVec3D(SubtractVec3D(randomPointLight, v_intersection));

				notBlockedProportion += !IsRayBlocked(v_intersection, v_newDirection, g_lights[i].coords);
			}

			notBlockedProportion /= SAMPLES_PER_RAY;

			float distance = Distance3D(v_intersection, g_lights[i].coords) - g_lights[i].radius;

			v_objectColor = VecScalarMultiplication3D(v_objectColor, 1 + material.emittance);
			Vec3D v_lightColor = VecScalarMultiplication3D(g_lights[i].tint, g_lights[i].emittance);

			// (objectColor + lightColor) * notBlockedProportion / (distance ^ 2)
			Vec3D v_shading = VecScalarMultiplication3D(VecScalarMultiplication3D(AddVec3D(v_objectColor, v_lightColor), notBlockedProportion), 1 / (distance * distance));

			AddToVec3D(&v_pixelColor, v_shading);
		}


		// Reflections
		Vec3D v_specularDirecion = SubtractVec3D(v_incomingDirection, VecScalarMultiplication3D(v_surfaceNormal, 2 * DotProduct3D(v_incomingDirection, v_surfaceNormal)));

		Vec3D v_reflectionIntersection, v_reflectionColor;
		Quaternion q_reflectionIntersectionNormal;
		Material newMaterial;

		if (material.reflectiveRoughness == 0)
		{
			// Specular reflections
			bool b_foundIntersection = FindIntersection(v_intersection, v_specularDirecion, &v_reflectionIntersection, &v_reflectionColor, &q_reflectionIntersectionNormal, &newMaterial);

			if (b_foundIntersection)
			{
				v_reflectionColor = CalculateLighting_DistributionTracing(
					v_reflectionColor, newMaterial, q_reflectionIntersectionNormal.vecPart, v_specularDirecion, v_intersection, i_bounceCount + 1
				);
			}
		}
		else
		{
			// Diffuse reflections
			int hitCount = 0;

			for (int i = 0; i < SAMPLES_PER_RAY; i++)
			{
				Vec3D v_lambertianDirection = ReturnNormalizedVec3D(RandomVec_InUnitSphere());
				if (DotProduct3D(v_lambertianDirection, v_surfaceNormal) < 0)
					v_lambertianDirection = VecScalarMultiplication3D(v_lambertianDirection, -1);

				Vec3D v_diffuseDirection = Lerp3D(v_specularDirecion, v_lambertianDirection, material.reflectiveRoughness);

				bool b_foundIntersection = FindIntersection(v_intersection, v_diffuseDirection, &v_reflectionIntersection, &v_reflectionColor, &q_reflectionIntersectionNormal, &newMaterial);

				if (b_foundIntersection)
				{
					AddToVec3D(&v_reflectionColor, CalculateLighting_DistributionTracing(
						v_reflectionColor, newMaterial, q_reflectionIntersectionNormal.vecPart, v_diffuseDirection, v_intersection, i_bounceCount + 1
					));
					hitCount++;
				}
			}

			if (hitCount > 0) v_reflectionColor = VecScalarMultiplication3D(v_reflectionColor, 1 / hitCount);
		}


		// Refraction
		// Tangent inside of the plane defined by v_surfaceNormal and v_incomingDirection
		Vec3D v_surfaceTangent = CrossProduct(ReturnNormalizedVec3D(CrossProduct(v_surfaceNormal, v_incomingDirection)), v_surfaceNormal);

		float sinIncomingAngle = DotProduct3D(v_incomingDirection, v_surfaceTangent);

		float sinRefractedAngle = Min(REFRACTION_INDEX_AIR * sinIncomingAngle / material.refractionIndex, 1.0f);

		float cosRefractedAngle = sqrt(1 - sinRefractedAngle * sinRefractedAngle); // Pythagorean identity

		//bool b_foundIntersection = FindIntersection(v_intersection, v_reflectedDirecion, &v_reflectionIntersection, &v_reflectionColor, &q_reflectionIntersectionNormal, &newMaterial);

		//if (b_foundIntersection)
		//	v_reflectionColor = CalculateLighting_DistributionTracing(
		//		v_reflectionColor, newMaterial, q_reflectionIntersectionNormal.vecPart, v_reflectedDirecion, v_intersection, ++i_bounceCount
		//	);


		// Fresnel for weighing reflection and refraction color
		float cosIncomingAngle = -DotProduct3D(v_incomingDirection, v_surfaceNormal);

		// Average of the s-polarized reflectance and p-polarized reflectance probabilities
		float fresnel = (
			Square((REFRACTION_INDEX_AIR * cosIncomingAngle - material.refractionIndex * cosRefractedAngle) / (REFRACTION_INDEX_AIR * cosIncomingAngle + material.refractionIndex * cosRefractedAngle)) +
			Square((REFRACTION_INDEX_AIR * cosRefractedAngle - material.refractionIndex * cosIncomingAngle) / (REFRACTION_INDEX_AIR * cosRefractedAngle + material.refractionIndex * cosIncomingAngle))
		) * 0.5f;

		float reflectance = Lerp(material.minReflectance, material.maxReflectance, fresnel);

		 //((1 - reflectance) * v_objectColor + reflectance * v_reflectionColor) / 2
		v_pixelColor = VecScalarMultiplication3D(AddVec3D(VecScalarMultiplication3D(v_objectColor, (1 - reflectance)), VecScalarMultiplication3D(v_reflectionColor, reflectance)), 0.5f);
		//v_pixelColor = VecScalarMultiplication3D(AddVec3D(v_objectColor, v_reflectionColor), 0.5f);

		return v_pixelColor;
	}

	bool FindIntersection(Vec3D v_start, Vec3D v_direction, Vec3D* v_intersection, Vec3D* v_color, Quaternion* q_normal, Material* material)
	{
		// Check ground
		bool groundIntersect = GroundIntersection_RT(v_start, v_direction, v_intersection, v_color, q_normal);

		if (groundIntersect && !IsRayBlocked(v_start, v_direction, *v_intersection))
		{
			*material = g_ground.material;
			return true;
		}

		// Check all spheres
		for (int i = 0; i < g_spheres.size(); i++)
		{
			bool sphereIntersect = SphereIntersection_RT(g_spheres[i], v_start, v_direction, v_intersection, v_color, q_normal);

			if (sphereIntersect && !IsRayBlocked(v_start, v_direction, *v_intersection))
			{
				*material = g_spheres[i].material;
				return true;
			}
		}

		// Check all triangles
		for (int i = 0; i < g_triangles.size(); i++)
		{
			bool triangleIntersect = TriangleIntersection_RT(g_triangles[i], v_start, v_direction, v_intersection, v_color, q_normal);

			if (triangleIntersect && !IsRayBlocked(v_start, v_direction, *v_intersection))
			{
				*material = g_triangles[i].material;
				return true;
			}
		}

		return false;
	}

	bool IsRayBlocked(Vec3D v_start, Vec3D v_direction, Vec3D v_intersection)
	{
		Vec3D v_otherIntersection = ZERO_VEC3D;

		for (int j = 0; j < g_spheres.size(); j++)
		{
			bool otherIntersectionExists = SphereIntersection_RT(g_spheres[j], v_start, v_direction, &v_otherIntersection);

			// If there exists a closer intersection to the ray start vector it means the ray is blocked
			if (otherIntersectionExists && DistanceSquared3D(v_start, v_otherIntersection) < DistanceSquared3D(v_start, v_intersection))
			{
				return true;
			}
		}

		for (int j = 0; j < g_triangles.size(); j++)
		{
			bool otherIntersectionExists = TriangleIntersection_RT(g_triangles[j], v_start, v_direction, &v_otherIntersection);

			// If there exists a closer intersection to the ray start vector it means the ray is blocked
			if (otherIntersectionExists && DistanceSquared3D(v_start, v_otherIntersection) < DistanceSquared3D(v_start, v_intersection))
			{
				return true;
			}
		}

		bool otherIntersectionExists = GroundIntersection_RT(v_start, v_direction, &v_otherIntersection);

		// If there exists a closer intersection to the ray start vector it means the ray is blocked
		if (otherIntersectionExists && DistanceSquared3D(v_start, v_otherIntersection) < DistanceSquared3D(v_start, v_intersection))
		{
			return true;
		}

		// The ray is not blocked
		return false;
	}

	Vec3D RandomVec_InUnitSphere()
	{
		Vec3D randPoint;

		do
		{
			float randX = float(int64_t(randEngine()) - int64_t(randEngine.max()) / 2) / (int64_t(randEngine.max()) / 2);
			float randY = float(int64_t(randEngine()) - int64_t(randEngine.max()) / 2) / (int64_t(randEngine.max()) / 2);
			float randZ = float(int64_t(randEngine()) - int64_t(randEngine.max()) / 2) / (int64_t(randEngine.max()) / 2);

			randPoint = { randX, randY, randZ };
		} while (VecLengthSquared(randPoint) > 1);

		return randPoint;
	}
};

int main()
{
	Engine rayTracer;
	if (rayTracer.Construct(SCREEN_WIDTH, SCREEN_HEIGHT, 1, 1))
		rayTracer.Start();
	return 0;
}

#include "Controlls.h"