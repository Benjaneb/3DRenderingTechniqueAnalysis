#define OLC_PGE_APPLICATION
#define SCREEN_WIDTH 800
#define SCREEN_HEIGHT 500
#define RENDER_DISTANCE 50
#define TOUCHING_DISTANCE 0.001f
#define OFFSET_DISTANCE 0.002f
#define MAX_BOUNCES 2
#define SAMPLES_PER_PIXEL 1
#define SAMPLES_PER_RAY 1

#include <iostream>
#include <cuda_runtime.h>
#include <device_launch_parameters.h>
#include "olcPixelGameEngine.h"
#include "MathUtilities.cuh"
#include "WorldDatatypes.h"
#include "ParseOBJ.h"

// Global variables

Player g_player = { { 4, 6, -2 }, { 1, ZERO_VEC3D }, TAU * 0.25f };

Vec3D g_pixels[SCREEN_HEIGHT * SCREEN_WIDTH]; // Pixel buffer that contains all pixels that'll be drawn on screen
float g_depthBuffer[SCREEN_HEIGHT * SCREEN_WIDTH]; // Contains the distance to each point represented by a pixel

std::vector<Sphere> g_spheres;
std::vector<Triangle> g_triangles;

olc::Sprite* g_textureAtlas;


namespace Options
{
	bool mcControls = false;
}


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
		g_textureAtlas = new olc::Sprite("../Assets/basketball.png");

		g_spheres = 
		{
			{ { -5, 6, 11 }, 10, { 100, 200, 255 }, 1, 0.75, g_textureAtlas, { 0, 0 }, { 1, 1 }, CreateRotationQuaternion(ReturnNormalizedVec3D({ 1, 0, 1 }), PI / 4)},
			{ { 9, 6, 13 }, 3, { 255, 10, 100 }, 0.3, 0.8 }
		};

		g_triangles =
		{
			{ { { -2, 1, 3 }, { 0, 2, 3 }, { 1, 1.5, 3 } }, { { 0, 0 }, { 1, 1 }, { 0, 1 } } }
		};

		return true;
	}

	bool OnUserUpdate(float fElapsedTime) override
	{
		Controlls(fElapsedTime);
		RayTracing();

		return true;
	}

	// Defined in Controlls.h
	void Controlls(float fElapsedTime);

	void RayTracing()
	{
		float zFar = (SCREEN_WIDTH * 0.5f) / tan(g_player.FOV * 0.5f);

		for (int y = -SCREEN_HEIGHT * 0.5f; y < SCREEN_HEIGHT * 0.5f; y++)
		{
			for (int x = -SCREEN_WIDTH * 0.5f; x < SCREEN_WIDTH * 0.5f; x++)
			{
				Vec3D v_direction = { x, y, zFar };
				NormalizeVec3D(&v_direction);

				Vec3D v_newDirection = QuaternionMultiplication(g_player.q_orientation, { 0, v_direction }, QuaternionConjugate(g_player.q_orientation)).vecPart;

				int screenX = x + SCREEN_WIDTH * 0.5f;
				int screenY = (SCREEN_HEIGHT - 1) - (y + SCREEN_HEIGHT * 0.5f);

				Vec3D pixelColor = ZERO_VEC3D;

				for (int i = 0; i < SAMPLES_PER_PIXEL; i++)
				{
					// Clearing the buffers                        137, 250, 255
					g_pixels[SCREEN_WIDTH * screenY + screenX] = ZERO_VEC3D;
					g_depthBuffer[SCREEN_WIDTH * screenY + screenX] = INFINITY;

					RenderGround(g_player.coords, v_newDirection, screenX, screenY);

					RenderSpheres(g_player.coords, v_newDirection, screenX, screenY);

					//RenderTriangles(g_player.coords, v_newDirection, screenX, screenY);

					AddToVec3D(&pixelColor, g_pixels[SCREEN_WIDTH * screenY + screenX]);
				}

				ScaleVec3D(&pixelColor, 1 / float(SAMPLES_PER_PIXEL));

				pixelColor.x = Min(pixelColor.x, 255.0f);
				pixelColor.y = Min(pixelColor.y, 255.0f);
				pixelColor.z = Min(pixelColor.z, 255.0f);

				Draw(screenX, screenY, { uint8_t(pixelColor.x), uint8_t(pixelColor.y), uint8_t(pixelColor.z) });
			}
		}
	}

	void RenderGround(Vec3D v_start, Vec3D v_direction, int screenX, int screenY)
	{
		Vec3D v_intersectionColor = ZERO_VEC3D;

		bool intersectionExists;
		Vec3D v_intersection = ZERO_VEC3D;
		float depth = 0;

		float groundLevel = -1;
		VertexPair2D textureVertexPair = { { { 0, 0 }, { 1, 1 } } };
		float textureScalar = 10;

		intersectionExists = GroundIntersectionRT(groundLevel, textureVertexPair, textureScalar, v_start, v_direction, &v_intersection, &v_intersectionColor, &depth);

		if (intersectionExists && depth < g_depthBuffer[SCREEN_WIDTH * screenY + screenX])
		{
			v_intersectionColor = CalculateLighting_PathTracing(v_intersectionColor, 0, 0.3, { 0, 1, 0 }, v_intersection, 0);

			g_pixels[SCREEN_WIDTH * screenY + screenX] = v_intersectionColor;
			g_depthBuffer[SCREEN_WIDTH * screenY + screenX] = depth;
		}
	}

	bool GroundIntersectionRT(float groundLevel, VertexPair2D textureVertexPair, float textureScalar, Vec3D v_start, Vec3D v_direction,
		Vec3D* v_intersection = nullptr, Vec3D* v_intersectionColor = nullptr, float* depth = nullptr)
	{
		if (v_direction.y >= 0 || v_start.y < groundLevel)
		{
			return false;
		}

		if (v_intersection == nullptr)
		{
			return true;
		}

		ScaleVec3D(&v_direction, (groundLevel - v_start.y) / v_direction.y);

		Vec3D rayGroundIntersection = AddVec3D(v_start, v_direction);

		Vec3D v_offset = VecScalarMultiplication3D({ 0, 1, 0 }, OFFSET_DISTANCE);

		AddToVec3D(&rayGroundIntersection, v_offset);

		*v_intersection = rayGroundIntersection;

		if (depth != nullptr)
		{
			*depth = Distance3D(g_player.coords, rayGroundIntersection);
		}

		if (v_intersectionColor == nullptr)
		{
			return true;
		}

		float signedTextureWidth = (textureVertexPair.vertices[1].x - textureVertexPair.vertices[0].x) * textureScalar;
		float signedTextureHeight = (textureVertexPair.vertices[1].y - textureVertexPair.vertices[0].y) * textureScalar;

		float textureX = fmod(rayGroundIntersection.x, signedTextureWidth) / signedTextureWidth;
		float textureY = fmod(rayGroundIntersection.z, signedTextureHeight) / signedTextureHeight;

		// if the textureCoordinates are negative, we need to flip them around the center of the texture and make them positive
		if (textureX < 0) textureX += 1;
		if (textureY < 0) textureY += 1;

		olc::Pixel texelColor = g_textureAtlas->Sample(textureX + textureVertexPair.vertices[0].x, textureY + textureVertexPair.vertices[0].y);

		*v_intersectionColor = { float(texelColor.r), float(texelColor.g), float(texelColor.b) };

		return true;
	}

	/*bool GroundIntersectionRM(float groundLevel, VertexPair2D textureVertexPair, float textureScalar, Vec3D v_start, Vec3D v_direction, 
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

				olc::Pixel texelColor = g_textureAtlas->Sample(textureX, textureY);

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
		float depth = 0;
		Vec3D v_surfaceNormal = ZERO_VEC3D;

		for (int i = 0; i < g_spheres.size(); i++)
		{
			bool intersectionExists = SphereIntersection_RT(g_spheres[i], v_start, v_direction, &v_intersection, &v_intersectionColor, &depth, &v_surfaceNormal);

			//bool intersectionExists = SphereIntersection_RM(g_spheres[i], v_start, v_direction, &v_intersection, &depth);

			if (intersectionExists && depth < g_depthBuffer[SCREEN_WIDTH * screenY + screenX])
			{
				v_intersectionColor = CalculateLighting_PathTracing(v_intersectionColor, g_spheres[i].emittance, g_spheres[i].reflectance, v_surfaceNormal, v_intersection, 0);

				g_pixels[SCREEN_WIDTH * screenY + screenX] = v_intersectionColor;
				g_depthBuffer[SCREEN_WIDTH * screenY + screenX] = depth;
			}
		}
	}

	// Ray tracing for spheres
	bool SphereIntersection_RT(Sphere sphere, Vec3D v_start, Vec3D v_direction,
		Vec3D* v_intersection = nullptr, Vec3D* v_intersectionColor = nullptr, float* depth = nullptr, Vec3D* v_surfaceNormal = nullptr)
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

		Vec3D v_correctHit = (dist1 < dist2) ? v_alternative1 : v_alternative2;

		// Check if the intersection is behind the player. if so, discard it
		if (DotProduct3D(SubtractVec3D(v_correctHit, v_start), v_direction) < 0) return false;

		Vec3D v_normal = SubtractVec3D(v_correctHit, sphere.coords);
		NormalizeVec3D(&v_normal);

		// There exists an intersection which is not behind the ray, but we don't care about returning where the intersection was
		if (v_intersection != nullptr)
		{
			Vec3D v_offset = VecScalarMultiplication3D(v_normal, OFFSET_DISTANCE);

			// ISAK: Better to offset the intersection here so we don't have to do it anywere else
			*v_intersection = AddVec3D(v_correctHit, v_offset);
		}

		if (depth != nullptr)
		{
			*depth = Distance3D(g_player.coords, v_correctHit);
		}

		if (v_surfaceNormal != nullptr)
		{
			*v_surfaceNormal = v_normal;
		}

		if (v_intersectionColor != nullptr)
		{
			if (sphere.texture == nullptr) *v_intersectionColor = sphere.color;
			else *v_intersectionColor = SphereTexturing(sphere, v_normal);
		}

		return true;
	}

	Vec3D SphereTexturing(Sphere sphere, Vec3D v_normal)
	{
		Vec3D iHat = { 1, 0, 0 };
		Vec3D jHat = { 0, 1, 0 };
		Vec3D kHat = { 0, 0, 1 };

		// Rotating axies by sphere rotation quaternion
		iHat = QuaternionMultiplication(sphere.rotQuaternion, { 0, iHat }, QuaternionConjugate(sphere.rotQuaternion)).vecPart;
		jHat = QuaternionMultiplication(sphere.rotQuaternion, { 0, jHat }, QuaternionConjugate(sphere.rotQuaternion)).vecPart;
		kHat = QuaternionMultiplication(sphere.rotQuaternion, { 0, kHat }, QuaternionConjugate(sphere.rotQuaternion)).vecPart;

		// Translate normal into new coordinate system
		v_normal = { DotProduct3D(v_normal, iHat), DotProduct3D(v_normal, jHat), DotProduct3D(v_normal, kHat) };
		
		// UV coordinates
		float u = 0.5 + atan2(v_normal.x, v_normal.z) / TAU;
		float v = 0.5 - asin(v_normal.y) / PI;
		
		// Interpolate between assigned texture coordinates
		float textureX = Lerp(sphere.textureCorner1.x, sphere.textureCorner2.x, u);
		float textureY = Lerp(sphere.textureCorner1.y, sphere.textureCorner2.y, v);

		olc::Pixel texelColor = sphere.texture->Sample(textureX, textureY);

		return { (float)texelColor.r, (float)texelColor.g, (float)texelColor.b };
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
		Vec3D v_intersectionColor = ZERO_VEC3D;

		bool intersectionExists;
		Vec3D v_intersection = ZERO_VEC3D;
		Vec3D v_surfaceNormal = ZERO_VEC3D;
		float depth = 0;

		for (int i = 0; i < g_triangles.size(); i++)
		{
			intersectionExists = TriangleIntersection_RT(g_triangles[i], v_start, v_direction, &v_intersection, &v_intersectionColor, &depth, &v_surfaceNormal);

			if (intersectionExists && depth < g_depthBuffer[SCREEN_WIDTH * screenY + screenX])
			{
				g_pixels[SCREEN_WIDTH * screenY + screenX] = v_intersectionColor;
				g_depthBuffer[SCREEN_WIDTH * screenY + screenX] = depth;
			}
		}
	}

	// Ray tracing for triangles
	bool TriangleIntersection_RT(Triangle triangle, Vec3D v_start, Vec3D v_direction, 
		Vec3D* v_intersection = nullptr, Vec3D* v_intersectionColor = nullptr, float* depth = nullptr, Vec3D* v_surfaceNormal = nullptr)
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
		if ((DotProduct3D(v_triangleEdge1_normal, SubtractVec3D(v_trianglePlaneIntersection, triangle.vertices[1])) > 0) ||
			(DotProduct3D(v_triangleEdge2_normal, SubtractVec3D(v_trianglePlaneIntersection, triangle.vertices[2])) > 0) ||
			(DotProduct3D(v_triangleEdge3_normal, SubtractVec3D(v_trianglePlaneIntersection, triangle.vertices[0])) > 0))
		{
			return false;
		}

		Vec3D v_offset = VecScalarMultiplication3D(v_triangleNormal, OFFSET_DISTANCE);

		AddToVec3D(&v_trianglePlaneIntersection, v_offset);

		// if we don't care where the intersection is we just return true before setting v_intersection
		if (v_intersection != nullptr)
		{
			*v_intersection = v_trianglePlaneIntersection;
		}

		if (depth != nullptr)
		{
			*depth = Distance3D(g_player.coords, v_trianglePlaneIntersection);
		}

		if (v_surfaceNormal != nullptr)
		{
			*v_surfaceNormal = v_triangleNormal;
		}
		
		if (v_intersectionColor == nullptr)
		{
			return true;
		}

		// from here on we calculate the texture coordinates

		Vec2D v_textureTriangleEdge1 = SubtractVec2D(triangle.textureVertices[1], triangle.textureVertices[0]);
		Vec2D v_textureTriangleEdge2 = SubtractVec2D(triangle.textureVertices[2], triangle.textureVertices[0]);

		Vec3D v_intersectionRelativeToTriangle = SubtractVec3D(v_trianglePlaneIntersection, triangle.vertices[0]);

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

		olc::Pixel texelColor = g_textureAtlas->Sample(textureCoordinates.x, textureCoordinates.y);

		*v_intersectionColor = { float(texelColor.r), float(texelColor.g), float(texelColor.b) };
		
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

				olc::Pixel texelColor = g_textureAtlas->Sample(textureCoordinates.x, textureCoordinates.y);

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

	Vec3D CalculateLighting_PathTracing(Vec3D v_objectColor, float f_objectEmittance, float f_objectReflectance, Vec3D v_surfaceNormal, Vec3D v_start, int i_bounceCount)
	{
		Vec3D v_outgoingLightColor = VecScalarMultiplication3D(v_objectColor, f_objectEmittance);

		if (i_bounceCount > MAX_BOUNCES)
		{
			return v_outgoingLightColor;
		}

		Vec3D v_direction = ReturnNormalizedVec3D({ float(rand()), float(rand()), float(rand()) });

		// The direction vector is in the wrong hemisphere, so we need to flip it into the other hemisphere
		if (DotProduct3D(v_surfaceNormal, v_direction) < 0)
		{
			ScaleVec3D(&v_direction, -1);
		}

		for (int i = 0; i < g_spheres.size(); i++)
		{
			Vec3D v_intersection = ZERO_VEC3D;
			Vec3D v_intersectionColor = ZERO_VEC3D;
			Vec3D v_normal = ZERO_VEC3D;

			bool intersectionExists = SphereIntersection_RT(g_spheres[i], v_start, v_direction, &v_intersection, &v_intersectionColor, nullptr, &v_normal);

			bool b_rayIsBlocked = false;

			if (intersectionExists)
			{
				for (int j = 0; j < g_spheres.size(); j++)
				{
					Vec3D v_otherIntersection = ZERO_VEC3D;

					bool otherIntersectionExists = SphereIntersection_RT(g_spheres[j], v_start, v_direction, &v_otherIntersection);

					// If there exists a closer intersection to the ray start vector it means the ray is blocked
					if (otherIntersectionExists && DistanceSquared3D(v_start, v_otherIntersection) < DistanceSquared3D(v_start, v_intersection))
					{
						b_rayIsBlocked = true;
						break;
					}
				}

				for (int j = 0; j < g_triangles.size(); j++)
				{
					Vec3D v_otherIntersection = ZERO_VEC3D;

					bool otherIntersectionExists = TriangleIntersection_RT(g_triangles[j], v_start, v_direction, &v_otherIntersection);

					// If there exists a closer intersection to the ray start vector it means the ray is blocked
					if (otherIntersectionExists && DistanceSquared3D(v_start, v_otherIntersection) < DistanceSquared3D(v_start, v_intersection))
					{
						b_rayIsBlocked = true;
						break;
					}
				}
			}

			if (intersectionExists && b_rayIsBlocked == false)
			{
				Vec3D v_incomingLightColor = CalculateLighting_PathTracing(v_intersectionColor, g_spheres[i].emittance, g_spheres[i].reflectance, v_normal, v_intersection, i_bounceCount + 1);

				AddToVec3D(
					&v_outgoingLightColor,
					VecScalarMultiplication3D(v_incomingLightColor, 2 * f_objectReflectance * DotProduct3D(v_surfaceNormal, v_direction))
				);

				return v_outgoingLightColor;
			}
		}

		for (int i = 0; i < g_triangles.size(); i++)
		{
			Vec3D v_intersection = ZERO_VEC3D;
			Vec3D v_intersectionColor = ZERO_VEC3D;
			Vec3D v_normal = ZERO_VEC3D;

			bool intersectionExists = TriangleIntersection_RT(g_triangles[i], v_start, v_direction, &v_intersection, &v_intersectionColor, nullptr, &v_normal);

			bool b_rayIsBlocked = false;

			if (intersectionExists)
			{
				for (int j = 0; j < g_spheres.size(); j++)
				{
					Vec3D v_otherIntersection = ZERO_VEC3D;

					bool otherIntersectionExists = SphereIntersection_RT(g_spheres[j], v_start, v_direction, &v_otherIntersection);

					// If there exists a closer intersection to the ray start vector it means the ray is blocked
					if (otherIntersectionExists && DistanceSquared3D(v_start, v_otherIntersection) < DistanceSquared3D(v_start, v_intersection))
					{
						b_rayIsBlocked = true;
						break;
					}
				}

				for (int j = 0; j < g_triangles.size(); j++)
				{
					Vec3D v_otherIntersection = ZERO_VEC3D;

					bool otherIntersectionExists = TriangleIntersection_RT(g_triangles[j], v_start, v_direction, &v_otherIntersection);

					// If there exists a closer intersection to the ray start vector it means the ray is blocked
					if (otherIntersectionExists && DistanceSquared3D(v_start, v_otherIntersection) < DistanceSquared3D(v_start, v_intersection))
					{
						b_rayIsBlocked = true;
						break;
					}
				}
			}

			if (intersectionExists && b_rayIsBlocked == false)
			{
				Vec3D v_incomingLightColor = CalculateLighting_PathTracing(v_intersectionColor, g_triangles[i].emittance, g_triangles[i].reflectance, v_normal, v_intersection, i_bounceCount + 1);

				AddToVec3D(
					&v_outgoingLightColor,
					VecScalarMultiplication3D(v_incomingLightColor, 2 * f_objectReflectance * DotProduct3D(v_surfaceNormal, v_direction))
				);

				return v_outgoingLightColor;
			}
		}

		return v_outgoingLightColor;
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