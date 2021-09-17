#pragma once
#define PI 3.141592
#define TAU 6.283185
#define ZERO_VEC3D { 0, 0, 0 }
#define IDENTITY_QUATERNION { 1, { 0, 0, 0 } }

/*
// Datatypes
*/

struct Vec2D
{
	float x, y;
};

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
	float realPart;
	Vec3D vecPart;
};

/*
// Methods
*/

// Methods for numbers

float Abs(float a)
{
	return (a >= 0) ? a : -a;
}

float Min(float a, float b)
{
	return (a < b) ? a : b;
}

float Max(float a, float b)
{
	return (a > b) ? a : b;
}

void Clamp(float* valueToClamp, float lowerBound, float upperBound)
{
	// Clamps a value between two other values. e.g: Clamp(7, 5, 10) is 7 because its already between 5 and 10
	*valueToClamp = Min(upperBound, Max(lowerBound, *valueToClamp));
}

float Clamp(float valueToClamp, float lowerBound, float upperBound)
{
	// Clamps a value between two other values. e.g: Clamp(7, 5, 10) is 7 because its already between 5 and 10
	return Min(upperBound, Max(lowerBound, valueToClamp));
}

float Lerp(float startValue, float endValue, float t)
{
	// Linearly interpolate between two numbers
	return startValue + (endValue - startValue) * t;
}

//
// Methods for 2D vectors
//

void AddToVec2D(Vec2D* v1, Vec2D v2)
{
	v1->x += v2.x;
	v1->y += v2.y;
}

Vec2D AddVec2D(Vec2D v1, Vec2D v2)
{
	return { v1.x + v2.x, v1.y + v2.y };
}

void SubtractFromVec2D(Vec2D* v1, Vec2D v2)
{
	v1->x -= v2.x;
	v1->y -= v2.y;
}

Vec2D SubtractVec2D(Vec2D v1, Vec2D v2)
{
	return { v1.x - v2.x, v1.y - v2.y };
}

void ScaleVec2D(Vec2D* v, float scalar)
{
	v->x *= scalar;
	v->y *= scalar;
}

Vec2D VecScalarMultiplication2D(Vec2D v, float scalar)
{
	return { v.x * scalar, v.y * scalar };
}

float VecLength2D(Vec2D v)
{
	return sqrt(v.x * v.x + v.y * v.y);
}

float Distance2D(Vec2D v1, Vec2D v2)
{
	return sqrt((v2.x - v1.x) * (v2.x - v1.x) + (v2.y - v1.y) * (v2.y - v1.y));
}

void NormalizeVec2D(Vec2D* v)
{
	float inverseVectorLength = 1 / sqrt(v->x * v->x + v->y * v->y);

	v->x *= inverseVectorLength;
	v->y *= inverseVectorLength;
}

float DotProduct2D(Vec2D v1, Vec2D v2)
{
	return v1.x * v2.x + v1.y * v2.y;
}

Vec2D Lerp2D(Vec2D startVector, Vec2D endVector, float t)
{
	Vec2D result;

	result.x = startVector.x + (endVector.x - startVector.x) * t;
	result.y = startVector.y + (endVector.y - startVector.y) * t;

	return result;
}

//
// Methods for 3D vectors
//

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

void SubtractFromVec3D(Vec3D* v1, Vec3D v2)
{
	v1->x -= v2.x;
	v1->y -= v2.y;
	v1->z -= v2.z;
}

Vec3D SubtractVec3D(Vec3D v1, Vec3D v2)
{
	return { v1.x - v2.x, v1.y - v2.y, v1.z - v2.z };
}

