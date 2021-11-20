#define OLC_PGE_APPLICATION
#define RAY_TRACER
#define PATH_TRACING 0

// Startup settings (cannot be changed during runtime)
#define ASYNC 1
#define THREAD_COUNT 4
#define SCREEN_WIDTH 900
#define SCREEN_HEIGHT 720
#define TOUCHING_DISTANCE 0.01f
#define OFFSET_DISTANCE 0.00001f
#define MAX_BOUNCES 15
#define SAMPLES_PER_PIXEL 20 // for path tracing
#define SAMPLES_PER_RAY 1 // for distribution ray tracing
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

std::vector<Sphere> g_spheres;
std::vector<Triangle> g_triangles;
std::vector<Light> g_lights;

Ground g_ground;

olc::Sprite* g_basketball_texture;
olc::Sprite* g_planks_texture;
olc::Sprite* g_concrete_texture;
olc::Sprite* g_tiledfloor_texture;
olc::Sprite* g_worldmap_texture;
olc::Sprite* g_bricks_texture;

olc::Sprite* g_basketball_normalmap;
olc::Sprite* g_planks_normalmap;
olc::Sprite* g_concrete_normalmap;
olc::Sprite* g_tiledfloor_normalmap;
olc::Sprite* g_worldmap_normalmap;
olc::Sprite* g_bricks_normalmap;

