#define OLC_PGE_APPLICATION

#include <iostream>
#include "olcPixelGameEngine.h"
#include "MathUtilities.h"
#include "WorldDatatypes.h"


// Global variables
int g_int_screenWidth = 500;
int g_int_screenHeight = 300;

Player g_player = { { 0, 0, 0, }, {0, 0, 1, 0 }, PI / 2.0f };

std::vector<Sphere> g_spheres;
std::vector<Triangle> g_triangles;


class Engine : public olc::PixelGameEngine
{
public:
	Engine()
	{
		sAppName = "Ray_Tracing_Engine";
	}

public:

	// Initiations of Engine class global variables
	bool OnUserCreate() override
	{
		Sphere sphere1 = { { 1, 0, 5 }, 3, olc::BLUE };
		g_spheres = { sphere1 };

		g_triangles = { { 10, { { -1, 0, 2 }, { 0, 1, 2 }, { 1, 0.5, 3 } } } };

		return true;
	}

	// Main loop
	bool OnUserUpdate(float fElapsedTime) override
	{
		Clear(olc::BLACK);

		RayTracing();

		return true;
	}

	void RayTracing()
	{
		float zFar = (g_int_screenWidth * 0.5f) / tan(g_player.FOV * 0.5f);

		for (int y = -g_int_screenHeight / 2; y < g_int_screenHeight / 2; y++)
		{
			for (int x = -g_int_screenWidth / 2; x < g_int_screenWidth / 2; x++)
			{
				Vec3D v_direction = { x, y, zFar };



				// render the triangles
				for (int i = 0; i < g_triangles.size(); i++)
				{
					RenderTriangles(g_triangles[i], g_player.coordinates, v_direction, x + g_int_screenWidth / 2, (g_int_screenHeight - 1) - (y + g_int_screenHeight / 2));
				}
			}
		}
	}

	void RenderSpheres(Sphere sphere, Vec3D v_start, Vec3D v_direction)
	{
		Vec3D v_intersection = { 0, 0, 0 };

		bool intersectionExists = SphereIntersection(sphere, v_start, v_direction, true, &v_intersection);
	}

	bool SphereIntersection(Sphere sphere, Vec3D v_start, Vec3D v_direction, bool b_calcIntersection, Vec3D* v_intersection = nullptr)
	{
		float k1 = (v_direction.x != 0) ? (v_direction.y / v_direction.x) : FLT_MAX;
		float k2 = (v_direction.x != 0) ? (v_direction.z / v_direction.x) : FLT_MAX;

		float a = 1 + k1 * k1 + k2 * k2;
		float b = 2 * (v_start.x - sphere.coords.x) + 2 * k1 * (v_start.y - sphere.coords.y) + 2 * k2 * (v_start.z - sphere.coords.z);
		float c = (v_start.x - sphere.coords.x) * (v_start.x - sphere.coords.x) + (v_start.y - sphere.coords.y) * (v_start.y - sphere.coords.y) + 
			(v_start.z - sphere.coords.z) * (v_start.z - sphere.coords.z) - sphere.radius * sphere.radius;

		// There exists no intersections (no real answer)
		if (b * b - 4 * a * c < 0) return false;

		// If there exists an intersection but we don't care *where* the intersection is
		if (!b_calcIntersection) return true;
		
		// If we do care where the intersection is:
		Vec3D v_alternative1;
		v_alternative1.x = (-b + sqrt(b * b - 4 * a * c)) / (2 * a);
		v_alternative1.y = k1 * v_alternative1.x + v_start.y;
		v_alternative1.z = k2 * v_alternative1.x + v_start.z;
		v_alternative1.x += v_start.x;

		Vec3D v_alternative2;
		v_alternative2.x = (-b - sqrt(b * b - 4 * a * c)) / (2 * a);
		v_alternative2.y = k1 * v_alternative2.x + v_start.y;
		v_alternative2.z = k2 * v_alternative2.x + v_start.z;
		v_alternative2.x += v_start.x;

		// Check which intersection is the closest and choose that one
		float dist1 = DistanceSquared3D(v_alternative1, v_start);
		float dist2 = DistanceSquared3D(v_alternative2, v_start);
		Vec3D v_correctHit = (dist1 < dist2) ? v_alternative1 : v_alternative2;

		// Check if the intersection is behind the player, if so discard it
		float dotProduct = DotProduct3D(v_correctHit, v_start);
		if (dotProduct < 0) return false;

		*v_intersection = v_correctHit;
		return true;
	}

	void RenderTriangles(Triangle triangle, Vec3D v_start, Vec3D v_direction, int screenX, int screenY)
	{
		NormalizeVec3D(&v_direction);

		Vec3D v_intersection = { 0, 0, 0 };

		bool intersectionExists = TriangleIntersection(triangle, v_start, v_direction, true, &v_intersection);

		if (intersectionExists)
		{
			Draw(screenX, screenY, olc::WHITE);
		}
	}

	bool TriangleIntersection(Triangle triangle, Vec3D v_start, Vec3D v_direction, 
		bool b_calcIntersection, Vec3D* v_intersection = nullptr)
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

		Vec3D v_trianglePlaneIntersection = LinePlaneIntersection(v_start, v_direction, v_triangleNormal, f_trianglePlaneOffset);

		// these normals aren't actually normalized, but that doesn't matter for this use-case
		Vec3D v_triangleEdge1_normal = CrossProduct(v_triangleNormal, SubtractVec3D(triangle.vertices[1], triangle.vertices[0]));
		Vec3D v_triangleEdge2_normal = CrossProduct(v_triangleNormal, SubtractVec3D(triangle.vertices[2], triangle.vertices[1]));
		Vec3D v_triangleEdge3_normal = CrossProduct(v_triangleNormal, SubtractVec3D(triangle.vertices[0], triangle.vertices[2]));

		// check if the intersection is outside of the triangle
		if (DotProduct3D(v_triangleEdge1_normal, SubtractVec3D(v_trianglePlaneIntersection, triangle.vertices[1])) <= 0) return false;
		if (DotProduct3D(v_triangleEdge2_normal, SubtractVec3D(v_trianglePlaneIntersection, triangle.vertices[2])) <= 0) return false;
		if (DotProduct3D(v_triangleEdge3_normal, SubtractVec3D(v_trianglePlaneIntersection, triangle.vertices[0])) <= 0) return false;

		//if we don't care where the intersection is we just return true before setting v_intersection
		if (b_calcIntersection == false) return true;

		*v_intersection = v_trianglePlaneIntersection;

		return true;
	}

	Vec3D LinePlaneIntersection(Vec3D v_start, Vec3D v_direction, Vec3D v_planeNormal, float f_planeOffset)
	{
		float f_deltaOffset = DotProduct3D(v_start, v_planeNormal);

		f_planeOffset -= f_deltaOffset;

		float f_scalingFactor = f_planeOffset / DotProduct3D(v_direction, v_planeNormal);

		return AddVec3D(VecScalarMultiplication3D(v_direction, f_scalingFactor), v_start);
	}

};

int main()
{
	Engine rayTracer;
	if (rayTracer.Construct(g_int_screenWidth, g_int_screenHeight, 1, 1))
		rayTracer.Start();
	return 0;
}