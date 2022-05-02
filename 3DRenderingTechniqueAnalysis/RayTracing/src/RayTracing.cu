#define OLC_PGE_APPLICATION
#define RAY_TRACER
#define PATH_TRACING 0 // 0: distribution tracing, 1: path tracing

// Startup settings (cannot be changed during runtime)
#define ASYNC 1
#define THREAD_COUNT 4
#define SCREEN_WIDTH 900
#define SCREEN_HEIGHT 720
#define OFFSET_DISTANCE 0.0001
#define MOVE_DISTANCE 0.01
#define SAMPLES_PER_PIXEL 1000 // for path tracing
#define AMBIENT_LIGHT { 0, 0, 0 } //{ 27.5, 35, 55 } // sky light basically
#define GAUSSIAN_BLUR 1 // blur for denoising
#define MEDIAN_FILTER 0 // used for firefly reduction and denoising, bad for low spp
#define REFLECTIONS 1 // ON or OFF
#define MAX_COLOR_VALUE 1000000 // used for reducing fireflies, introduces bias
#define MAX_BOUNCES 2 // For distribution ray tracing
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

Vec3D screenBuffer[SCREEN_HEIGHT * SCREEN_WIDTH];

Player g_player;

std::vector<Sphere> g_spheres;
std::vector<Triangle> g_triangles;
std::vector<Light> g_lights;

Ground g_ground;

// Textures
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

