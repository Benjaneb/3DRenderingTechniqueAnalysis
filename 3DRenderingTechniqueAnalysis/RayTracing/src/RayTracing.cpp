#define OLC_PGE_APPLICATION
#include <iostream>
#include "olcPixelGameEngine.h"

// Override base class with your custom functionality
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
		for (int x = 0; x < ScreenWidth(); x++)
			for (int y = 0; y < ScreenHeight(); y++)
				Draw(x, y, olc::Pixel(rand() % 256, rand() % 256, rand() % 256));
		return true;
	}
};

int main()
{
	Engine rayTracer;
	if (rayTracer.Construct(256, 240, 4, 4))
		rayTracer.Start();
	return 0;
}