#define OLC_PGE_APPLICATION
#include <iostream>
#include "olcPixelGameEngine.h"
#include "MathUtilities.h"
#include "WorldDatatypes.h"

int g_screenWidth = 500;
int g_screenHeight = 300;

class Engine : public olc::PixelGameEngine
{
public:
	Engine()
	{
		sAppName = "Ray_Tracing_Engine";
	}

public:
	bool OnUserCreate() override
	{
		return true;
	}

	bool OnUserUpdate(float fElapsedTime) override
	{
		RayTracing();
		return true;
	}

	void RayTracing()
	{
		for (int y = 0; y < g_screenHeight; y++)
		{
			for (int x = 0; x < g_screenWidth; x++)
			{

			}
		}
	}

};

int main()
{
	Engine rayTracer;
	if (rayTracer.Construct(g_screenWidth, g_screenHeight, 1, 1))
		rayTracer.Start();
	return 0;
}