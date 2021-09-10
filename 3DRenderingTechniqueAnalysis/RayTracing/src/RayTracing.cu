#define OLC_PGE_APPLICATION
#define SCREEN_WIDTH 1280
#define SCREEN_HEIGHT 720
#define RENDER_DISTANCE 50
#define TOUCHING_DISTANCE 0.01f

#include <iostream>
#include <cuda_runtime.h>
#include <device_launch_parameters.h>
#include "olcPixelGameEngine.h"
#include "MathUtilities.cuh"
#include "WorldDatatypes.h"

// Global variables

Player g_player = { { 0, 1, 0 }, { 1, { 0, 0, 0 } }, TAU * 0.25f };

olc::Pixel g_pixels[SCREEN_HEIGHT * SCREEN_WIDTH]; // Pixel buffer that contains all pixels that'll be drawn on screen
float g_depthBuffer[SCREEN_HEIGHT * SCREEN_WIDTH]; // Contains the most recent distance to the drawn object on every pixel

std::vector<Sphere> g_spheres;
std::vector<Triangle> g_triangles;
std::vector<LightSource> g_lights;

olc::Sprite* g_textureAtlas;

enum ControlsType
{
	TYPE_1,
	TYPE_2
};

ControlsType g_controlsType = TYPE_2;

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
		g_textureAtlas = new olc::Sprite("../Assets/textureAtlas.png");

		Sphere sphere1 = { { 1, 1, 10 }, 4, olc::BLUE, 2 };
		g_spheres = { sphere1 };

		Triangle triangle1 = {
			{ { -2, 1, 3 }, { 0, 2, 3 }, { 1, 1.5, 3 } },
			{ { 0, 0 }, { 1, 1 }, { 0, 1 } }
		};
		g_triangles = { triangle1 };

		LightSource sun = { { 0, 13, 0 }, { 255, 255, 190 } };
		g_lights = { sun };

		return true;
	}

	bool OnUserUpdate(float fElapsedTime) override
	{
		Controlls(fElapsedTime);
		RayTracing();

		return true;
	}

	void Controlls(float fElapsedTime)
	{
		float movementSpeed = 7 * fElapsedTime;
		float rotationSpeed = 2.5 * fElapsedTime;

		// Movement
		
		if (GetKey(olc::Key::W).bHeld)
		{
			Quaternion q_newDirection = QuaternionMultiplication(g_player.q_orientation, { 0, { 0, 0, 1 } }, ConjugateQuaternion(g_player.q_orientation));

			if (g_controlsType == TYPE_1)
			{
				q_newDirection.vecPart.y = 0;
			}

			NormalizeVec3D(&q_newDirection.vecPart);
			ScaleVec3D(&q_newDirection.vecPart, movementSpeed);

			AddToVec3D(&g_player.coords, q_newDirection.vecPart);
		}
		
		if (GetKey(olc::Key::A).bHeld)
		{
			Quaternion q_newDirection = QuaternionMultiplication(g_player.q_orientation, { 0, { -1, 0, 0 } }, ConjugateQuaternion(g_player.q_orientation));

			if (g_controlsType == TYPE_1)
			{
				q_newDirection.vecPart.y = 0;
			}

			NormalizeVec3D(&q_newDirection.vecPart);
			ScaleVec3D(&q_newDirection.vecPart, movementSpeed);

			AddToVec3D(&g_player.coords, q_newDirection.vecPart);
		}
		
		if (GetKey(olc::Key::S).bHeld)
		{
			Quaternion q_newDirection = QuaternionMultiplication(g_player.q_orientation, { 0, { 0, 0, -1 } }, ConjugateQuaternion(g_player.q_orientation));

			if (g_controlsType == TYPE_1)
			{
				q_newDirection.vecPart.y = 0;
			}

			NormalizeVec3D(&q_newDirection.vecPart);
			ScaleVec3D(&q_newDirection.vecPart, movementSpeed);

			AddToVec3D(&g_player.coords, q_newDirection.vecPart);
		}
		
		if (GetKey(olc::Key::D).bHeld)
		{
			Quaternion q_newDirection = QuaternionMultiplication(g_player.q_orientation, { 0, { 1, 0, 0 } }, ConjugateQuaternion(g_player.q_orientation));

			if (g_controlsType == TYPE_1)
			{
				q_newDirection.vecPart.y = 0;
			}

			NormalizeVec3D(&q_newDirection.vecPart);
			ScaleVec3D(&q_newDirection.vecPart, movementSpeed);

			AddToVec3D(&g_player.coords, q_newDirection.vecPart);
		}

		if (GetKey(olc::Key::SPACE).bHeld)
		{
			g_player.coords.y += movementSpeed;
		}

		if (GetKey(olc::Key::SHIFT).bHeld)
		{
			g_player.coords.y -= movementSpeed;
		}

		// Rotation
		
		if (GetKey(olc::Key::RIGHT).bHeld)
		{
			NormalizeQuaternion(&g_player.q_orientation);

			Quaternion q_newRotationAxis = QuaternionMultiplication(ConjugateQuaternion(g_player.q_orientation), { 0, { 0, 1, 0 } }, g_player.q_orientation);

			Quaternion rotationQuaternion = CreateRotationQuaternion(q_newRotationAxis.vecPart, rotationSpeed);

			g_player.q_orientation = QuaternionMultiplication(g_player.q_orientation, rotationQuaternion);
		}
		
		if (GetKey(olc::Key::LEFT).bHeld)
		{
			NormalizeQuaternion(&g_player.q_orientation);

			Quaternion q_newRotationAxis = QuaternionMultiplication(ConjugateQuaternion(g_player.q_orientation), { 0, { 0, 1, 0 } }, g_player.q_orientation);

			Quaternion rotationQuaternion = CreateRotationQuaternion(q_newRotationAxis.vecPart, -rotationSpeed);

			g_player.q_orientation = QuaternionMultiplication(g_player.q_orientation, rotationQuaternion);
		}
		
		if (GetKey(olc::Key::UP).bHeld)
		{
			NormalizeQuaternion(&g_player.q_orientation);

			Quaternion rotationQuaternion = CreateRotationQuaternion({ 1, 0, 0 }, -rotationSpeed);

			g_player.q_orientation = QuaternionMultiplication(g_player.q_orientation, rotationQuaternion);
		}
		
		if (GetKey(olc::Key::DOWN).bHeld)
		{
			NormalizeQuaternion(&g_player.q_orientation);

			Quaternion rotationQuaternion = CreateRotationQuaternion({ 1, 0, 0 }, rotationSpeed);

			g_player.q_orientation = QuaternionMultiplication(g_player.q_orientation, rotationQuaternion);
		}
	}

	void RayTracing()
	{
		float zFar = (SCREEN_WIDTH * 0.5f) / tan(g_player.FOV * 0.5f);

		for (int y = -SCREEN_HEIGHT * 0.5f; y < SCREEN_HEIGHT * 0.5f; y++)
		{
			for (int x = -SCREEN_WIDTH * 0.5f; x < SCREEN_WIDTH * 0.5f; x++)
			{
				Vec3D v_direction = { x, y, zFar };
				NormalizeVec3D(&v_direction);

				Vec3D v_newDirection = QuaternionMultiplication(g_player.q_orientation, { 0, v_direction }, ConjugateQuaternion(g_player.q_orientation)).vecPart;

				int screenX = x + SCREEN_WIDTH * 0.5f;
				int screenY = (SCREEN_HEIGHT - 1) - (y + SCREEN_HEIGHT * 0.5f);

				// Clearing the buffers
				g_pixels[SCREEN_WIDTH * screenY + screenX] = { 137, 250, 255 };
				g_depthBuffer[SCREEN_WIDTH * screenY + screenX] = INFINITY;

				RenderGround(g_player.coords, v_newDirection, screenX, screenY);

				RenderSpheres(g_player.coords, v_newDirection, screenX, screenY);

				//RenderTriangles(g_player.coords, v_newDirection, screenX, screenY);

				Draw(screenX, screenY, g_pixels[SCREEN_WIDTH * screenY + screenX]);
			}
		}
	}

	void RenderGround(Vec3D v_start, Vec3D v_direction, int screenX, int screenY)
	{
		olc::Pixel pixelColor = { 0, 0, 0 };

		bool intersectionExists;
		Vec3D v_intersection = { 0, 0, 0 };
		float depth = 0;

		float groundLevel = -1;
		VertexPair2D textureVertexPair = { { { 0, 0 }, { 1, 1 } } };
		float textureScalar = 10;

		intersectionExists = GroundIntersectionRT(groundLevel, textureVertexPair, textureScalar, v_start, v_direction, &v_intersection, &depth, &pixelColor);

		if (intersectionExists && depth < g_depthBuffer[SCREEN_WIDTH * screenY + screenX])
		{
			g_pixels[SCREEN_WIDTH * screenY + screenX] = pixelColor;
			g_depthBuffer[SCREEN_WIDTH * screenY + screenX] = depth;
		}
	}

	bool GroundIntersectionRT(float groundLevel, VertexPair2D textureVertexPair, float textureScalar, Vec3D v_start, Vec3D v_direction, 
		Vec3D* v_intersection = nullptr, float* depth = nullptr, olc::Pixel* pixelColor = nullptr)
	{
		if (v_direction.y >= 0)
		{
			return false;
		}

		if (v_intersection == nullptr)
		{
			return true;
		}

		ScaleVec3D(&v_direction, (groundLevel - v_start.y) / v_direction.y);

		Vec3D rayGroundIntersection = AddVec3D(v_start, v_direction);

		*v_intersection = rayGroundIntersection;
		*depth = Distance3D(g_player.coords, rayGroundIntersection);

		if (pixelColor == nullptr)
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

		*pixelColor = g_textureAtlas->Sample(textureX + textureVertexPair.vertices[0].x, textureY + textureVertexPair.vertices[0].y);

		return true;
	}

	bool GroundIntersectionRM(float groundLevel, VertexPair2D textureVertexPair, float textureScalar, Vec3D v_start, Vec3D v_direction, 
		Vec3D* v_intersection = nullptr, float* depth = nullptr, olc::Pixel* pixelColor = nullptr)
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

				*pixelColor = g_textureAtlas->Sample(textureX + textureVertexPair.vertices[0].x, textureY + textureVertexPair.vertices[0].y);

				return true;
			}

			totalDistanceTravelled += distanceToGround;
		}

		return false;
	}

	void RenderSpheres(Vec3D v_start, Vec3D v_direction, int screenX, int screenY)
	{
		Vec3D v_intersection = { 0, 0, 0 };
		float minDistance_RM = 0;
		bool shadow = 1;
		float depth = 0;

		for (int i = 0; i < g_spheres.size(); i++)
		{
			//bool intersectionExists = SphereIntersection_RT(g_spheres[i], v_start, v_direction, &v_intersection);

			bool intersectionExists = SphereIntersection_RM(g_spheres[i], v_start, v_direction, &v_intersection, &depth, &minDistance_RM);

			// Hard shadows
			if (g_spheres[i].luminance <= 0)
			{
				for (int i = 0; i < g_lights.size(); i++)
				{
					Vec3D v_offset = SubtractVec3D(v_intersection, g_spheres[i].coords);
					NormalizeVec3D(&v_offset);
					v_offset = VecScalarMultiplication3D(v_offset, 0.05);

					Vec3D v_offsetIntersection = AddVec3D(v_offset, v_intersection);

					Vec3D v_direction = ReturnNormalizedVec3D(SubtractVec3D(g_lights[i].coords, v_intersection));

					shadow = !SphereIntersection_RM(g_spheres[i], v_offsetIntersection, v_direction);
				}
			}

			// No glow
			if (intersectionExists && depth < g_depthBuffer[SCREEN_WIDTH * screenY + screenX])
			{
				olc::Pixel pixelColor;
				pixelColor.r = g_spheres[i].color.r * shadow;
				pixelColor.b = g_spheres[i].color.b * shadow;
				pixelColor.g = g_spheres[i].color.g * shadow;

				g_pixels[SCREEN_WIDTH * screenY + screenX] = pixelColor;
				g_depthBuffer[SCREEN_WIDTH * screenY + screenX] = depth;
			}
			// Glow (mix background color with glow color)
			else if (!intersectionExists && g_spheres[i].luminance > 0)
			{
				olc::Pixel glowColor;

				float glowBrightness = 1 / ((minDistance_RM / g_spheres[i].luminance) + 1);

				glowColor = ColorScalarMultiplication(g_spheres[i].color, glowBrightness);

				AddToColor(&glowColor, g_pixels[SCREEN_WIDTH * screenY + screenX]);

				// Makes sure the background doesn't get darker when the glow decreases
				glowColor = ColorScalarMultiplication(glowColor, 1 / (1 + glowBrightness));

				g_pixels[SCREEN_WIDTH * screenY + screenX] = glowColor;
			}
		}
	}

	// Ray tracing for spheres
	bool SphereIntersection_RT(Sphere sphere, Vec3D v_start, Vec3D v_direction, float* depth = nullptr, Vec3D* v_intersection = nullptr)
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
		if (v_intersection == nullptr) return true;
		
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

		// Check if the intersection is behind the player. if so, discard it
		float dotProduct = DotProduct3D(v_correctHit, v_start);
		if (dotProduct < 0) return false;

		*v_intersection = v_correctHit;
		*depth = Distance3D(g_player.coords, v_correctHit);

		return true;
	}

	// Ray marching for spheres
	bool SphereIntersection_RM(Sphere sphere, Vec3D v_start, Vec3D v_direction, 
		Vec3D* v_intersection = nullptr, float* depth = nullptr, float* minDistance = nullptr)
	{
		float distanceTravelled = 0;
		float currentMin = INFINITY;

		while (distanceTravelled < RENDER_DISTANCE)
		{
			float distance = Distance3D(v_start, sphere.coords) - sphere.radius;
			currentMin = Min(currentMin, distance); // For glow
			distanceTravelled += distance;
			AddToVec3D(&v_start, VecScalarMultiplication3D(v_direction, distance));

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

		if (minDistance != nullptr && sphere.luminance > 0) *minDistance = currentMin;

		return false;
	}

	void RenderTriangles(Vec3D v_start, Vec3D v_direction, int screenX, int screenY)
	{
		olc::Pixel pixelColor = { 0, 0, 0 };

		bool intersectionExists;
		Vec3D v_intersection = { 0, 0, 0 };
		float depth = 0;

		for (int i = 0; i < g_triangles.size(); i++)
		{
			intersectionExists = TriangleIntersection_RT(g_triangles[i], v_start, v_direction, &v_intersection, &depth, &pixelColor);
		}

		if (intersectionExists && depth < g_depthBuffer[SCREEN_WIDTH * screenY + screenX])
		{
			g_pixels[SCREEN_WIDTH * screenY + screenX] = pixelColor;
			g_depthBuffer[SCREEN_WIDTH * screenY + screenX] = depth;
		}
	}

	// Ray tracing for triangles
	bool TriangleIntersection_RT(Triangle triangle, Vec3D v_start, Vec3D v_direction, Vec3D* v_intersection = nullptr, float* depth = nullptr, olc::Pixel* pixelColor = nullptr)
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

		// if we don't care where the intersection is we just return true before setting v_intersection
		if (v_intersection == nullptr)
		{
			return true;
		}

		*v_intersection = v_trianglePlaneIntersection;
		*depth = Distance3D(g_player.coords, v_trianglePlaneIntersection);

		// calculating the texture coordinates
		if (pixelColor == nullptr)
		{
			return true;
		}

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

		*pixelColor = g_textureAtlas->Sample(textureCoordinates.x, textureCoordinates.y);
		
		return true;
	}

	Vec3D LinePlaneIntersection(Vec3D v_start, Vec3D v_direction, Vec3D v_planeNormal, float f_planeOffset)
	{
		float f_deltaOffset = DotProduct3D(v_start, v_planeNormal);

		f_planeOffset -= f_deltaOffset;

		float f_scalingFactor = f_planeOffset / DotProduct3D(v_direction, v_planeNormal);

		return AddVec3D(VecScalarMultiplication3D(v_direction, f_scalingFactor), v_start);
	}

	bool TriangleIntersection_RM(Triangle triangle, Vec3D v_start, Vec3D v_direction, Vec3D* v_intersection = nullptr, float* depth = nullptr, olc::Pixel* pixelColor = nullptr)
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

				*pixelColor = g_textureAtlas->Sample(textureCoordinates.x, textureCoordinates.y);

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
	}

	void MixColor(olc::Pixel* color1, olc::Pixel color2)
	{
		color1->r = (color2.r + color1->r) / 2;
		color1->g = (color2.g + color1->g) / 2;
		color1->b = (color2.b + color1->b) / 2;
	}
};

int main()
{
	Engine rayTracer;
	if (rayTracer.Construct(SCREEN_WIDTH, SCREEN_HEIGHT, 1, 1))
		rayTracer.Start();
	return 0;
}