#pragma once

void Engine::Controlls(float fElapsedTime)
{
	float movementSpeed = 8 * fElapsedTime;
	float rotationSpeed = 2.5 * fElapsedTime;

	Vec3D* v_movement;
	Quaternion* q_rotation;

#ifdef RAY_TRACER
	v_movement = &g_player.coords;
	q_rotation = &g_player.q_orientation;
#endif

#ifdef RASTERIZER
	Vec3D v_worldMovement = ZERO_VEC3D;
	Quaternion q_worldRotation = IDENTITY_QUATERNION;
	v_movement = &v_worldMovement;
	q_rotation = &q_worldRotation;
#endif

	// Movement

	if (GetKey(olc::Key::W).bHeld)
	{
		Quaternion q_newDirection = QuaternionMultiplication(*q_rotation, { 0, { 0, 0, 1 } }, QuaternionConjugate(*q_rotation));

		if (Options::mcControls)
		{
			q_newDirection.vecPart.y = 0;
		}

		NormalizeVec3D(&q_newDirection.vecPart);
		ScaleVec3D(&q_newDirection.vecPart, movementSpeed);

		AddToVec3D(v_movement, q_newDirection.vecPart);
	}

	if (GetKey(olc::Key::A).bHeld)
	{
		Quaternion q_newDirection = QuaternionMultiplication(*q_rotation, { 0, { -1, 0, 0 } }, QuaternionConjugate(*q_rotation));

		if (Options::mcControls)
		{
			q_newDirection.vecPart.y = 0;
		}

		NormalizeVec3D(&q_newDirection.vecPart);
		ScaleVec3D(&q_newDirection.vecPart, movementSpeed);

		AddToVec3D(v_movement, q_newDirection.vecPart);
	}

	if (GetKey(olc::Key::S).bHeld)
	{
		Quaternion q_newDirection = QuaternionMultiplication(*q_rotation, { 0, { 0, 0, -1 } }, QuaternionConjugate(*q_rotation));

		if (Options::mcControls)
		{
			q_newDirection.vecPart.y = 0;
		}

		NormalizeVec3D(&q_newDirection.vecPart);
		ScaleVec3D(&q_newDirection.vecPart, movementSpeed);

		AddToVec3D(v_movement, q_newDirection.vecPart);
	}

	if (GetKey(olc::Key::D).bHeld)
	{
		Quaternion q_newDirection = QuaternionMultiplication(*q_rotation, { 0, { 1, 0, 0 } }, QuaternionConjugate(*q_rotation));

		if (Options::mcControls)
		{
			q_newDirection.vecPart.y = 0;
		}

		NormalizeVec3D(&q_newDirection.vecPart);
		ScaleVec3D(&q_newDirection.vecPart, movementSpeed);

		AddToVec3D(v_movement, q_newDirection.vecPart);
	}

	if (GetKey(olc::Key::SPACE).bHeld)
	{
		v_movement->y += movementSpeed;
	}

	if (GetKey(olc::Key::SHIFT).bHeld)
	{
		v_movement->y -= movementSpeed;
	}

	// Rotation

	if (GetKey(olc::Key::RIGHT).bHeld)
	{
		NormalizeQuaternion(q_rotation);

		Quaternion q_newRotationAxis = QuaternionMultiplication(QuaternionConjugate(*q_rotation), { 0, { 0, 1, 0 } }, *q_rotation);

		Quaternion rotationQuaternion = CreateRotationQuaternion(q_newRotationAxis.vecPart, rotationSpeed);

		*q_rotation = QuaternionMultiplication(*q_rotation, rotationQuaternion);
	}

	if (GetKey(olc::Key::LEFT).bHeld)
	{
		NormalizeQuaternion(q_rotation);

		Quaternion q_newRotationAxis = QuaternionMultiplication(QuaternionConjugate(*q_rotation), { 0, { 0, 1, 0 } }, *q_rotation);

		Quaternion rotationQuaternion = CreateRotationQuaternion(q_newRotationAxis.vecPart, -rotationSpeed);

		*q_rotation = QuaternionMultiplication(*q_rotation, rotationQuaternion);
	}

	if (GetKey(olc::Key::UP).bHeld)
	{
		NormalizeQuaternion(q_rotation);

		Quaternion rotationQuaternion = CreateRotationQuaternion({ 1, 0, 0 }, -rotationSpeed);

		*q_rotation = QuaternionMultiplication(*q_rotation, rotationQuaternion);
	}

	if (GetKey(olc::Key::DOWN).bHeld)
	{
		NormalizeQuaternion(q_rotation);

		Quaternion rotationQuaternion = CreateRotationQuaternion({ 1, 0, 0 }, rotationSpeed);

		*q_rotation = QuaternionMultiplication(*q_rotation, rotationQuaternion);
	}

#ifdef RASTERIZER
	// Offset every triangle in opposite direction of player's movement
	for (int i = 0; i < g_triangles.size(); i++)
	{
		for (int j = 0; j < 3; j++)
		{
			SubtractFromVec3D(&g_triangles[i].vertices[j], v_worldMovement);
		}
	}
#endif
}