std::default_random_engine randEngine;

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
		g_bricks_texture = new olc::Sprite("../Assets/bricks.png");

		g_basketball_normalmap = new olc::Sprite("../Assets/basketball_normalmap.png");
		g_planks_normalmap = new olc::Sprite("../Assets/planks_normalmap.png");
		g_concrete_normalmap = new olc::Sprite("../Assets/concrete_normalmap.png");
		g_tiledfloor_normalmap = new olc::Sprite("../Assets/tiledfloor_normalmap.png");
		g_worldmap_normalmap = new olc::Sprite("../Assets/tiledfloor_normalmap.png");
		g_bricks_normalmap = new olc::Sprite("../Assets/bricks_normalmap.png");

		g_spheres =
		{
			// Lightsource
			{ { 1.5, 3, 1.5 }, 0.5, { { 45, 40, 30 }, { 0.9, 0.7, 0.1 }, { 0.9, 0.7, 0.1 }, 0.6, 1.6, 500 } },
			// Glossy ball
			{ { 1.5, 1.4, 1.5 }, 0.4, { { 0, 0, 0 }, { 1, 1, 1 }, { 1, 1, 1 }, 0.2, 15, 500 } },
			// Other lightsource
			{ { 0.5, 0.2, 0.7 }, 0.2, { { 30, 5, 10 }, { 0.9, 0.2, 0.4 }, { 0.9, 0.2, 0.4 }, 0.6, 1.6, 500 } },
			// Refractive ball
			{ { 1.5, 2.1, 0.25 }, 0.6, { { 0, 0, 0 }, { 0.2, 0.2, 0.2 }, { 0.2, 0.2, 0.2 }, 0.3, 1.56, 0 } }
			// Basket ball
			//{ { 2.5, 0.5, 0.8 }, 0.5, { 1, 1, 1 }, { 0.2, 0.6, 0.8, 0.9, { -1, 0, 0 }, 500, 2 }, g_basketball_texture, { 0, 0 }, { 1, 1 }, CreateRotationQuaternion(ReturnNormalizedVec3D({ 1, 0, 1 }), PI / 2) },
			// World atlas globe
			//{ { 1.75, 0.3, 0.5 }, 0.3, { 1, 1, 1 }, { 0.35, 0.7, 0.7, 0.9, { 1, 0, 0 }, 500, 1.45 }, g_worldmap_texture, { 0, 0 }, { 1, 1 }, CreateRotationQuaternion(ReturnNormalizedVec3D({ -1, 0.5, -2 }), PI / 2) },
			// Magenta lightsource
			//{ { 0.5, 0.4, 0.8 }, 0.4, { 1, 0.2, 0.4157 }, { 35, 0.2, 0.5, 0.95, { -1, 0, 0 }, 500, 1.6 } },
			// Refractive ball
			//{ { 1.1, 0.3, 0.4 }, 0.3, { 1, 1, 1 }, { 0.2, 0.2, 0.2, 0.95, { 1, 0, 0 }, 0.5, 1.4 } },
			// Cyan lightsource
			//{ { 2.4, 0.3, 1.75 }, 0.3, { 0.3, 1.15, 1.15 }, { 45, 0.2, 0.5, 0.95, { 1, 0, 0 }, 500, 1.6 } }
		};

		g_triangles =
		{
			// Walls first face
			{ { { 0, 0, 3 }, { 0, 3, 3 }, { 3, 3, 3 } }, { { 0, 0, 0 }, { 0.3, 0.2, 0.2 }, { 0.3, 0.2, 0.2 }, 0.975, 1.3, 500 }, "", g_bricks_texture, { { 0, 1 }, { 0, 0 }, { 1, 0 } } },
			{ { { 0, 0, 3 }, { 3, 3, 3 }, { 3, 0, 3 } }, { { 0, 0, 0 }, { 0.3, 0.2, 0.2 }, { 0.3, 0.2, 0.2 }, 0.975, 1.3, 500 }, "", g_bricks_texture, { { 0, 1 }, { 1, 0 }, { 1, 1 } } },
			// Walls second face														   
			{ { { 0, 0, 0 }, { 0, 3, 0 }, { 0, 3, 3 } }, { { 0, 0, 0 }, { 0.2, 0.4, 0.4 }, { 0.2, 0.4, 0.4 }, 0.975, 1.3, 500 }, "", g_concrete_texture, { { 0, 1 }, { 0, 0 }, { 1, 0 } } },
			{ { { 0, 0, 0 }, { 0, 3, 3 }, { 0, 0, 3 } }, { { 0, 0, 0 }, { 0.2, 0.4, 0.4 }, { 0.2, 0.4, 0.4 }, 0.975, 1.3, 500 }, "", g_concrete_texture, { { 0, 1 }, { 1, 0 }, { 1, 1 } } },
			// Walls third face															   
			{ { { 3, 0, 3 }, { 3, 3, 3 }, { 3, 3, 0 } }, { { 0, 0, 0 }, { 0.4, 0.2, 0.4 }, { 0.4, 0.2, 0.4 }, 0.975, 1.3, 500 }, "", g_concrete_texture, { { 0, 1 }, { 0, 0 }, { 1, 0 } } },
			{ { { 3, 0, 3 }, { 3, 3, 0 }, { 3, 0, 0 } }, { { 0, 0, 0 }, { 0.4, 0.2, 0.4 }, { 0.4, 0.2, 0.4 }, 0.975, 1.3, 500 }, "", g_concrete_texture, { { 0, 1 }, { 1, 0 }, { 1, 1 } } },
			// Walls fourth face														   
			{ { { 0, 3, 0 }, { 3, 3, 3 }, { 0, 3, 3 } }, { { 0, 0, 0 }, { 0.3, 0.3, 0.3 }, { 0.3, 0.3, 0.3 }, 0.975, 1.3, 500 }, "", g_concrete_texture, { { 0, 1 }, { 0, 0 }, { 1, 0 } } },
			{ { { 0, 3, 0 }, { 3, 3, 0 }, { 3, 3, 3 } }, { { 0, 0, 0 }, { 0.3, 0.3, 0.3 }, { 0.3, 0.3, 0.3 }, 0.975, 1.3, 500 }, "", g_concrete_texture, { { 0, 1 }, { 1, 0 }, { 1, 1 } } },

			// Box first face															   
			{ { { 1, 0, 2 }, { 2, 1, 2 }, { 1, 1, 2 } }, { { 0, 0, 0 }, { 0.4, 0.4, 0.4 }, { 0.4, 0.4, 0.4 }, 0.9, 1.7, 500 }, "", g_planks_texture, { { 0, 1 }, { 0, 0 }, { 1, 0 } } },
			{ { { 1, 0, 2 }, { 2, 0, 2 }, { 2, 1, 2 } }, { { 0, 0, 0 }, { 0.4, 0.4, 0.4 }, { 0.4, 0.4, 0.4 }, 0.9, 1.7, 500 }, "", g_planks_texture, { { 0, 1 }, { 1, 0 }, { 1, 1 } } },
			// Box second face											  				     
			{ { { 1, 0, 1 }, { 1, 1, 1 }, { 2, 1, 1 } }, { { 0, 0, 0 }, { 0.4, 0.4, 0.4 }, { 0.4, 0.4, 0.4 }, 0.9, 1.7, 500 }, "", g_planks_texture, { { 0, 1 }, { 0, 0 }, { 1, 0 } } },
			{ { { 1, 0, 1 }, { 2, 1, 1 }, { 2, 0, 1 } }, { { 0, 0, 0 }, { 0.4, 0.4, 0.4 }, { 0.4, 0.4, 0.4 }, 0.9, 1.7, 500 }, "", g_planks_texture, { { 0, 1 }, { 1, 0 }, { 1, 1 } } },
			// Box third face											 				    
			{ { { 1, 0, 1 }, { 1, 1, 2 }, { 1, 1, 1 } }, { { 0, 0, 0 }, { 0.4, 0.4, 0.4 }, { 0.4, 0.4, 0.4 }, 0.9, 1.7, 500 }, "", g_planks_texture, { { 0, 1 }, { 0, 0 }, { 1, 0 } } },
			{ { { 1, 0, 1 }, { 1, 0, 2 }, { 1, 1, 2 } }, { { 0, 0, 0 }, { 0.4, 0.4, 0.4 }, { 0.4, 0.4, 0.4 }, 0.9, 1.7, 500 }, "", g_planks_texture, { { 0, 1 }, { 1, 0 }, { 1, 1 } } },
			// Box fourth face							   				  				     
			{ { { 2, 0, 1 }, { 2, 1, 1 }, { 2, 1, 2 } }, { { 0, 0, 0 }, { 0.4, 0.4, 0.4 }, { 0.4, 0.4, 0.4 }, 0.9, 1.7, 500 }, "", g_planks_texture, { { 0, 1 }, { 0, 0 }, { 1, 0 } } },
			{ { { 2, 0, 1 }, { 2, 1, 2 }, { 2, 0, 2 } }, { { 0, 0, 0 }, { 0.4, 0.4, 0.4 }, { 0.4, 0.4, 0.4 }, 0.9, 1.7, 500 }, "", g_planks_texture, { { 0, 1 }, { 1, 0 }, { 1, 1 } } },
			// Box fifth face							   				  				     
			{ { { 1, 1, 1 }, { 1, 1, 2 }, { 2, 1, 2 } }, { { 0, 0, 0 }, { 0.4, 0.4, 0.4 }, { 0.4, 0.4, 0.4 }, 0.9, 1.7, 500 }, "", g_planks_texture, { { 0, 1 }, { 0, 0 }, { 1, 0 } } },
			{ { { 1, 1, 1 }, { 2, 1, 2 }, { 2, 1, 1 } }, { { 0, 0, 0 }, { 0.4, 0.4, 0.4 }, { 0.4, 0.4, 0.4 }, 0.9, 1.7, 500 }, "", g_planks_texture, { { 0, 1 }, { 1, 0 }, { 1, 1 } } },

			// refractive pyramid
			/*{ { { 0.9, 0 + 0.01, 2.9 - 0.7 }, { 0.5, 1.4 + 0.01, 2.5 - 0.7 }, { 0.1, 0 + 0.01, 2.9 - 0.7 } }, { 1, 1, 1 }, { 0.25, 0.4, 0.02, 0.95, { 0, 1, 0 }, 0, 1.52 } },
			{ { { 0.1, 0 + 0.01, 2.9 - 0.7 }, { 0.5, 1.4 + 0.01, 2.5 - 0.7 }, { 0.1, 0 + 0.01, 2.1 - 0.7 } }, { 1, 1, 1 }, { 0.25, 0.4, 0.02, 0.95, { 0, 1, 0 }, 0, 1.52 } },
			{ { { 0.1, 0 + 0.01, 2.1 - 0.7 }, { 0.5, 1.4 + 0.01, 2.5 - 0.7 }, { 0.9, 0 + 0.01, 2.1 - 0.7 } }, { 1, 1, 1 }, { 0.25, 0.4, 0.02, 0.95, { 0, 1, 0 }, 0, 1.52 } },
			{ { { 0.9, 0 + 0.01, 2.1 - 0.7 }, { 0.5, 1.4 + 0.01, 2.5 - 0.7 }, { 0.9, 0 + 0.01, 2.9 - 0.7 } }, { 1, 1, 1 }, { 0.25, 0.4, 0.02, 0.95, { 0, 1, 0 }, 0, 1.52 } },
			{ { { 0.9, 0 + 0.01, 2.9 - 0.7 }, { 0.1, 0 + 0.01, 2.9 - 0.7 }, { 0.1, 0 + 0.01, 2.1 - 0.7 } }, { 1, 1, 1 }, { 0.25, 0.4, 0.02, 0.95, { 1, 0, 0 }, 0, 1.52 } },
			{ { { 0.9, 0 + 0.01, 2.9 - 0.7 }, { 0.9, 0 + 0.01, 2.1 - 0.7 }, { 0.1, 0 + 0.01, 2.1 - 0.7 } }, { 1, 1, 1 }, { 0.25, 0.4, 0.02, 0.95, { 1, 0, 0 }, 0, 1.52 } },

			// other refractive pyramid
			{ { { 0.9 + 2, 0 + 0.01, 2.9 }, { 0.5 + 2, 1.4 + 0.01, 2.5 }, { 0.1 + 2, 0 + 0.01, 2.9 } }, { 0.6, 0.6, 1.5 }, { 0.3, 0.4, 0.02, 0.95, { 0, 1, 0 }, 0, 1.7 } },
			{ { { 0.1 + 2, 0 + 0.01, 2.9 }, { 0.5 + 2, 1.4 + 0.01, 2.5 }, { 0.1 + 2, 0 + 0.01, 2.1 } }, { 0.6, 0.6, 1.5 }, { 0.3, 0.4, 0.02, 0.95, { 0, 1, 0 }, 0, 1.7 } },
			{ { { 0.1 + 2, 0 + 0.01, 2.1 }, { 0.5 + 2, 1.4 + 0.01, 2.5 }, { 0.9 + 2, 0 + 0.01, 2.1 } }, { 0.6, 0.6, 1.5 }, { 0.3, 0.4, 0.02, 0.95, { 0, 1, 0 }, 0, 1.7 } },
			{ { { 0.9 + 2, 0 + 0.01, 2.1 }, { 0.5 + 2, 1.4 + 0.01, 2.5 }, { 0.9 + 2, 0 + 0.01, 2.9 } }, { 0.6, 0.6, 1.5 }, { 0.3, 0.4, 0.02, 0.95, { 0, 1, 0 }, 0, 1.7 } },
			{ { { 0.9 + 2, 0 + 0.01, 2.9 }, { 0.1 + 2, 0 + 0.01, 2.9 }, { 0.1 + 2, 0 + 0.01, 2.1 } }, { 0.6, 0.6, 1.5 }, { 0.3, 0.4, 0.02, 0.95, { 1, 0, 0 }, 0, 1.7 } },
			{ { { 0.9 + 2, 0 + 0.01, 2.9 }, { 0.9 + 2, 0 + 0.01, 2.1 }, { 0.1 + 2, 0 + 0.01, 2.1 } }, { 0.6, 0.6, 1.5 }, { 0.3, 0.4, 0.02, 0.95, { 1, 0, 0 }, 0, 1.7 } }*/
		};

		g_lights =
		{
			{ { 1.5, 3, 1.5 }, 0.5, 500, { 1, 0.8, 0.6 } }
		};
		g_ground = { 0, { { 0, 0, 0 }, { 0.4, 0.4, 0.4 }, { 0.4, 0.4, 0.4 }, 0.6, 2, 500 }, g_tiledfloor_texture, { 0, 0 }, { 1, 1 }, 1 };