std::random_device seedEngine;
std::uniform_real_distribution<> uniformDistribution(-1, 1);
std::uniform_real_distribution<> uniform_zero_to_one(0, 1);

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
		//g_player = { { 1.5, 0.5, -0.5 }, { 1, ZERO_VEC3D }, TAU * 0.2f };

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
			/* FIRST BALLS */

			/*// Lightsource
			{ { 1.5, 3, 1.5 }, 0.5, { { 45, 40, 30 }, { 0.9, 0.7, 0.1 }, { 0.9, 0.7, 0.1 }, 0.6, 1.6, { 500, 500, 500 } } },
			// Glossy ball
			{ { 1.5, 1.4, 1.5 }, 0.4, { { 0, 0, 0 }, { 0.8, 0.8, 0.8 }, { 0.8, 0.8, 0.8 }, 0.05, 12.5, { 500, 500, 500 } } },
			// Other lightsource
			{ { 0.6, 0.3, 0.85 }, 0.3, { { 30, 5, 10 }, { 0.9, 0.2, 0.4 }, { 0.9, 0.2, 0.4 }, 0.6, 1.6, { 500, 500, 500 } } },
			// Other lightsource
			{ { 1.9, 0.3, 0.5 }, 0.3, { { 2.25, 13.1, 18.7 }, { 0.9, 0.2, 0.4 }, { 0.9, 0.2, 0.4 }, 0.6, 1.6, { 500, 500, 500 } } },
			// Refractive ball
			{ { 2.5, 0.5, 2.2 }, 0.5, { { 0, 0, 0 }, { 0.02, 0.02, 0.02 }, { 0.4, 0.4, 0.4 }, 0.05, 1.52, { 0, 0, 0 } } }*/

			/* SECOND BALLS */

			//{ { 1.5, 3, 1.5 }, 0.5, { { 45, 40, 30 }, { 0.9, 0.7, 0.1 }, 0.5, 0.6, 1.6, { 500, 500, 500 }, 0, DIELECTRIC } },

			{ { 1.5, 0.7, 1.5 }, 0.7, { { 0, 0, 0 }, { 0, 0, 0 }, 0.8, 0.002, 1.04, { 0, 1, 0.666 }, 0, DIELECTRIC } }, // old IOR = 1.04
			//{ { 1.5, 0.7, 1.5 }, 0.7, { { 0, 0, 0 }, { 0.8, 0.2, 0.4 }, 0.8, 0.05, 12.5, { 500, 500, 500 }, 0, PLASTIC } },
			//{ { 1.5, 0.7, 1.5 }, 0.7, { { 0, 0, 0 }, { 0.843, 0.7176, 0.251 }, 0.8, 0.01, 10, { 500, 500, 500 }, 2.92, DIELECTRIC } },

			{ { 0.5, 0.45, 2.1 }, 0.45, { { 0, 0, 0 }, { 1.0, 0.851246, 0.301305 }, 0.8, 0.1, 0.277, { 500, 500, 500 }, 2.92, METAL } },

			{ { 2.5, 0.45, 2.1 }, 0.45, { { 0, 0, 0 }, { 0.31627, 0.95295, 0.56719 }, 0.85, 0.1, 3, { 500, 500, 500 }, 0, PLASTIC } },

			// Other Refractive ball
			//{ { 1.5, 2.3, 0.3 }, 0.5, { { 0, 0, 0 }, { 0.2, 0.2, 0.2 }, { 0.2, 0.2, 0.2 }, 0.3, 1.52, { 0, 0, 0 } } }
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
			// Walls north face
			{ { { 0, 0, 3 }, { 0, 3, 3 }, { 3, 3, 3 } }, { { 0, 0, 0 }, { 0.9, 0.9, 0.9 }, 0.2, 0.975, 1.3, { 500, 500, 500 }, 0, DIELECTRIC }/*, "", g_bricks_texture, { { 0, 1 }, { 0, 0 }, { 1, 0 } },     g_bricks_normalmap*/ },
			{ { { 0, 0, 3 }, { 3, 3, 3 }, { 3, 0, 3 } }, { { 0, 0, 0 }, { 0.9, 0.9, 0.9 }, 0.2, 0.975, 1.3, { 500, 500, 500 }, 0, DIELECTRIC }/*, "", g_bricks_texture, { { 0, 1 }, { 1, 0 }, { 1, 1 } },     g_bricks_normalmap*/ },
			// Walls west face														   													  
			{ { { 0, 0, 0 }, { 0, 3, 0 }, { 0, 3, 3 } }, { { 0, 0, 0 }, { 0.9, 0.2, 0.1 }, 0.2, 0.975, 1.3, { 500, 500, 500 }, 0, DIELECTRIC }/*, "", g_concrete_texture, { { 0, 1 }, { 0, 0 }, { 1, 0 } }, g_concrete_normalmap*/ },
			{ { { 0, 0, 0 }, { 0, 3, 3 }, { 0, 0, 3 } }, { { 0, 0, 0 }, { 0.9, 0.2, 0.1 }, 0.2, 0.975, 1.3, { 500, 500, 500 }, 0, DIELECTRIC }/*, "", g_concrete_texture, { { 0, 1 }, { 1, 0 }, { 1, 1 } }, g_concrete_normalmap*/ },
			// Walls east face
			{ { { 3, 0, 3 }, { 3, 3, 3 }, { 3, 3, 0 } }, { { 0, 0, 0 }, { 0.1, 0.9, 0.3 }, 0.2, 0.975, 1.3, { 500, 500, 500 }, 0, DIELECTRIC }/*, "", g_concrete_texture, { { 0, 1 }, { 0, 0 }, { 1, 0 } }, g_concrete_normalmap*/ },
			{ { { 3, 0, 3 }, { 3, 3, 0 }, { 3, 0, 0 } }, { { 0, 0, 0 }, { 0.1, 0.9, 0.3 }, 0.2, 0.975, 1.3, { 500, 500, 500 }, 0, DIELECTRIC }/*, "", g_concrete_texture, { { 0, 1 }, { 1, 0 }, { 1, 1 } }, g_concrete_normalmap*/ },
			// Walls ceiling
			{ { { 0, 3, 0 }, { 3, 3, 3 }, { 0, 3, 3 } }, { { 0, 0, 0 }, { 0.9, 0.9, 0.9 }, 0.2, 0.975, 1.3, { 500, 500, 500 }, 0, DIELECTRIC }/*, "", g_concrete_texture, { { 0, 1 }, { 0, 0 }, { 1, 0 } }, g_concrete_normalmap*/ },
			{ { { 0, 3, 0 }, { 3, 3, 0 }, { 3, 3, 3 } }, { { 0, 0, 0 }, { 0.9, 0.9, 0.9 }, 0.2, 0.975, 1.3, { 500, 500, 500 }, 0, DIELECTRIC }/*, "", g_concrete_texture, { { 0, 1 }, { 1, 0 }, { 1, 1 } }, g_concrete_normalmap*/ },

			// Tall box north face
			{ { { 0.5, 0, 2.5 }, { 1.25, 1.58, 2.75 }, { 1.25, 0, 2.75 } },				{ { 0, 0, 0 }, { 0.8, 0.8, 0.8 }, 0.4, 0.9, 1.7, { 500, 500, 500 }, 0, DIELECTRIC } },
			{ { { 0.5, 0, 2.5 }, { 0.5, 1.58, 2.5 }, { 1.25, 1.58, 2.75 } },			{ { 0, 0, 0 }, { 0.8, 0.8, 0.8 }, 0.4, 0.9, 1.7, { 500, 500, 500 }, 0, DIELECTRIC } },
			// Tall box south face
			{ { { 0.75, 0, 1.75 }, { 1.5, 1.58, 2 }, { 1.5, 0, 2 } },					{ { 0, 0, 0 }, { 0.8, 0.8, 0.8 }, 0.4, 0.9, 1.7, { 500, 500, 500 }, 0, DIELECTRIC } },
			{ { { 0.75, 0, 1.75 }, { 0.75, 1.58, 1.75 }, { 1.5, 1.58, 2 } },			{ { 0, 0, 0 }, { 0.8, 0.8, 0.8 }, 0.4, 0.9, 1.7, { 500, 500, 500 }, 0, DIELECTRIC } },
			// Tall box west face
			{ { { 0.5, 0, 2.5 }, { 0.75, 1.58, 1.75 }, { 0.75, 0, 1.75 } },				{ { 0, 0, 0 }, { 0.8, 0.8, 0.8 }, 0.4, 0.9, 1.7, { 500, 500, 500 }, 0, DIELECTRIC } },
			{ { { 0.5, 0, 2.5 }, { 0.5, 1.58, 2.5 }, { 0.75, 1.58, 1.75 } },			{ { 0, 0, 0 }, { 0.8, 0.8, 0.8 }, 0.4, 0.9, 1.7, { 500, 500, 500 }, 0, DIELECTRIC } },
			// Tall box east face
			{ { { 1.5, 0, 2 }, { 1.25, 1.58, 2.75 }, { 1.25, 0, 2.75 } },				{ { 0, 0, 0 }, { 0.8, 0.8, 0.8 }, 0.4, 0.9, 1.7, { 500, 500, 500 }, 0, DIELECTRIC } },
			{ { { 1.5, 0, 2 }, { 1.5, 1.58, 2 }, { 1.25, 1.58, 2.75 } }, 				{ { 0, 0, 0 }, { 0.8, 0.8, 0.8 }, 0.4, 0.9, 1.7, { 500, 500, 500 }, 0, DIELECTRIC } },
			// Tall box top face
			{ { { 0.75, 1.58, 1.75 }, { 1.25, 1.58, 2.75 }, { 1.5, 1.58, 2 } },			{ { 0, 0, 0 }, { 0.8, 0.8, 0.8 }, 0.4, 0.9, 1.7, { 500, 500, 500 }, 0, DIELECTRIC } },
			{ { { 0.75, 1.58, 1.75 }, { 0.5, 1.58, 2.5 }, { 1.25, 1.58, 2.75 } },		{ { 0, 0, 0 }, { 0.8, 0.8, 0.8 }, 0.4, 0.9, 1.7, { 500, 500, 500 }, 0, DIELECTRIC } },

			// Box north face															   
			{ { { 1.625, 0, 1.5 }, { 2.375, 0.79, 1.25 }, { 2.375, 0, 1.25 } },			{ { 0, 0, 0 }, { 0.8, 0.8, 0.8 }, 0.4, 0.9, 1.7, { 500, 500, 500 }, 0, DIELECTRIC } },
			{ { { 1.625, 0, 1.5 }, { 1.625, 0.79, 1.5 }, { 2.375, 0.79, 1.25 } },		{ { 0, 0, 0 }, { 0.8, 0.8, 0.8 }, 0.4, 0.9, 1.7, { 500, 500, 500 }, 0, DIELECTRIC } },
			// Box south face
			{ { { 1.375, 0, 0.75 }, { 2.125, 0.79, 0.5 }, { 2.125, 0, 0.5 } },			{ { 0, 0, 0 }, { 0.8, 0.8, 0.8 }, 0.4, 0.9, 1.7, { 500, 500, 500 }, 0, DIELECTRIC } },
			{ { { 1.375, 0, 0.75 }, { 1.375, 0.79, 0.75 }, { 2.125, 0.79, 0.5 } },		{ { 0, 0, 0 }, { 0.8, 0.8, 0.8 }, 0.4, 0.9, 1.7, { 500, 500, 500 }, 0, DIELECTRIC } },
			// Box west face
			{ { { 1.625, 0, 1.5 }, { 1.375, 0.79, 0.75 }, { 1.375, 0, 0.75 } },			{ { 0, 0, 0 }, { 0.8, 0.8, 0.8 }, 0.4, 0.9, 1.7, { 500, 500, 500 }, 0, DIELECTRIC } },
			{ { { 1.625, 0, 1.5 }, { 1.625, 0.79, 1.5 }, { 1.375, 0.79, 0.75 } },		{ { 0, 0, 0 }, { 0.8, 0.8, 0.8 }, 0.4, 0.9, 1.7, { 500, 500, 500 }, 0, DIELECTRIC } },
			// Box east face
			{ { { 2.375, 0, 1.25 }, { 2.125, 0.79, 0.5 }, { 2.125, 0, 0.5 } },			{ { 0, 0, 0 }, { 0.8, 0.8, 0.8 }, 0.4, 0.9, 1.7, { 500, 500, 500 }, 0, DIELECTRIC } },
			{ { { 2.375, 0, 1.25 }, { 2.375, 0.79, 1.25 }, { 2.125, 0.79, 0.5 } },		{ { 0, 0, 0 }, { 0.8, 0.8, 0.8 }, 0.4, 0.9, 1.7, { 500, 500, 500 }, 0, DIELECTRIC } },
			// Box top face
			{ { { 1.375, 0.79, 0.75 }, { 2.375, 0.79, 1.25 }, { 2.125, 0.79, 0.5 } },	{ { 0, 0, 0 }, { 0.8, 0.8, 0.8 }, 0.4, 0.9, 1.7, { 500, 500, 500 }, 0, DIELECTRIC } },
			{ { { 1.375, 0.79, 0.75 }, { 1.625, 0.79, 1.5 }, { 2.375, 0.79, 1.25 } },	{ { 0, 0, 0 }, { 0.8, 0.8, 0.8 }, 0.4, 0.9, 1.7, { 500, 500, 500 }, 0, DIELECTRIC } },

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

		g_ground = { 0, { { 0, 0, 0 }, { 1, 1, 1 }, 0.3, 0.6, 2, { 500, 500, 500 }, 0, DIELECTRIC }, g_tiledfloor_texture, { 0, 0 }, { 1, 1 }, 1, g_tiledfloor_normalmap };