void ScaleVec3D(Vec3D* v, float scalar)
{
	v->x *= scalar;
	v->y *= scalar;
	v->z *= scalar;
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

//
// Methods for matrices (and vectors I guess)
//

Vec3D VecMatrixMultiplication3D(Vec3D v, Matrix3D m)
{
	Vec3D result = ZERO_VEC3D;

	AddToVec3D(&result, VecScalarMultiplication3D(m.i_Hat, v.x));
	AddToVec3D(&result, VecScalarMultiplication3D(m.j_Hat, v.y));
	AddToVec3D(&result, VecScalarMultiplication3D(m.k_Hat, v.z));

	return result;
}

Matrix3D MatrixMultiplication3D(Matrix3D m1, Matrix3D m2)
{
	Matrix3D newMatrix =
	{
		VecMatrixMultiplication3D(m1.i_Hat, m2),
		VecMatrixMultiplication3D(m1.j_Hat, m2),
		VecMatrixMultiplication3D(m1.k_Hat, m2)
	};
	
	return newMatrix;
}

Matrix3D InverseMatrix3D(Matrix3D m)
{
	float reciprocalDetM = 1 / DotProduct3D(m.i_Hat, CrossProduct(m.j_Hat, m.k_Hat));

	Vec3D new_i_Hat;
	Vec3D new_j_Hat;
	Vec3D new_k_Hat;

	new_i_Hat.x = m.j_Hat.y * m.k_Hat.z - m.k_Hat.y * m.j_Hat.z;
	new_i_Hat.y = -(m.i_Hat.y * m.k_Hat.z - m.k_Hat.y * m.i_Hat.z);
	new_i_Hat.z = m.i_Hat.y * m.j_Hat.z - m.j_Hat.y * m.i_Hat.z;

	new_j_Hat.x = -(m.j_Hat.x * m.k_Hat.z - m.k_Hat.x * m.j_Hat.z);
	new_j_Hat.y = m.i_Hat.x * m.k_Hat.z - m.k_Hat.x * m.i_Hat.z;
	new_j_Hat.z = -(m.i_Hat.x * m.j_Hat.z - m.j_Hat.x * m.i_Hat.z);

	new_k_Hat.x = m.j_Hat.x * m.k_Hat.y - m.k_Hat.x * m.j_Hat.y;
	new_k_Hat.y = -(m.i_Hat.x * m.k_Hat.y - m.k_Hat.x * m.i_Hat.y);
	new_k_Hat.z = m.i_Hat.x * m.j_Hat.y - m.j_Hat.x * m.i_Hat.y;

	new_i_Hat = VecScalarMultiplication3D(new_i_Hat, reciprocalDetM);
	new_j_Hat = VecScalarMultiplication3D(new_j_Hat, reciprocalDetM);
	new_k_Hat = VecScalarMultiplication3D(new_k_Hat, reciprocalDetM);

	Matrix3D invertedMatrix =
	{
		new_i_Hat,
		new_j_Hat,
		new_k_Hat
	};

	return invertedMatrix;
}

//
// Methods for quaternions
//

Quaternion CreateRotationQuaternion(Vec3D axis, float angle)
{
	return { cos(angle * 0.5f), VecScalarMultiplication3D(axis, sin(angle * 0.5f)) };
}

Quaternion QuaternionConjugate(Quaternion q)
{
	return { q.realPart, { -q.vecPart.x, -q.vecPart.y, -q.vecPart.z } };
}

// Multiplies two quaternions
Quaternion QuaternionMultiplication(Quaternion q1, Quaternion q2)
{
	Quaternion result = { 0, ZERO_VEC3D };

	result.vecPart.x = q1.vecPart.x * q2.realPart + q1.vecPart.y * q2.vecPart.z - q1.vecPart.z * q2.vecPart.y + q1.realPart * q2.vecPart.x;
	result.vecPart.y = -q1.vecPart.x * q2.vecPart.z + q1.vecPart.y * q2.realPart + q1.vecPart.z * q2.vecPart.x + q1.realPart * q2.vecPart.y;
	result.vecPart.z = q1.vecPart.x * q2.vecPart.y - q1.vecPart.y * q2.vecPart.x + q1.vecPart.z * q2.realPart + q1.realPart * q2.vecPart.z;
	result.realPart = -q1.vecPart.x * q2.vecPart.x - q1.vecPart.y * q2.vecPart.y - q1.vecPart.z * q2.vecPart.z + q1.realPart * q2.realPart;

	return result;
}

// Multiplies three quaternions
Quaternion QuaternionMultiplication(Quaternion q1, Quaternion q2, Quaternion q3)
{
	Quaternion firstMultiplication = QuaternionMultiplication(q1, q2);

	return QuaternionMultiplication(firstMultiplication, q3);
}

void NormalizeQuaternion(Quaternion* q)
{
	float reciprocalLength = 1 / sqrt(q->realPart * q->realPart + q->vecPart.x * q->vecPart.x + q->vecPart.y * q->vecPart.y + q->vecPart.z * q->vecPart.z);

	q->realPart *= reciprocalLength;
	q->vecPart.x *= reciprocalLength;
	q->vecPart.y *= reciprocalLength;
	q->vecPart.z *= reciprocalLength;
}