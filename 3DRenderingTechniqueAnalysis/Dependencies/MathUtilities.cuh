#pragma once
#define PI 3.141592
#define TAU 6.283185
#define ZERO_VEC2D { 0, 0 }
#define ZERO_VEC3D { 0, 0, 0 }
#define IDENTITY_QUATERNION { 1, { 0, 0, 0 } }

/*
// Datatypes
*/

struct Vec2D
{
	double x, y;
};

struct Vec3D
{
	double x, y, z;
};

struct Matrix3D
{
	Vec3D i_Hat, j_Hat, k_Hat;
};

struct Quaternion
{
	double realPart;
	Vec3D vecPart;
};

/*
// Methods
*/

// Methods for numbers

double Abs(double a)
{
	return (a >= 0) ? a : -a;
}

double Sign(double a)
{
	return (a >= 0) ? 1 : -1;
}

double Min(double a, double b)
{
	return (a < b) ? a : b;
}

double Max(double a, double b)
{
	return (a > b) ? a : b;
}

void Clamp(double* valueToClamp, double lowerBound, double upperBound)
{
	// Clamps a value between two other values. e.g: Clamp(7, 5, 10) is 7 because its already between 5 and 10
	*valueToClamp = Min(upperBound, Max(lowerBound, *valueToClamp));
}

double Clamp(double valueToClamp, double lowerBound, double upperBound)
{
	// Clamps a value between two other values. e.g: Clamp(7, 5, 10) is 7 because its already between 5 and 10
	return Min(upperBound, Max(lowerBound, valueToClamp));
}

double Lerp(double startValue, double endValue, double t)
{
	// Linearly interpolate between two numbers
	return startValue + (endValue - startValue) * t;
}

double Square(double a)
{
	return a * a;
}

double Sigmoid(double x)
{
	double expTerm = exp(x);

	return (expTerm - 1) / (expTerm + 1);
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

void ScaleVec2D(Vec2D* v, double scalar)
{
	v->x *= scalar;
	v->y *= scalar;
}

Vec2D VecScalarMultiplication2D(Vec2D v, double scalar)
{
	return { v.x * scalar, v.y * scalar };
}

double VecLength2D(Vec2D v)
{
	return sqrt(v.x * v.x + v.y * v.y);
}

double Distance2D(Vec2D v1, Vec2D v2)
{
	return sqrt((v2.x - v1.x) * (v2.x - v1.x) + (v2.y - v1.y) * (v2.y - v1.y));
}

void NormalizeVec2D(Vec2D* v)
{
	double inverseVectorLength = 1 / sqrt(v->x * v->x + v->y * v->y);

	v->x *= inverseVectorLength;
	v->y *= inverseVectorLength;
}

double DotProduct2D(Vec2D v1, Vec2D v2)
{
	return v1.x * v2.x + v1.y * v2.y;
}

Vec2D Lerp2D(Vec2D startVector, Vec2D endVector, double t)
{
	Vec2D result;

	result.x = startVector.x + (endVector.x - startVector.x) * t;
	result.y = startVector.y + (endVector.y - startVector.y) * t;

	return result;
}

// Used for vertex sorting
bool MaxY2D(Vec2D v1, Vec2D v2)
{
	return (v1.y > v2.y);
}

//
// Methods for 3D vectors
//

void PrintVec3D(Vec3D v)
{
	std::cout << v.x << " " << v.y << " " << v.z << std::endl;
}

inline void AddToVec3D(Vec3D* v1, Vec3D v2)
{
	v1->x += v2.x;
	v1->y += v2.y;
	v1->z += v2.z;
}

Vec3D AddVec3D(Vec3D v1, Vec3D v2)
{
	return { v1.x + v2.x, v1.y + v2.y, v1.z + v2.z };
}

inline void SubtractFromVec3D(Vec3D* v1, Vec3D v2)
{
	v1->x -= v2.x;
	v1->y -= v2.y;
	v1->z -= v2.z;
}

inline Vec3D SubtractVec3D(Vec3D v1, Vec3D v2)
{
	return { v1.x - v2.x, v1.y - v2.y, v1.z - v2.z };
}

inline void ScaleVec3D(Vec3D* v, double scalar)
{
	v->x *= scalar;
	v->y *= scalar;
	v->z *= scalar;
}

inline Vec3D VecScalarMultiplication3D(Vec3D v, double scalar)
{
	return { v.x * scalar, v.y * scalar, v.z * scalar };
}

double VecLength3D(Vec3D v)
{
	return sqrt(v.x * v.x + v.y * v.y + v.z * v.z);
}

double VecLengthSquared(Vec3D v)
{
	return v.x * v.x + v.y * v.y + v.z * v.z;
}

double Distance3D(Vec3D v1, Vec3D v2)
{
	return sqrt((v2.x - v1.x) * (v2.x - v1.x) + (v2.y - v1.y) * (v2.y - v1.y) + (v2.z - v1.z) * (v2.z - v1.z));
}

double DistanceSquared3D(Vec3D v1, Vec3D v2)
{
	return (v2.x - v1.x) * (v2.x - v1.x) + (v2.y - v1.y) * (v2.y - v1.y) + (v2.z - v1.z) * (v2.z - v1.z);
}

void NormalizeVec3D(Vec3D* v)
{
	double inverseVectorLength = 1 / sqrt(v->x * v->x + v->y * v->y + v->z * v->z);

	v->x *= inverseVectorLength;
	v->y *= inverseVectorLength;
	v->z *= inverseVectorLength;
}

Vec3D ReturnNormalizedVec3D(Vec3D v)
{
	double inverseVectorLength = 1 / sqrt(v.x * v.x + v.y * v.y + v.z * v.z);

	return { v.x * inverseVectorLength, v.y * inverseVectorLength, v.z * inverseVectorLength };
}

inline double DotProduct3D(Vec3D v1, Vec3D v2)
{
	return v1.x * v2.x + v1.y * v2.y + v1.z * v2.z;
}

inline Vec3D CrossProduct(Vec3D a, Vec3D b)
{
	return { a.y * b.z - a.z * b.y, a.z * b.x - a.x * b.z, a.x * b.y - a.y * b.x };
}

// Very useful
inline Vec3D ConusProduct(Vec3D a, Vec3D b)
{
	return { a.x * b.x, a.y * b.y, a.z * b.z };
}

inline Vec3D Lerp3D(Vec3D startVector, Vec3D endVector, double t)
{
	Vec3D result;

	result.x = startVector.x + (endVector.x - startVector.x) * t;
	result.y = startVector.y + (endVector.y - startVector.y) * t;
	result.z = startVector.z + (endVector.z - startVector.z) * t;

	return result;
}

void SwapVec3D(Vec3D* vec1, Vec3D* vec2)
{
	Vec3D temp = *vec1;
	*vec1 = *vec2;
	*vec2 = temp;
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
	double reciprocalDetM = 1 / DotProduct3D(m.i_Hat, CrossProduct(m.j_Hat, m.k_Hat));

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

Quaternion CreateRotationQuaternion(Vec3D axis, double angle)
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
	double reciprocalLength = 1 / sqrt(q->realPart * q->realPart + q->vecPart.x * q->vecPart.x + q->vecPart.y * q->vecPart.y + q->vecPart.z * q->vecPart.z);

	q->realPart *= reciprocalLength;
	q->vecPart.x *= reciprocalLength;
	q->vecPart.y *= reciprocalLength;
	q->vecPart.z *= reciprocalLength;
}