#if ASYNC == 1
	//std::async(std::launch::async, ImportScene, &g_triangles, "../Assets/RubberDuck.obj", 0.4, Vec3D({ 0.8, 0.5, 0.5 }));
#else
	//ImportScene(&g_triangles, "../Assets/RubberDuck.obj", 0.4, { 0.8, 0.5, 0.5 });
#endif

		return true;
	}

	bool OnUserUpdate(float fElapsedTime) override
	{
		Timer timer("Rendering");

		Controlls(fElapsedTime);

#if ASYNC == 1
		// Screen split up into 4 quadrants running in parallell on seperate threads

		std::future<void> returnValues[THREAD_COUNT];

		for (int i = 0; i < THREAD_COUNT; i++)
		{
			int startX = i * ceil(SCREEN_WIDTH / float(THREAD_COUNT));
			int endX = (i + 1) * ceil(SCREEN_WIDTH / float(THREAD_COUNT));

			if (startX >= SCREEN_WIDTH)
			{
				break;
			}

			endX = Min(endX, SCREEN_WIDTH);

			returnValues[i] = std::async(std::launch::async, &Engine::RayTracing, this, startX, endX);
		}
#else
		RayTracing({ 0, 0 }, { SCREEN_WIDTH, SCREEN_HEIGHT });
#endif
		std::cout << "\a" << std::endl;

		return true;
	}

