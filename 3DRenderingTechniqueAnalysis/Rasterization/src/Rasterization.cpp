#define OLC_PGE_APPLICATION
#include <iostream>
#include "olcPixelGameEngine.h"
#include "MathUtilities.cuh"

class Engine : public olc::PixelGameEngine
{
public:
	Engine()
	{
		sAppName = "Rasterization_Engine";
	}

public:
	bool OnUserCreate() override
	{
		return true;
	}

	bool OnUserUpdate(float fElapsedTime) override
	{
		for (int x = 0; x < ScreenWidth(); x++)
			for (int y = 0; y < ScreenHeight(); y++)
				Draw(x, y, olc::Pixel(rand() % 256, rand() % 256, rand() % 256));
		return true;
	}
};

int main()
{
	Engine rasterizer;
	if (rasterizer.Construct(256, 240, 4, 4))
		rasterizer.Start();
	return 0;
}