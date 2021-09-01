#pragma once
#define PI 3.141592
#define TAU 6.283185

/*
// Datatypes
*/

struct Vec3D
{
	float x, y, z;
};

struct Matrix3D
{
	Vec3D i_Hat, j_Hat, k_Hat;
};

struct Quaternion
{
	float a, i, j, k;
};

/*
// Methods
*/

// Methods for numbers

float Min(float a, float b)
{
	return (a < b) ? a : b;
}

float Max(float a, float b)
{
	return (a > b) ? a : b;
}

float Clamp(float lowerBound, float upperBound, float valueToClamp)
{
	// Clamps a value between two other values. e.g: Clamp(5, 10, 7) is 7 because its already between 5 and 10
	return Min(upperBound, Max(lowerBound, valueToClamp));
}

float Lerp(float startValue, float endValue, float t)
{
	// Linearly interpolate between two numbers
	return startValue + (endValue - startValue) * t;
}

// Methods for vectors

void AddToVec3D(Vec3D* v1, Vec3D v2)
{
	v1->x += v2.x;
	v1->y += v2.y;
	v1->z += v2.z;
}

Vec3D AddVec3D(Vec3D v1, Vec3D v2)
{
	return { v1.x + v2.x, v1.y + v2.y, v1.z + v2.z };
}

Vec3D SubtractVec3D(Vec3D v1, Vec3D v2)
{
	return { v1.x - v2.x, v1.y - v2.y, v1.z - v2.z };
}

Vec3D VecScalarMultiplication3D(Vec3D v, float scalar)
{
	return { v.x * scalar, v.y * scalar, v.z * scalar };
}

float VecLength3D(Vec3D v)
{
	return sqrt(v.x * v.x + v.y * v.y + v.z * v.z);
}

float VecLengthSquared(Vec3D v)
{
	return v.x * v.x + v.y * v.y + v.z * v.z;
}

float Distance3D(Vec3D v1, Vec3D v2)
{
	return sqrt((v2.x - v1.x) * (v2.x - v1.x) + (v2.y - v1.y) * (v2.y - v1.y) + (v2.z - v1.z) * (v2.z - v1.z));
}

float DistanceSquared3D(Vec3D v1, Vec3D v2)
{
	return (v2.x - v1.x) * (v2.x - v1.x) + (v2.y - v1.y) * (v2.y - v1.y) + (v2.z - v1.z) * (v2.z - v1.z);
}

void NormalizeVec3D(Vec3D* v)
{
	float inverseVectorLength = 1 / sqrt(v->x * v->x + v->y * v->y + v->z * v->z);

	v->x *= inverseVectorLength;
	v->y *= inverseVectorLength;
	v->z *= inverseVectorLength;
}

Vec3D ReturnNormalizedVec3D(Vec3D v)
{
	float inverseVectorLength = 1 / sqrt(v.x * v.x + v.y * v.y + v.z * v.z);

	return { v.x * inverseVectorLength, v.y * inverseVectorLength, v.z * inverseVectorLength };
}

float DotProduct3D(Vec3D v1, Vec3D v2)
{
	return v1.x * v2.x + v1.y * v2.y + v1.z * v2.z;
}

Vec3D CrossProduct(Vec3D a, Vec3D b)
{
	return { a.y * b.z - a.z * b.y, a.z * b.x - a.x * b.z, a.x * b.y - a.y * b.x };
}

// Very useful
Vec3D ConusProduct(Vec3D a, Vec3D b)
{
	return { a.x * b.x, a.y * b.y, a.z * b.z };
}

Vec3D Lerp3D(Vec3D startVector, Vec3D endVector, float t)
{
	Vec3D result;

	result.x = startVector.x + (endVector.x - startVector.x) * t;
	result.y = startVector.y + (endVector.y - startVector.y) * t;
	result.z = startVector.z + (endVector.z - startVector.z) * t;

	return result;
}

Vec3D VecMatrixMultiplication3D(Vec3D v, Matrix3D m)
{
	Vec3D result = { 0, 0, 0 };

	AddToVec3D(&result, VecScalarMultiplication3D(m.i_Hat, v.x));
	AddToVec3D(&result, VecScalarMultiplication3D(m.j_Hat, v.y));
	AddToVec3D(&result, VecScalarMultiplication3D(m.k_Hat, v.z));

	return result;
}

// Methods for quaternions

// Multiplies two quaternions
Quaternion QuaternionMultiplication(Quaternion q1, Quaternion q2)
{

}

// Multiplies three quaternions
Quaternion QuaternionMultiplication(Quaternion q1, Quaternion q2, Quaternion q3)
{

}

// Things to add:
// 1. matrix-matrix multiplication
// 2. matrix inversion function (returns the inverse of a matrix)