private:
	// Defined in Controlls.h
	void Controlls(float fElapsedTime);

	void RayTracing(int startX, int endX)
	{
		const float zFar = (SCREEN_WIDTH * 0.5f) / tan(g_player.FOV * 0.5f);

		for (float y = -SCREEN_HEIGHT * 0.5f + 0.5f; y < SCREEN_HEIGHT * 0.5f + 0.5f; y++)
		{
			for (float x = -SCREEN_WIDTH * 0.5f + 0.5f + startX; x < -SCREEN_WIDTH * 0.5f + 0.5f + endX; x++)
			{
				Vec3D v_direction = { x, y, zFar };

				Vec3D v_orientedDirection = QuaternionMultiplication(g_player.q_orientation, { 0, v_direction }, QuaternionConjugate(g_player.q_orientation)).vecPart;

				int screenX = x + SCREEN_WIDTH * 0.5f;
				int screenY = SCREEN_HEIGHT - (y + SCREEN_HEIGHT * 0.5f);

				Vec3D pixelColor = ZERO_VEC3D;

				for (int i = 0; i < SAMPLES_PER_PIXEL; i++)
				{
					// For anti-aliasing
					Vec3D v_jitteredDirection = AddVec3D(v_orientedDirection, RandomVec_InUnitSphere());

					NormalizeVec3D(&v_jitteredDirection);

					AddToVec3D(&pixelColor, RenderWorld(g_player.coords, v_jitteredDirection));
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

	Vec3D RenderWorld(Vec3D v_start, Vec3D v_direction)
	{
		Vec3D v_intersection = ZERO_VEC3D;
		Vec3D v_intersectionColor = ZERO_VEC3D;
		Quaternion q_surfaceNormal = IDENTITY_QUATERNION;

		for (int i = 0; i < g_spheres.size(); i++)
		{
			bool intersectionExists = SphereIntersection_RT(g_spheres[i], v_start, v_direction, &v_intersection, &v_intersectionColor, &q_surfaceNormal);

			bool b_isRayBlocked = true;

			if (intersectionExists)
			{
				b_isRayBlocked = IsRayBlocked(v_start, v_direction, v_intersection);
			}

			if (intersectionExists && b_isRayBlocked == false)
			{
				v_intersectionColor = CalculateLighting_PathTracing(
					v_intersectionColor, g_spheres[i].material, q_surfaceNormal, v_direction, v_intersection, 0
				);

				return v_intersectionColor;
			}
		}

		for (int i = 0; i < g_triangles.size(); i++)
		{
			bool intersectionExists = TriangleIntersection_RT(g_triangles[i], v_start, v_direction, &v_intersection, &v_intersectionColor, &q_surfaceNormal);

			bool b_isRayBlocked = true;

			if (intersectionExists)
			{
				b_isRayBlocked = IsRayBlocked(v_start, v_direction, v_intersection);
			}

			if (intersectionExists && b_isRayBlocked == false)
			{
				v_intersectionColor = CalculateLighting_PathTracing(
					v_intersectionColor, g_triangles[i].material, q_surfaceNormal, v_direction, v_intersection, 0
				);

				return v_intersectionColor;
			}
		}

		bool intersectionExists = GroundIntersection_RT(v_start, v_direction, &v_intersection, &v_intersectionColor, &q_surfaceNormal);

		if (intersectionExists)
		{
#if PATH_TRACING == 1
			v_intersectionColor = CalculateLighting_PathTracing(
				v_intersectionColor, g_ground.material, q_surfaceNormal, v_direction, v_intersection, 0
			);
#else
			v_intersectionColor = CalculateLighting_DistributionTracing(
				v_intersectionColor, g_ground.material, v_surfaceNormal, v_direction, v_intersection, 0
			);
#endif

			return v_intersectionColor;
		}

		return ZERO_VEC3D;
	}

	bool GroundIntersection_RT(Vec3D v_start, Vec3D v_direction,
		Vec3D* v_intersection = nullptr, Vec3D* v_intersectionColor = nullptr, Quaternion* q_surfaceNormal = nullptr)
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

	// Ray tracing for spheres
	bool SphereIntersection_RT(Sphere sphere, Vec3D v_start, Vec3D v_direction,
		Vec3D* v_intersection = nullptr, Vec3D* v_intersectionColor = nullptr, Quaternion* q_surfaceNormal = nullptr)
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

		// Calculating tangents of the sphere
		Vec3D v_sidewaysTangent = ReturnNormalizedVec3D({ -v_normal.z, 0, v_normal.x });
		Vec3D v_forwardTangent = ReturnNormalizedVec3D({ 0, -v_normal.z, v_normal.y });

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

		if (sphere.texture != nullptr || sphere.normalMap != nullptr)
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
		
		return true;
	}

	// Ray tracing for triangles
	bool TriangleIntersection_RT(Triangle triangle, Vec3D v_start, Vec3D v_direction,
		Vec3D* v_intersection = nullptr, Vec3D* v_intersectionColor = nullptr, Quaternion* q_surfaceNormal = nullptr)
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
		
		return true;
	}

	Vec3D LinePlaneIntersection(Vec3D v_start, Vec3D v_direction, Vec3D v_planeNormal, float f_planeOffset)
	{
		float f_deltaOffset = DotProduct3D(v_start, v_planeNormal);

		f_planeOffset -= f_deltaOffset;

		float f_scalingFactor = f_planeOffset / DotProduct3D(v_direction, v_planeNormal);

		return AddVec3D(VecScalarMultiplication3D(v_direction, f_scalingFactor), v_start);
	}

	Vec3D CalculateLighting_PathTracing(Vec3D v_textureColor, Material material, Quaternion q_surfaceNormal, Vec3D v_incomingDirection, Vec3D v_intersection, int i_bounceCount)
	{
		Vec3D v_outgoingLightColor = ConusProduct(v_textureColor, material.emittance);

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

#define SHRINKING_BIAS 0.1 // empirically found to be pretty good

		// Having the actual probability of reflectance given solely by the fresnel factor wastes a lot of rays. Therefore it is biased according to the attenuation of the material
		float refractionProbability = exp(-material.attenuation * SHRINKING_BIAS) * 0.9;

		bool refractRay = (float(int64_t(randEngine())) / float(int64_t(randEngine.max()))) < refractionProbability;

		float weight = 1 / refractionProbability;

		if (refractRay)
		{
			v_outgoingDirection = ReturnNormalizedVec3D(RandomVec_InUnitSphere());

			if (DotProduct3D(v_outgoingDirection, q_surfaceNormal.vecPart) > 0)
			{
				// The vector is in the wrong hemisphere, so we flip it
				ScaleVec3D(&v_outgoingDirection, -1);
			}

			AddToVec3D(&v_intersection, VecScalarMultiplication3D(v_outgoingDirection, OFFSET_DISTANCE));

			if (q_surfaceNormal.realPart == 1)
			{
				// The ray is refracting into the object
				attenuation = material.attenuation;
			}
		}
		else
		{
			v_outgoingDirection = ReturnNormalizedVec3D(RandomVec_InUnitSphere());

			if (DotProduct3D(v_outgoingDirection, q_surfaceNormal.vecPart) < 0)
			{
				// The vector is in the wrong hemisphere, so we flip it
				ScaleVec3D(&v_outgoingDirection, -1);
			}

			AddToVec3D(&v_intersection, VecScalarMultiplication3D(v_outgoingDirection, OFFSET_DISTANCE));

			if (q_surfaceNormal.realPart == -1)
			{
				// The ray is reflecting into the object
				attenuation = material.attenuation;
			}

			weight = 1 / (1 - refractionProbability);
		}

		Vec3D v_nextIntersection = ZERO_VEC3D;
		Vec3D v_nextIntersectionColor = ZERO_VEC3D;
		Quaternion q_nextNormal = IDENTITY_QUATERNION;
		Material nextMaterial;

		bool intersectionExists = NextIntersection(v_intersection, v_outgoingDirection, &v_nextIntersection, &v_nextIntersectionColor, &q_nextNormal, &nextMaterial);

		if (intersectionExists)
		{
			Vec3D v_incomingLightColor = CalculateLighting_PathTracing(
				v_nextIntersectionColor, nextMaterial, q_nextNormal, v_outgoingDirection, v_nextIntersection, i_bounceCount + 1
			);

			Vec3D v_diffuseTint = VecScalarMultiplication3D(ConusProduct(v_textureColor, material.diffuseTint), 1.0f / 255);
			Vec3D v_specularTint = VecScalarMultiplication3D(ConusProduct(v_textureColor, material.specularTint), 1.0f / 255);

			float attenuationFactor = exp(-attenuation * Distance3D(v_intersection, v_nextIntersection));
			
			if(refractRay)
			{
				AddToVec3D(
					&v_outgoingLightColor,
					VecScalarMultiplication3D(
						v_incomingLightColor, BTDF(v_incomingDirection, v_outgoingDirection, q_surfaceNormal.vecPart, refractionIndex1, refractionIndex2, material.roughness) * attenuationFactor * weight * TAU
					)
				);
			}
			else
			{
				AddToVec3D(
					&v_outgoingLightColor,
					VecScalarMultiplication3D(
						ConusProduct(v_incomingLightColor, BRDF(v_incomingDirection, v_outgoingDirection, q_surfaceNormal.vecPart, refractionIndex1, refractionIndex2, material.roughness, v_diffuseTint, v_specularTint)),
						DotProduct3D(v_outgoingDirection, q_surfaceNormal.vecPart) * attenuationFactor * weight * TAU
					)
				);
			}
		}

		return v_outgoingLightColor;
	}

	bool NextIntersection(Vec3D v_start, Vec3D v_direction, Vec3D* v_intersection, Vec3D* v_intersectionColor, Quaternion* q_normal, Material* material)
	{
		for (int i = 0; i < g_spheres.size(); i++)
		{
			bool intersectionExists = SphereIntersection_RT(g_spheres[i], v_start, v_direction, v_intersection, v_intersectionColor, q_normal);

			bool b_rayIsBlocked = false;

			if (intersectionExists)
			{
				b_rayIsBlocked = IsRayBlocked(v_start, v_direction, *v_intersection);
			}

			if (intersectionExists && b_rayIsBlocked == false)
			{
				*material = g_spheres[i].material;

				return true;
			}
		}

		for (int i = 0; i < g_triangles.size(); i++)
		{
			bool intersectionExists = TriangleIntersection_RT(g_triangles[i], v_start, v_direction, v_intersection, v_intersectionColor, q_normal);

			bool b_rayIsBlocked = false;

			if (intersectionExists)
			{
				b_rayIsBlocked = IsRayBlocked(v_start, v_direction, *v_intersection);
			}

			if (intersectionExists && b_rayIsBlocked == false)
			{
				*material = g_triangles[i].material;

				return true;
			}
		}

		bool intersectionExists = GroundIntersection_RT(v_start, v_direction, v_intersection, v_intersectionColor, q_normal);

		if (intersectionExists)
		{
			*material = g_ground.material;

			return true;
		}

		return false;
	}

	Vec3D CalculateLighting_DistributionTracing(Vec3D v_objectColor, Material material, Vec3D v_surfaceNormal, Vec3D v_incomingDirection, Vec3D v_intersection, int i_bounceCount)
	{
		Vec3D pixelColor = ZERO_VEC3D;

		// Temporary until refraction (it'll need to decide whether to offset in or out)
		AddToVec3D(&v_intersection, VecScalarMultiplication3D(v_surfaceNormal, OFFSET_DISTANCE));

		// Soft shadows
		for (int i = 0; i < g_lights.size(); i++)
		{
			float notBlockedProportion = 0;

			for (int j = 0; j < SAMPLES_PER_RAY; j++)
			{
				float randX = float(int64_t(randEngine()) - int64_t(randEngine.max()) / 2) / float(int64_t(randEngine.max()) / 2);
				float randY = float(int64_t(randEngine()) - int64_t(randEngine.max()) / 2) / float(int64_t(randEngine.max()) / 2);
				float randZ = float(int64_t(randEngine()) - int64_t(randEngine.max()) / 2) / float(int64_t(randEngine.max()) / 2);
				Vec3D v_displacement = { randX, randY, randZ };
				NormalizeVec3D(&v_displacement);
				v_displacement = VecScalarMultiplication3D(v_displacement, g_lights[i].radius);
				Vec3D randomPointLight = AddVec3D(g_lights[i].coords, v_displacement);

				Vec3D v_newDirection = ReturnNormalizedVec3D(SubtractVec3D(randomPointLight, v_intersection));

				notBlockedProportion += !IsRayBlocked(v_intersection, v_newDirection, g_lights[i].coords);
			}

			notBlockedProportion /= SAMPLES_PER_RAY;

			float distance = Distance3D(v_intersection, g_lights[i].coords) - g_lights[i].radius;

			//v_objectColor = VecScalarMultiplication3D(v_objectColor, material.emittance);
			Vec3D lightColor = VecScalarMultiplication3D(g_lights[i].tint, g_lights[i].emittance);

			// (objectColor + lightColor) * notBlockedProportion / (distance ^ 2)
			Vec3D v_shading = VecScalarMultiplication3D(VecScalarMultiplication3D(AddVec3D(v_objectColor, lightColor), notBlockedProportion), 1.0f / (distance * distance));

			AddToVec3D(&pixelColor, v_shading);
		}

		// Reflection


		// Refraction

		return pixelColor;
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

	// Cook-Torrance BRDF with GGX distribution function and GGX geometry function
	Vec3D BRDF(Vec3D v_incomingDirection, Vec3D v_outgoingDirection, Vec3D v_normal, float refractionIndex1, float refractionIndex2, float roughness, Vec3D v_diffuseTint, Vec3D v_specularTint)
	{
		ScaleVec3D(&v_incomingDirection, -1);

		Vec3D v_bisectorVector = ReturnNormalizedVec3D(Lerp3D(v_incomingDirection, v_outgoingDirection, 0.5));

		float fresnelFactor = Fresnel(v_incomingDirection, v_bisectorVector, refractionIndex1, refractionIndex2);

		float diffuseTerm = (1 - fresnelFactor) / PI;

		float specularTerm = fresnelFactor * GeometryBidirectional(v_incomingDirection, v_outgoingDirection, v_normal, v_bisectorVector, roughness) * Distribution(v_normal, v_bisectorVector, roughness) /
			(4 * DotProduct3D(v_incomingDirection, v_normal) * DotProduct3D(v_outgoingDirection, v_normal));

		return AddVec3D(VecScalarMultiplication3D(v_diffuseTint, diffuseTerm), VecScalarMultiplication3D(v_specularTint, specularTerm));
	}

	float Chi(float x)
	{
		return x > 0 ? 1 : 0;
	}

	float Distribution(Vec3D v_normal, Vec3D v_bisectorVector, float roughness)
	{
		float bisectDotNormal = DotProduct3D(v_bisectorVector, v_normal);
		float bisectDotNormal2 = bisectDotNormal * bisectDotNormal;
		float roughness2 = roughness * roughness;

		return (Chi(DotProduct3D(v_bisectorVector, v_normal)) * roughness2) / (PI * Square(bisectDotNormal2 * (roughness2 + (1 - bisectDotNormal2) / bisectDotNormal2)));
	}

	float Fresnel(Vec3D v_incomingDirection, Vec3D v_bisectorVector, float refractionIndex1, float refractionIndex2)
	{
		float c = DotProduct3D(v_incomingDirection, v_bisectorVector);

		float g = sqrt(Max((refractionIndex2 * refractionIndex2) / (refractionIndex1 * refractionIndex1) - 1 + c * c, 0));

		return 0.5 * (Square(g - c) / Square(g + c)) * (1 + Square(c * (g + c) - 1) / Square(c * (g - c) + 1));
	}

	float GeometryBidirectional(Vec3D v_incomingDirection, Vec3D v_outgoingDirection, Vec3D v_normal, Vec3D v_bisectorVector, float roughness)
	{
		return GeometryMonodirectional(v_incomingDirection, v_normal, v_bisectorVector, roughness) * GeometryMonodirectional(v_outgoingDirection, v_normal, v_bisectorVector, roughness);
	}

	float GeometryMonodirectional(Vec3D vec, Vec3D v_normal, Vec3D v_bisectorVector, float roughness)
	{
		float VecDotNormal = DotProduct3D(vec, v_normal);
		float VecDotNormal2 = VecDotNormal * VecDotNormal;
		float a = 1.0f / (roughness * sqrt(1 - VecDotNormal2) / VecDotNormal);
		float a2 = a * a;

		return Chi(DotProduct3D(vec, v_bisectorVector) / DotProduct3D(vec, v_normal)) * (a < 1.59 ? (3.535 * a + 2.181 * a2) / (1 + 2.276 * a + 2.577 * a2) : 1);
	}

	float BTDF(Vec3D v_incomingDirection, Vec3D v_outgoingDirection, Vec3D v_normal, float refractionIndex1, float refractionIndex2, float roughness)
	{
		ScaleVec3D(&v_normal, -1);

		Vec3D v_bisectorVector = ReturnNormalizedVec3D(Lerp3D(v_incomingDirection, v_outgoingDirection, 0.5));

		float incomingDotBisector = DotProduct3D(v_incomingDirection, v_bisectorVector);
		float outgoingDotBisector = DotProduct3D(v_outgoingDirection, v_bisectorVector);

		return (incomingDotBisector * outgoingDotBisector) / (DotProduct3D(v_incomingDirection, v_normal) * DotProduct3D(v_outgoingDirection, v_normal)) *
			(refractionIndex2 * refractionIndex2 * (1 - Fresnel(v_incomingDirection, v_bisectorVector, refractionIndex1, refractionIndex2)) * GeometryBidirectional(v_incomingDirection, v_outgoingDirection, v_normal, v_bisectorVector, roughness) *
				Distribution(v_normal, v_bisectorVector, roughness)) / Square(refractionIndex1 * incomingDotBisector + refractionIndex2 * outgoingDotBisector);
	}

	Vec3D RandomVec_InUnitSphere()
	{
		Vec3D randPoint;

		do
		{
			float randX = float(int64_t(randEngine()) - int64_t(randEngine.max()) / 2) / float(int64_t(randEngine.max()) / 2);
			float randY = float(int64_t(randEngine()) - int64_t(randEngine.max()) / 2) / float(int64_t(randEngine.max()) / 2);
			float randZ = float(int64_t(randEngine()) - int64_t(randEngine.max()) / 2) / float(int64_t(randEngine.max()) / 2);

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