#if PATH_TRACING == 0
		g_lights =
		{
			//{ { 1.5, 2.7, 1.5 }, 0.3, { 45, 40, 30 } },
			{ { 1.5, 2.7, 1.5 }, 0.3, { 30, 26.67, 20 } },
			//{ { 1.5, 2.7, 1.5 }, 0.3, { 39.3, 45.3, 20 } },
			//{ { 0, 0, -1005 }, 1000, { 45, 40, 30 } } // Giant light source
		};

		// Insert all light sources into sphere list to make them visible
		for (int i = 0; i < g_lights.size(); i++)
			g_spheres.push_back({ g_lights[i].coords, g_lights[i].radius - 0.1, { g_lights[i].emittance, ZERO_VEC3D, 0, 0, 1, { 0, 0, 0 } } });
#endif

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

		StartThreads();

#if GAUSSIAN_BLUR == 1
		GaussianBlur();
#endif

#if MEDIAN_FILTER == 1
		MedianFiltering();
#endif

		for (int y = 0; y < SCREEN_HEIGHT; y++)
		{
			for (int x = 0; x < SCREEN_WIDTH; x++)
			{
				Vec3D pixelColor = screenBuffer[y * SCREEN_WIDTH + x];

				Draw(x, y, { uint8_t(pixelColor.x), uint8_t(pixelColor.y), uint8_t(pixelColor.z) });
			}
		}

		std::cout << "\a" << std::endl;

		return true;
	}

	void StartThreads()
	{
#if ASYNC == 1
		// Screen split up into 4 quadrants running in parallell on seperate threads

		std::future<void> returnValues[THREAD_COUNT];

		for (int i = 0; i < THREAD_COUNT; i++)
		{
			int startX = i * ceil(SCREEN_WIDTH / double(THREAD_COUNT));
			int endX = (i + 1) * ceil(SCREEN_WIDTH / double(THREAD_COUNT));

			if (startX >= SCREEN_WIDTH)
			{
				break;
			}

			endX = Min(endX, SCREEN_WIDTH);

			std::mt19937 randomEngine(seedEngine());

			returnValues[i] = std::async(std::launch::async, &Engine::RayTracing, this, startX, endX, randomEngine);
		}
#else
		std::mt19937 randomEngine(seedEngine());
		RayTracing(0, SCREEN_WIDTH, randomEngine);
#endif
	}

