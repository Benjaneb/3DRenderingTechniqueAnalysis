#define OLC_PGE_APPLICATION
#define SCREEN_WIDTH 1280
#define SCREEN_HEIGHT 720

#include <iostream>
#include "olcPixelGameEngine.h"
#include "MathUtilities.h"
#include "WorldDatatypes.h"


// Global variables
Player g_player = { { 0, 0, 0, }, {0, 0, 1, 0 }, PI / 2.0f };

std::vector<Sphere> g_spheres;
std::vector<Triangle> g_triangles;
std::vector<Light> g_lights;


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
		Sphere sphere1 = { { 1, 0, 8 }, 3, olc::BLUE };
		g_spheres = { sphere1 };

		Triangle triangle1 = { { { -2, 0, 2 }, { 0, 1, 2 }, { 1, 0.5, 3 } } };
		g_triangles = { triangle1 };

		Light sun = { { 0, 10, 0 }, olc::Pixel(255, 255, 190) };
		g_lights = { sun };

		return true;
	}

	// Main loop
	bool OnUserUpdate(float fElapsedTime) override
	{
		Clear(olc::GREY);
		Controlls(fElapsedTime);
		RayTracing();

		return true;
	}

	void Controlls(float fElapsedTime)
	{

		if (GetKey(olc::Key::W).bHeld)
		{

		}

		if (GetKey(olc::Key::A).bHeld)
		{

		}

		if (GetKey(olc::Key::S).bHeld)
		{

		}

		if (GetKey(olc::Key::D).bHeld)
		{

		}

		if (GetKey(olc::Key::LEFT).bHeld)
		{

		}

		if (GetKey(olc::Key::RIGHT).bHeld)
		{

		}

		if (GetKey(olc::Key::UP).bHeld)
		{

		}

		if (GetKey(olc::Key::DOWN).bHeld)
		{

		}
	}

	void RayTracing()
	{
		float zFar = (SCREEN_WIDTH * 0.5f) / tan(g_player.FOV * 0.5f);

		for (int y = -SCREEN_HEIGHT / 2; y < SCREEN_HEIGHT / 2; y++)
		{
			for (int x = -SCREEN_WIDTH / 2; x < SCREEN_WIDTH / 2; x++)
			{
				Vec3D v_direction = { x, y, zFar };
				NormalizeVec3D(&v_direction);

				int screenX = x + SCREEN_WIDTH / 2;
				int screenY = (SCREEN_HEIGHT - 1) - (y + SCREEN_HEIGHT / 2);

				// Render spheres
				for (int i = 0; i < g_spheres.size(); i++)
				{
					RenderSpheres(g_spheres[i], g_player.coords, v_direction, screenX, screenY);
				}

				// Render triangles
				//for (int i = 0; i < g_triangles.size(); i++)
				//{
				//	RenderTriangles(g_triangles[i], g_player.coords, v_direction, screenX, screenY);
				//}
			}
		}
	}

	void RenderSpheres(Sphere sphere, Vec3D v_start, Vec3D v_direction, int screenX, int screenY)
	{
		Vec3D v_intersection = { 0, 0, 0 };

		//bool intersectionExists = SphereIntersection_RT(sphere, v_start, v_direction, true, &v_intersection);

		bool intersectionExists = SphereIntersection_RM(sphere, v_start, v_direction, true, &v_intersection);

		// Hard shadows
		bool shadow;
		

		for (int i = 0; i < g_lights.size(); i++)
		{
			Vec3D v_offset = SubtractVec3D(v_intersection, sphere.coords);
			NormalizeVec3D(&v_offset);
			v_offset = VecScalarMultiplication3D(v_offset, 0.05);

			Vec3D v_offsetIntersection = AddVec3D(v_offset, v_intersection);

			Vec3D v_direction = ReturnNormalizedVec3D(SubtractVec3D(g_lights[i].coords, v_intersection));

			shadow = !SphereIntersection_RM(sphere, v_offsetIntersection, v_direction, false);
		}

		if (intersectionExists)
		{
			Draw(screenX, screenY, olc::Pixel(255 * shadow, 255 * shadow, 255 * shadow));
		}
	}

	// Ray tracing for spheres
	bool SphereIntersection_RT(Sphere sphere, Vec3D v_start, Vec3D v_direction, bool b_calcIntersection, Vec3D* v_intersection = nullptr)
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

	// Ray marching for spheres
	bool SphereIntersection_RM(Sphere sphere, Vec3D v_start, Vec3D v_direction, bool b_calcIntersection, Vec3D* v_intersection = nullptr)
	{
		float touchingDistance = 0.01;
		float renderDistance = 10;
		float distanceTravelled = 0;

		while (distanceTravelled < renderDistance)
		{
			float distance = Distance3D(v_start, sphere.coords) - sphere.radius;
			distanceTravelled += distance;
			AddToVec3D(&v_start, VecScalarMultiplication3D(v_direction, distance));

			if (distance <= touchingDistance)
			{
				if (b_calcIntersection) *v_intersection = v_start;
				return true;
			}
		}

		return false;
	}

	void RenderTriangles(Triangle triangle, Vec3D v_start, Vec3D v_direction, int screenX, int screenY)
	{
		Vec3D v_intersection = { 0, 0, 0 };

		bool intersectionExists = TriangleIntersection_RT(triangle, v_start, v_direction, true, &v_intersection);

		if (intersectionExists)
		{
			Draw(screenX, screenY, olc::WHITE);
		}
	}

	// Ray tracing for triangles
	bool TriangleIntersection_RT(Triangle triangle, Vec3D v_start, Vec3D v_direction, 
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
		Vec3D v_triangleEdge1_normal = CrossProduct(SubtractVec3D(triangle.vertices[1], triangle.vertices[0]), v_triangleNormal);
		Vec3D v_triangleEdge2_normal = CrossProduct(SubtractVec3D(triangle.vertices[2], triangle.vertices[1]), v_triangleNormal);
		Vec3D v_triangleEdge3_normal = CrossProduct(SubtractVec3D(triangle.vertices[0], triangle.vertices[2]), v_triangleNormal);

		// check if the intersection is outside of the triangle
		if (DotProduct3D(v_triangleEdge1_normal, SubtractVec3D(v_trianglePlaneIntersection, triangle.vertices[1])) > 0) return false;
		if (DotProduct3D(v_triangleEdge2_normal, SubtractVec3D(v_trianglePlaneIntersection, triangle.vertices[2])) > 0) return false;
		if (DotProduct3D(v_triangleEdge3_normal, SubtractVec3D(v_trianglePlaneIntersection, triangle.vertices[0])) > 0) return false;

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

	bool TriangleIntersection_RM(Triangle triangle, Vec3D v_start, Vec3D v_direction,
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

		float f_signedDistanceToPlane = f_trianglePlaneOffset - DotProduct3D(v_start, v_triangleNormal);

		// the start vector projected onto the trianglePlane
		Vec3D vecProjectedOnPlane = AddVec3D(v_start, VecScalarMultiplication3D(v_triangleNormal, f_signedDistanceToPlane));

		Vec3D v_triangleEdge1_normal = CrossProduct(SubtractVec3D(triangle.vertices[1], triangle.vertices[0]), v_triangleNormal);
		NormalizeVec3D(&v_triangleEdge1_normal);
		Vec3D v_triangleEdge2_normal = CrossProduct(SubtractVec3D(triangle.vertices[2], triangle.vertices[1]), v_triangleNormal);
		NormalizeVec3D(&v_triangleEdge2_normal);
		Vec3D v_triangleEdge3_normal = CrossProduct(SubtractVec3D(triangle.vertices[0], triangle.vertices[2]), v_triangleNormal);
		NormalizeVec3D(&v_triangleEdge3_normal);

		bool b_projectedVecInsideTriangle = true;

		float signedDistEdge1 = DotProduct3D(v_triangleEdge1_normal, SubtractVec3D(vecProjectedOnPlane, triangle.vertices[1]));
		float signedDistEdge2 = DotProduct3D(v_triangleEdge2_normal, SubtractVec3D(vecProjectedOnPlane, triangle.vertices[2]));
		float signedDistEdge3 = DotProduct3D(v_triangleEdge3_normal, SubtractVec3D(vecProjectedOnPlane, triangle.vertices[0]));

		// check if the projected vector is outside of the triangle
		if (signedDistEdge1 > 0) b_projectedVecInsideTriangle = false;
		if (signedDistEdge2 > 0) b_projectedVecInsideTriangle = false;
		if (signedDistEdge3 > 0) b_projectedVecInsideTriangle = false;

		//if (b_projectedVecInsideTriangle == false)
		//{
		//	if()


		//}

		return true;
	}
};

int main()
{
	Engine rayTracer;
	if (rayTracer.Construct(SCREEN_WIDTH, SCREEN_HEIGHT, 1, 1))
		rayTracer.Start();
	return 0;
}