private:
	// Defined in Controlls.h
	void Controlls(float fElapsedTime);

	void RayTracing(int startX, int endX, std::mt19937 randomEngine)
	{
		const double zFar = (SCREEN_WIDTH * 0.5f) / tan(g_player.FOV * 0.5f);

		for (double y = -SCREEN_HEIGHT * 0.5f + 0.5f; y < SCREEN_HEIGHT * 0.5f + 0.5f; y++)
		{
			for (double x = -SCREEN_WIDTH * 0.5f + 0.5f + startX; x < -SCREEN_WIDTH * 0.5f + 0.5f + endX; x++)
			{
				Vec3D v_direction = { x, y, zFar };

				Vec3D v_orientedDirection = QuaternionMultiplication(g_player.q_orientation, { 0, v_direction }, QuaternionConjugate(g_player.q_orientation)).vecPart;

				int screenX = x + SCREEN_WIDTH * 0.5f;
				int screenY = SCREEN_HEIGHT - (y + SCREEN_HEIGHT * 0.5f);

				Vec3D pixelColor = ZERO_VEC3D;

				for (int i = 0; i < SAMPLES_PER_PIXEL; i++)
				{
#if PATH_TRACING == 1
					// For anti-aliasing
					Vec3D v_jitteredDirection = AddVec3D(v_orientedDirection, RandomVec_InUnitSphere(&randomEngine));
					NormalizeVec3D(&v_jitteredDirection);

					AddToVec3D(&pixelColor, RenderPixel(g_player.coords, v_jitteredDirection, &randomEngine));
#else
					NormalizeVec3D(&v_orientedDirection);

					AddToVec3D(&pixelColor, RenderPixel(g_player.coords, v_orientedDirection, &randomEngine));
#endif
				}

				ScaleVec3D(&pixelColor, 1 / double(SAMPLES_PER_PIXEL));

				pixelColor.x = Min(pixelColor.x, 255.0f);
				pixelColor.y = Min(pixelColor.y, 255.0f);
				pixelColor.z = Min(pixelColor.z, 255.0f);

				ScaleVec3D(&pixelColor, 1.0f / 255);

				pixelColor = { LINEAR_TO_SRGB(pixelColor.x), LINEAR_TO_SRGB(pixelColor.y), LINEAR_TO_SRGB(pixelColor.z) };

				ScaleVec3D(&pixelColor, 255.0f);

				screenBuffer[screenY * SCREEN_WIDTH + screenX] = pixelColor;

				//Draw(screenX, screenY, { uint8_t(pixelColor.x), uint8_t(pixelColor.y), uint8_t(pixelColor.z) });
			}
#if PATH_TRACING == 1
			std::cout << ((y + SCREEN_HEIGHT * 0.5f) / SCREEN_HEIGHT) * 100 << "%" << '\n';
#endif
		}
	}

	Vec3D RenderPixel(Vec3D v_start, Vec3D v_direction, std::mt19937* randomEngine)
	{
		Vec3D v_intersection = ZERO_VEC3D;
		Vec3D v_textureColor = ZERO_VEC3D;
		Quaternion q_surfaceNormal = IDENTITY_QUATERNION;
		Material material;

		bool intersectionExists = NextIntersection(v_start, v_direction, &v_intersection, &v_textureColor, &q_surfaceNormal, &material);

		if (intersectionExists)
		{
#if PATH_TRACING == 1
			v_textureColor = CalculateLighting_PathTracing(
				v_textureColor, material, q_surfaceNormal, v_direction, v_intersection, { 1, 1, 1 }, randomEngine
			);
#else
			v_textureColor = CalculateLighting_DistributionTracing(
				v_textureColor, material, q_surfaceNormal.vecPart, v_direction, v_intersection, 0, randomEngine
			);
#endif
		}

		return v_textureColor;
	}

	void MedianFilter()
	{
		auto AddColorToVector = [](std::vector<Vec3D>* colors, int x, int y)
		{
			if (x >= 0 && x < SCREEN_WIDTH && y >= 0 && y < SCREEN_HEIGHT)
			{
				colors->push_back(screenBuffer[y * SCREEN_WIDTH + x]);
			}
		};

		auto ColorSize = [](Vec3D color)
		{
			return Max(color.x, Max(color.y, color.z));
		};

		auto MedianColor = [ColorSize](std::vector<Vec3D>* colors)
		{
			for (int i = 0; i < colors->size(); i++)
			{
				for (int j = 0; j < colors->size() - 1; j++)
				{
					if (ColorSize(colors->at(j)) > ColorSize(colors->at(j + 1)))
					{
						SwapVec3D(&(colors->at(j)), &(colors->at(j + 1)));
					}
				}
			}

			return colors->at(colors->size() / 2);
		};

		Vec3D* screenBufferCopy = new Vec3D[SCREEN_HEIGHT * SCREEN_WIDTH];

		for (int y = 0; y < SCREEN_HEIGHT; y++)
		{
			for (int x = 0; x < SCREEN_WIDTH; x++)
			{
				std::vector<Vec3D> colors;

				AddColorToVector(&colors, x, y);
				AddColorToVector(&colors, x + 1, y);
				AddColorToVector(&colors, x - 1, y);
				AddColorToVector(&colors, x, y + 1);
				AddColorToVector(&colors, x, y - 1);

				screenBufferCopy[y * SCREEN_WIDTH + x] = MedianColor(&colors);
			}
		}

		for (int y = 0; y < SCREEN_HEIGHT; y++)
		{
			for (int x = 0; x < SCREEN_WIDTH; x++)
			{
				screenBuffer[y * SCREEN_WIDTH + x] = screenBufferCopy[y * SCREEN_WIDTH + x];
			}
		}

		delete[] screenBufferCopy;
	}

	void GaussianBlur()
	{
		auto WeightedPixel = [](double weight, int x, int y)
		{
			Vec3D weightedPixel = ZERO_VEC3D;

			if (x >= 0 && x < SCREEN_WIDTH && y >= 0 && y < SCREEN_HEIGHT)
			{
				weightedPixel = VecScalarMultiplication3D(screenBuffer[y * SCREEN_WIDTH + x], weight);
			}

			return weightedPixel;
		};

#define KERNEL_SIZE 3

		double gaussianKernel[KERNEL_SIZE * KERNEL_SIZE] =
		{
			0.0000, 0.0625, 0.0000,
			0.0625, 0.7500, 0.0625,
			0.0000, 0.0625, 0.0000,
		};

		Vec3D* screenBufferCopy = new Vec3D[SCREEN_HEIGHT * SCREEN_WIDTH];

		for (int y = 0; y < SCREEN_HEIGHT; y++)
		{
			for (int x = 0; x < SCREEN_WIDTH; x++)
			{
				Vec3D blurredPixel = ZERO_VEC3D;

				for (int i = 0; i < 3; i++)
				{
					for (int j = 0; j < 3; j++)
					{
						AddToVec3D(&blurredPixel, WeightedPixel(gaussianKernel[i * KERNEL_SIZE + j], x + j - KERNEL_SIZE / 2, y + i - KERNEL_SIZE / 2));
					}
				}

				screenBufferCopy[y * SCREEN_WIDTH + x] = blurredPixel;
			}
		}

		for (int y = 0; y < SCREEN_HEIGHT; y++)
		{
			for (int x = 0; x < SCREEN_WIDTH; x++)
			{
				screenBuffer[y * SCREEN_WIDTH + x] = screenBufferCopy[y * SCREEN_WIDTH + x];
			}
		}

		delete[] screenBufferCopy;
	}

	double LINEAR_TO_SRGB(double l)
	{
		if (l <= 0.0031308)
		{
			return l * 12.92;
		}

		return 1.055 * pow(l, 0.41666) - 0.055;
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
			double signedTextureWidth = (g_ground.textureCorner2.x - g_ground.textureCorner1.x) * g_ground.textureScalar;
			double signedTextureHeight = (g_ground.textureCorner2.y - g_ground.textureCorner1.y) * g_ground.textureScalar;

			double t1 = fmod(rayGroundIntersection.x, signedTextureWidth) / signedTextureWidth;
			double t2 = fmod(rayGroundIntersection.z, signedTextureHeight) / signedTextureHeight;

			// if the t values are negative, we need to flip them around the center of the texture and make them positive
			if (t1 < 0) t1 += 1;
			if (t2 < 0) t2 += 1;

			double textureX = Lerp(g_ground.textureCorner1.x, g_ground.textureCorner2.x, t1);
			double textureY = Lerp(g_ground.textureCorner1.y, g_ground.textureCorner2.y, t2);

			if (g_ground.texture != nullptr)
			{
				olc::Pixel texelColor = g_ground.texture->Sample(textureX, textureY);

				*v_intersectionColor = { double(texelColor.r), double(texelColor.g), double(texelColor.b) };
			}
			if (g_ground.normalMap != nullptr)
			{
				olc::Pixel normalMapColor = g_ground.normalMap->Sample(textureX, textureY);

				// Converting the color in the normalMap to an actual unit vector
				q_surfaceNormal->vecPart = ReturnNormalizedVec3D({ double(normalMapColor.r) * 2 - 255.0f, double(normalMapColor.b) * 2 - 255.0f, double(normalMapColor.g) * 2 - 255.0f });
			}
		}

		return true;
	}

	// Ray tracing for spheres
	bool SphereIntersection_RT(Sphere sphere, Vec3D v_start, Vec3D v_direction,
		Vec3D* v_intersection = nullptr, Vec3D* v_intersectionColor = nullptr, Quaternion* q_surfaceNormal = nullptr)
	{
		double dxdz = v_direction.x / v_direction.z;
		double dydz = v_direction.y / v_direction.z;

		double a = dxdz * dxdz + dydz * dydz + 1;
		
		double b = 
			2 * dxdz * (v_start.x - sphere.coords.x) +
			2 * dydz * (v_start.y - sphere.coords.y) +
			2 * (v_start.z - sphere.coords.z);

		double c = 
			(v_start.x - sphere.coords.x) * (v_start.x - sphere.coords.x) +
			(v_start.y - sphere.coords.y) * (v_start.y - sphere.coords.y) +
			(v_start.z - sphere.coords.z) * (v_start.z - sphere.coords.z) - sphere.radius * sphere.radius;

		// ISAK: There wasn't any need to recalculate this multiple times
		double rootContent = b * b - 4 * a * c;

		// There exists no intersections (no real answer)
		if (rootContent < 0) return false;

		double z1 = (-b + sqrt(rootContent)) / (2 * a);
		double z2 = (-b - sqrt(rootContent)) / (2 * a);

		Vec3D v_alternative1 = { z1 * dxdz, z1 * dydz, z1 };
		AddToVec3D(&v_alternative1, v_start);

		Vec3D v_alternative2 = { z2 * dxdz, z2 * dydz, z2 };
		AddToVec3D(&v_alternative2, v_start);

		// Check which intersection is the closest and choose that one
		double dist1 = DistanceSquared3D(v_alternative1, v_start);
		double dist2 = DistanceSquared3D(v_alternative2, v_start);

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

		if (q_surfaceNormal != nullptr)
		{
			q_surfaceNormal->vecPart = v_normal;
			q_surfaceNormal->realPart = 1;

			if (DistanceSquared3D(v_start, sphere.coords) < sphere.radius * sphere.radius)
			{
				q_surfaceNormal->realPart = -1;
			}
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
			double u = 0.5 + atan2(v_normal.x, v_normal.z) / TAU;
			double v = 0.5 - asin(v_normal.y) / PI;

			double textureX = Lerp(sphere.textureCorner1.x, sphere.textureCorner2.x, u);
			double textureY = Lerp(sphere.textureCorner1.y, sphere.textureCorner2.y, v);

			if (sphere.texture != nullptr)
			{
				// Interpolating between assigned texture coordinates
				olc::Pixel texelColor = sphere.texture->Sample(textureX, textureY);

				*v_intersectionColor = { (double)texelColor.r, (double)texelColor.g, (double)texelColor.b };
			}
			if (sphere.normalMap != nullptr)
			{
				olc::Pixel normalMapColor = sphere.normalMap->Sample(textureX, textureY);

				// Converting the color in the normalMap to an actual unit vector
				Vec3D v_normalMapNormal = ReturnNormalizedVec3D({ double(normalMapColor.r) * 2 - 255.0f, double(normalMapColor.b) * 2 - 255.0f, double(normalMapColor.g) * 2 - 255.0f });

				// Calculating tangents of the sphere
				Vec3D v_sidewaysTangent = ReturnNormalizedVec3D({ -v_normal.z, 0, v_normal.x });
				Vec3D v_forwardTangent = ReturnNormalizedVec3D({ 0, -v_normal.z, v_normal.y });

				// Takes the normal in the normalMap and transforms it into the actual normal of the object
				Matrix3D normalMatrix =
				{
					v_sidewaysTangent,
					v_normal,
					v_forwardTangent
				};

				q_surfaceNormal->vecPart = VecMatrixMultiplication3D(v_normalMapNormal, normalMatrix);
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
		double f_trianglePlaneOffset = DotProduct3D(v_triangleNormal, triangle.vertices[0]);

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

				*v_intersectionColor = { double(texelColor.r), double(texelColor.g), double(texelColor.b) };
			}
			if (triangle.normalMap != nullptr)
			{
				olc::Pixel normalMapColor = triangle.normalMap->Sample(textureCoordinates.x, textureCoordinates.y);

				// Converting the color in the normalMap to an actual unit vector
				Vec3D v_normalMapNormal = ReturnNormalizedVec3D({ double(normalMapColor.r) * 2 - 255.0f, double(normalMapColor.b) * 2 - 255.0f, double(normalMapColor.g) * 2 - 255.0f });

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

				q_surfaceNormal->vecPart = VecMatrixMultiplication3D(v_normalMapNormal, normalMatrix);
			}
		}
		
		return true;
	}

	Vec3D LinePlaneIntersection(Vec3D v_start, Vec3D v_direction, Vec3D v_planeNormal, double f_planeOffset)
	{
		double f_deltaOffset = DotProduct3D(v_start, v_planeNormal);

		f_planeOffset -= f_deltaOffset;

		double f_scalingFactor = f_planeOffset / DotProduct3D(v_direction, v_planeNormal);

		return AddVec3D(VecScalarMultiplication3D(v_direction, f_scalingFactor), v_start);
	}

	enum ScatteringType
	{
		LAMBERTIAN,
		SPECULAR,
		TRANSMISSIVE
	};

	Vec3D CalculateLighting_PathTracing(Vec3D v_textureColor, Material material, Quaternion q_surfaceNormal, Vec3D v_incomingDirection, Vec3D v_intersection, Vec3D accumulatedAttenuation, std::mt19937* randomEngine)
	{
		Vec3D v_outgoingLightColor = ConusProduct(v_textureColor, material.emittance);

		// counterintuitive, but the probability goes up when accumulatedAttenuation goes up
		double survivalProbability = Max(Sigmoid(2 * Max(accumulatedAttenuation.x, Max(accumulatedAttenuation.y, accumulatedAttenuation.z))), 0.1);

		// Randomly terminate paths with russian roulette
		if (uniform_zero_to_one(*randomEngine) > survivalProbability)
		{
			return v_outgoingLightColor;
		}

		double refractionIndex1 = REFRACTION_INDEX_AIR;
		double refractionIndex2 = material.refractionIndex;
		Vec3D attenuation = { 0, 0, 0 };

		if (q_surfaceNormal.realPart == -1)
		{
			refractionIndex1 = material.refractionIndex;
			refractionIndex2 = REFRACTION_INDEX_AIR;
			v_outgoingLightColor = ZERO_VEC3D;
		}

		ScaleVec3D(&v_incomingDirection, -1);

		// Scale the normal to be oriented in the hemisphere the material was hit from
		ScaleVec3D(&(q_surfaceNormal.vecPart), q_surfaceNormal.realPart);

		Vec3D v_outgoingDirection;
		ScatteringType scatteringType;

		Vec3D v_microscopicNormal = MicroscopicNormal(v_incomingDirection, q_surfaceNormal.vecPart, material.roughness, randomEngine); // for specular and transmissive scattering

		double scatteringTypeProbability; // will be assigned a value later on, used for energy conservation

		bool isMaterialDielectric = (material.type == DIELECTRIC);
		bool isMaterialMetallic = (material.type == METAL);

		double reflectionProbability = 1.0; // 1.0 for metals

		if (!isMaterialMetallic)
		{
			double normalisedAttenuation = -exp(-Min(material.attenuation.x, Min(material.attenuation.y, material.attenuation.z))) + 1.0; // between 0 and 1
			double fresnelDielectric = FresnelDielectric(v_incomingDirection, v_microscopicNormal, refractionIndex1, refractionIndex2) * 0.5;

			reflectionProbability = Max(fresnelDielectric, normalisedAttenuation);
		}

		if (uniform_zero_to_one(*randomEngine) <= reflectionProbability)
		{
			double specularProbability = 1.0; // 1.0 for non-dielectrics
			
			if (isMaterialDielectric)
			{
				specularProbability = material.specularValue / (material.specularValue + Max(material.diffuseTint.x, Max(material.diffuseTint.y, material.diffuseTint.z)));
			}

			if(uniform_zero_to_one(*randomEngine) <= specularProbability)
			{
				scatteringType = SPECULAR;

				v_outgoingDirection = SubtractVec3D(VecScalarMultiplication3D(v_microscopicNormal, 2 * DotProduct3D(v_incomingDirection, v_microscopicNormal)), v_incomingDirection);

				scatteringTypeProbability = specularProbability * reflectionProbability;
			}
			else
			{
				scatteringType = LAMBERTIAN;

				Vec3D v_tangent = ReturnNormalizedVec3D(SubtractVec3D(v_incomingDirection, VecScalarMultiplication3D(q_surfaceNormal.vecPart, DotProduct3D(v_incomingDirection, q_surfaceNormal.vecPart))));

				Matrix3D transformationMatrix =
				{
					v_tangent,
					q_surfaceNormal.vecPart,
					CrossProduct(q_surfaceNormal.vecPart, v_tangent)
				};

				double randVariable = uniform_zero_to_one(*randomEngine);
				double theta = uniform_zero_to_one(*randomEngine) * TAU;

				double r = sqrt(randVariable);

				v_outgoingDirection = VecMatrixMultiplication3D({ r * cos(theta), sqrt(1 - randVariable), r * sin(theta) }, transformationMatrix);

				scatteringTypeProbability = (1 - specularProbability) * reflectionProbability;
			}
		}
		else
		{
			scatteringType = TRANSMISSIVE;

			double n = refractionIndex1 / refractionIndex2;

			double incomingDotBisector = DotProduct3D(v_incomingDirection, v_microscopicNormal);

			double bisectorScalar = n * incomingDotBisector - Sign(DotProduct3D(v_incomingDirection, q_surfaceNormal.vecPart)) * sqrt(Max(1 + n * (incomingDotBisector * incomingDotBisector - 1), 0));

			v_outgoingDirection = SubtractVec3D(VecScalarMultiplication3D(v_microscopicNormal, bisectorScalar), VecScalarMultiplication3D(v_incomingDirection, n));

			scatteringTypeProbability = 1.0 - reflectionProbability;
		}

		NormalizeVec3D(&v_outgoingDirection);

		AddToVec3D(&v_intersection, VecScalarMultiplication3D(v_outgoingDirection, OFFSET_DISTANCE));

		if (DotProduct3D(v_outgoingDirection, q_surfaceNormal.vecPart) * q_surfaceNormal.realPart < 0)
		{
			// The ray is going through the object
			attenuation = material.attenuation;
		}

		Vec3D v_nextIntersection = ZERO_VEC3D;
		Vec3D v_nextTextureColor = ZERO_VEC3D;
		Quaternion q_nextNormal = IDENTITY_QUATERNION;
		Material nextMaterial;

		Vec3D v_diffuseTint = VecScalarMultiplication3D(ConusProduct(v_textureColor, material.diffuseTint), 1.0 / 255);

		Vec3D weight = ZERO_VEC3D;

		if (scatteringType == LAMBERTIAN)
		{
			weight = VecScalarMultiplication3D(BRDF_LAMBERTIAN(v_incomingDirection, v_outgoingDirection, q_surfaceNormal.vecPart, refractionIndex1, refractionIndex2, v_diffuseTint), PI / scatteringTypeProbability);
		}
		else if (scatteringType == SPECULAR)
		{
			weight = VecScalarMultiplication3D(
				BRDF_COOKTORRANCE(v_incomingDirection, v_outgoingDirection, q_surfaceNormal.vecPart, v_microscopicNormal, refractionIndex1, refractionIndex2, material.roughness, material.extinctionCoefficient, material.specularValue, isMaterialMetallic), 1.0 / scatteringTypeProbability
			);

			if (!isMaterialDielectric)
			{
				weight = ConusProduct(weight, v_diffuseTint);
			}
		}
		else
		{
			weight = VecScalarMultiplication3D(BTDF(v_incomingDirection, v_outgoingDirection, q_surfaceNormal.vecPart, v_microscopicNormal, refractionIndex1, refractionIndex2, material.roughness), 1.0 / scatteringTypeProbability);
		}

		Vec3D v_incomingLightColor = AMBIENT_LIGHT;

		bool intersectionExists = NextIntersection(v_intersection, v_outgoingDirection, &v_nextIntersection, &v_nextTextureColor, &q_nextNormal, &nextMaterial);

		double distance = Distance3D(v_intersection, v_nextIntersection);

		attenuation = { exp(-attenuation.x * distance), exp(-attenuation.y * distance), exp(-attenuation.z * distance) };

		weight = ConusProduct(weight, attenuation);

		if (intersectionExists)
		{
			v_incomingLightColor = CalculateLighting_PathTracing(
				v_nextTextureColor, nextMaterial, q_nextNormal, v_outgoingDirection, v_nextIntersection, accumulatedAttenuation, randomEngine
			);
		}

		v_incomingLightColor = { Min(v_incomingLightColor.x, MAX_COLOR_VALUE), Min(v_incomingLightColor.y, MAX_COLOR_VALUE), Min(v_incomingLightColor.z, MAX_COLOR_VALUE) }; // Introduces bias. To avoid bias MAX_COLOR_VALUE should be very high

		// Add the energy that is lost by randomly terminating paths
		ScaleVec3D(&v_incomingLightColor, 1.0 / survivalProbability);

		AddToVec3D(&v_outgoingLightColor, ConusProduct(v_incomingLightColor, weight));

		return v_outgoingLightColor;
	}

	bool NextIntersection(Vec3D v_start, Vec3D v_direction, Vec3D* v_intersection, Vec3D* v_color, Quaternion* q_normal, Material* material)
	{
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

		// Check ground
		bool groundIntersect = GroundIntersection_RT(v_start, v_direction, v_intersection, v_color, q_normal);

		if (groundIntersect)
		{
			*material = g_ground.material;
			return true;
		}
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

	// Cook-Torrance (cock tolerance) BRDF with GGX distribution function and GGX geometry function
	Vec3D BRDF_COOKTORRANCE(Vec3D v_incomingDirection, Vec3D v_outgoingDirection, Vec3D v_normal, Vec3D v_microscopicNormal, double refractionIndex1, double refractionIndex2, double roughness, double extinctionCoefficient, double specularValue, bool isMaterialMetallic)
	{

		double fresnelFactor;
		
		if (isMaterialMetallic)
		{
			fresnelFactor = FresnelConductor(v_incomingDirection, v_microscopicNormal, refractionIndex1, refractionIndex2, extinctionCoefficient);
		}
		else
		{
			fresnelFactor = FresnelDielectric(v_incomingDirection, v_microscopicNormal, refractionIndex1, refractionIndex2);
		}

		// Some terms are not included because they are cancelled out bt the PDF
		double specularTerm = Abs(DotProduct3D(v_incomingDirection, v_microscopicNormal)) * fresnelFactor * GeometryBidirectional(v_incomingDirection, v_outgoingDirection, v_normal, v_microscopicNormal, roughness) /
			(Abs(DotProduct3D(v_incomingDirection, v_normal)) * Abs(DotProduct3D(v_microscopicNormal, v_normal)));

		return VecScalarMultiplication3D({ specularValue, specularValue, specularValue }, specularTerm);
	}

	Vec3D BRDF_LAMBERTIAN(Vec3D v_incomingDirection, Vec3D v_outgoingDirection, Vec3D v_normal, double refractionIndex1, double refractionIndex2, Vec3D v_diffuseTint)
	{
		Vec3D v_bisectorVector = ReturnNormalizedVec3D(Lerp3D(v_incomingDirection, v_outgoingDirection, 0.5));

		double fresnelFactor = FresnelDielectric(v_incomingDirection, v_bisectorVector, refractionIndex1, refractionIndex2);

		double diffuseTerm = Chi(DotProduct3D(v_bisectorVector, v_normal)) * Square(1 - fresnelFactor) / PI;

		return VecScalarMultiplication3D(v_diffuseTint, diffuseTerm);
	}

	double Chi(double x)
	{
		return x > 0 ? 1 : 0;
	}

	double FresnelDielectric(Vec3D v_incomingDirection, Vec3D v_microscopicNormal, double refractionIndex1, double refractionIndex2)
	{
		double c = Abs(DotProduct3D(v_incomingDirection, v_microscopicNormal));

		double g = sqrt(Max((refractionIndex2 * refractionIndex2) / (refractionIndex1 * refractionIndex1) - 1 + c * c, 0));

		return 0.5 * Square((g - c) / (g + c)) * (1 + Square(c * (g + c) - 1) / Square(c * (g - c) + 1));
	}

	double FresnelConductor(Vec3D v_incomingDirection, Vec3D v_normal, double refractionIndex1, double refractionIndex2, double extinctionCoefficient)
	{
		// reference for this can be found here: https://seblagarde.wordpress.com/2013/04/29/memo-on-fresnel-equations/

		double eta2 = Square(refractionIndex2 / refractionIndex1);
		double etak2 = Square(extinctionCoefficient / refractionIndex1);

		double cosTheta = DotProduct3D(v_incomingDirection, v_normal);
		double cosTheta2 = cosTheta * cosTheta;

		double sinTheta2 = 1 - cosTheta2;
		double sinTheta4 = sinTheta2 * sinTheta2;

		double sumA2B2 = sqrt(Square(eta2 - etak2 - sinTheta2) + 4 * eta2 * etak2);

		double a = sqrt(0.5 * (sumA2B2 + eta2 - etak2 - sinTheta2));

		double sPolarizedReflection = (sumA2B2 - 2 * a * cosTheta + cosTheta2) / (sumA2B2 + 2 * a * cosTheta + cosTheta2);
		double pPolarizedReflection = sPolarizedReflection * (cosTheta2 * sumA2B2 - 2 * a * cosTheta * sinTheta2 + sinTheta4) / (cosTheta2 * sumA2B2 + 2 * a * cosTheta * sinTheta2 + sinTheta4);

		return 0.5 * (sPolarizedReflection + pPolarizedReflection);
	}

	double GeometryBidirectional(Vec3D v_incomingDirection, Vec3D v_outgoingDirection, Vec3D v_normal, Vec3D v_microscopicNormal, double roughness)
	{
		return GeometryMonodirectional(v_incomingDirection, v_normal, v_microscopicNormal, roughness) * GeometryMonodirectional(v_outgoingDirection, v_normal, v_microscopicNormal, roughness);
	}

	double GeometryMonodirectional(Vec3D vec, Vec3D v_normal, Vec3D v_microscopicNormal, double roughness)
	{
		double VecDotNormal = DotProduct3D(vec, v_normal);
		double VecDotNormal2 = VecDotNormal * VecDotNormal;
		double a2 = VecDotNormal2 / (roughness * roughness * (1 - VecDotNormal2)); // a squared

		return Chi(DotProduct3D(vec, v_microscopicNormal) / DotProduct3D(vec, v_normal)) * 2 / (1 + sqrt(1 + 1 / a2));
	}

	Vec3D BTDF(Vec3D v_incomingDirection, Vec3D v_outgoingDirection, Vec3D v_normal, Vec3D v_microscopicNormal, double refractionIndex1, double refractionIndex2, double roughness)
	{
		double btdf = Abs(DotProduct3D(v_incomingDirection, v_microscopicNormal)) * GeometryBidirectional(v_incomingDirection, v_outgoingDirection, v_normal, v_microscopicNormal, roughness) /
			(Abs(DotProduct3D(v_incomingDirection, v_normal)) * Abs(DotProduct3D(v_microscopicNormal, v_normal)));

		return { btdf, btdf, btdf };
	}

	// computing the bisector vector (microscopic normal) used for importance sampling
	Vec3D MicroscopicNormal(Vec3D v_incomingDirection, Vec3D v_normal, double roughness, std::mt19937* randomEngine)
	{
		double randVariable = uniform_zero_to_one(*randomEngine);

		double cosTheta = sqrt((1 - randVariable) / (randVariable * (roughness * roughness - 1) + 1));
		double sinTheta = sqrt(1 - cosTheta * cosTheta);

		double randAngle = uniform_zero_to_one(*randomEngine) * TAU;

		Vec3D v_bisectorVector = { sinTheta * cos(randAngle), cosTheta, sinTheta * sin(randAngle) };

		Vec3D v_tangent = ReturnNormalizedVec3D(SubtractVec3D(v_incomingDirection, VecScalarMultiplication3D(v_normal, DotProduct3D(v_incomingDirection, v_normal))));

		Matrix3D transformationMatrix =
		{
			v_tangent,
			v_normal,
			CrossProduct(v_normal, v_tangent)
		};

		return VecMatrixMultiplication3D(v_bisectorVector, transformationMatrix);
	}

	Vec3D CalculateLighting_DistributionTracing(Vec3D v_objectColor, Material material, Vec3D v_surfaceNormal, Vec3D v_incomingDirection, Vec3D v_intersection, int i_bounceCount, std::mt19937* randomEngine)
	{
		Vec3D v_pixelColor = ZERO_VEC3D;

		if (i_bounceCount > MAX_BOUNCES)
			return v_pixelColor;

		// Temporary until refraction (it'll need to decide whether to offset in or out)
		AddToVec3D(&v_intersection, VecScalarMultiplication3D(v_surfaceNormal, MOVE_DISTANCE));

		Vec3D v_emittedColor = ConusProduct(v_objectColor, material.emittance);

		// Reflections
		Vec3D v_reflectionIntersection, v_reflectionColor, v_nextObjectColor;
		Quaternion q_reflectionIntersectionNormal;
		Material newMaterial;

#if REFLECTIONS == 1
		Vec3D v_specularDirection = SubtractVec3D(v_incomingDirection, VecScalarMultiplication3D(v_surfaceNormal, 2 * DotProduct3D(v_incomingDirection, v_surfaceNormal)));

		if (material.roughness == 0)
		{
			// Specular reflections
			bool b_foundIntersection = NextIntersection(v_intersection, v_specularDirection, &v_reflectionIntersection, &v_nextObjectColor, &q_reflectionIntersectionNormal, &newMaterial);

			if (b_foundIntersection)
			{
				v_reflectionColor = CalculateLighting_DistributionTracing(
					v_nextObjectColor, newMaterial, q_reflectionIntersectionNormal.vecPart, v_specularDirection, v_intersection, i_bounceCount + 1, randomEngine
				);
			}
		}
		else
		{
			// Diffuse reflections
			int hitCount = 1;

			for (int i = 0; i < SAMPLES_PER_RAY; i++)
			{
				Vec3D v_lambertianDirection = ReturnNormalizedVec3D(RandomVec_InUnitSphere(randomEngine));
				if (DotProduct3D(v_lambertianDirection, v_surfaceNormal) < 0)
					v_lambertianDirection = VecScalarMultiplication3D(v_lambertianDirection, -1);

				Vec3D v_diffuseDirection = Lerp3D(v_specularDirection, v_lambertianDirection, material.roughness);

				bool b_foundIntersection = NextIntersection(v_intersection, v_diffuseDirection, &v_reflectionIntersection, &v_nextObjectColor, &q_reflectionIntersectionNormal, &newMaterial);

				if (b_foundIntersection)
				{
					AddToVec3D(&v_reflectionColor, CalculateLighting_DistributionTracing(
						v_nextObjectColor, newMaterial, q_reflectionIntersectionNormal.vecPart, v_diffuseDirection, v_intersection, i_bounceCount + 1, randomEngine
					));
					hitCount++;
				}
			}

			v_reflectionColor = VecScalarMultiplication3D(v_reflectionColor, 1 / hitCount);
		}
#endif

		Vec3D v_lightingColor = ZERO_VEC3D;

		// Soft shadows
		for (int i = 0; i < g_lights.size(); i++)
		{
			double notBlockedProportion = 0;

			for (int j = 0; j < SAMPLES_PER_RAY; j++)
			{
				Vec3D v_displacement = ReturnNormalizedVec3D(RandomVec_InUnitSphere(randomEngine));
				v_displacement = VecScalarMultiplication3D(v_displacement, g_lights[i].radius);
				Vec3D randomPointLight = AddVec3D(g_lights[i].coords, v_displacement);

				Vec3D v_newDirection = ReturnNormalizedVec3D(SubtractVec3D(randomPointLight, v_intersection));

				notBlockedProportion += !IsRayBlocked(v_intersection, v_newDirection, g_lights[i].coords);
			}

			notBlockedProportion /= SAMPLES_PER_RAY;

			Vec3D v_lightColor;

			if (notBlockedProportion != 0)
			{
				float distance = Distance3D(v_intersection, g_lights[i].coords) - g_lights[i].radius;

				v_lightColor = VecScalarMultiplication3D(g_lights[i].emittance, notBlockedProportion / (distance * distance));
			}
			else
				v_lightColor = { 0.10, 0.13, 0.20 };
				//v_lightColor = { 0, 0, 0 };
			
			AddToVec3D(&v_lightingColor, v_lightColor);
		}


		// Refraction
		// Tangent inside of the plane defined by v_surfaceNormal and v_incomingDirection
		//Vec3D v_surfaceTangent = CrossProduct(ReturnNormalizedVec3D(CrossProduct(v_surfaceNormal, v_incomingDirection)), v_surfaceNormal);

		//float sinIncomingAngle = DotProduct3D(v_incomingDirection, v_surfaceTangent);

		//float sinRefractedAngle = Min(REFRACTION_INDEX_AIR * sinIncomingAngle / material.refractionIndex, 1.0f);

		//float cosRefractedAngle = sqrt(1 - sinRefractedAngle * sinRefractedAngle); // Pythagorean identity

		float cosIncomingAngle = Clamp(-DotProduct3D(v_incomingDirection, v_surfaceNormal), 0, 1);

		//bool b_foundIntersection = FindIntersection(v_intersection, v_reflectedDirecion, &v_reflectionIntersection, &v_reflectionColor, &q_reflectionIntersectionNormal, &newMaterial);

		//if (b_foundIntersection)
		//	v_reflectionColor = CalculateLighting_DistributionTracing(
		//		v_reflectionColor, newMaterial, q_reflectionIntersectionNormal.vecPart, v_reflectedDirecion, v_intersection, ++i_bounceCount
		//	);

		// Schlick's approximation
		float r0 = Square((REFRACTION_INDEX_AIR - material.refractionIndex) / (REFRACTION_INDEX_AIR + material.refractionIndex));
		float fresnel = r0 + (1 - r0) * (1 - cosIncomingAngle) * (1 - cosIncomingAngle) * (1 - cosIncomingAngle) * (1 - cosIncomingAngle) * (1 - cosIncomingAngle);

		v_pixelColor = ConusProduct(material.diffuseTint, AddVec3D(VecScalarMultiplication3D(v_reflectionColor, fresnel), VecScalarMultiplication3D(v_objectColor, 1 - fresnel)));

		v_pixelColor = ConusProduct(v_pixelColor, v_lightingColor);

		AddToVec3D(&v_pixelColor, ConusProduct(v_objectColor, material.emittance));
		
		return v_pixelColor;
	}

	Vec3D RandomVec_InUnitSphere(std::mt19937* randomEngine)
	{
		Vec3D randPoint;

		do
		{
			double randX = uniformDistribution(*randomEngine);
			double randY = uniformDistribution(*randomEngine);
			double randZ = uniformDistribution(*randomEngine);

			randPoint = { randX, randY, randZ };
		} while (VecLengthSquared(randPoint) > 1);

		return randPoint;
	}
};

__global__ void cum()
{

}

int main()
{
	cum<<<1, 1>>>();

	Engine rayTracer;

	if (rayTracer.Construct(SCREEN_WIDTH, SCREEN_HEIGHT, 1, 1))
		rayTracer.Start();
	return 0;
}

#include "Controlls.h"