#pragma once
#include "olcPixelGameEngine.h"

void Engine::Controlls(float fElapsedTime)
{
	float movementSpeed = 7 * fElapsedTime;
	float rotationSpeed = 2.5 * fElapsedTime;

	// Movement

	if (GetKey(olc::Key::W).bHeld)
	{
		Quaternion q_newDirection = QuaternionMultiplication(g_player.q_orientation, { 0, { 0, 0, 1 } }, QuaternionConjugate(g_player.q_orientation));

		if (Options::mcControls)
		{
			q_newDirection.vecPart.y = 0;
		}

		NormalizeVec3D(&q_newDirection.vecPart);
		ScaleVec3D(&q_newDirection.vecPart, movementSpeed);

		AddToVec3D(&g_player.coords, q_newDirection.vecPart);
	}

	if (GetKey(olc::Key::A).bHeld)
	{
		Quaternion q_newDirection = QuaternionMultiplication(g_player.q_orientation, { 0, { -1, 0, 0 } }, QuaternionConjugate(g_player.q_orientation));

		if (Options::mcControls)
		{
			q_newDirection.vecPart.y = 0;
		}

		NormalizeVec3D(&q_newDirection.vecPart);
		ScaleVec3D(&q_newDirection.vecPart, movementSpeed);

		AddToVec3D(&g_player.coords, q_newDirection.vecPart);
	}

	if (GetKey(olc::Key::S).bHeld)
	{
		Quaternion q_newDirection = QuaternionMultiplication(g_player.q_orientation, { 0, { 0, 0, -1 } }, QuaternionConjugate(g_player.q_orientation));

		if (Options::mcControls)
		{
			q_newDirection.vecPart.y = 0;
		}

		NormalizeVec3D(&q_newDirection.vecPart);
		ScaleVec3D(&q_newDirection.vecPart, movementSpeed);

		AddToVec3D(&g_player.coords, q_newDirection.vecPart);
	}

	if (GetKey(olc::Key::D).bHeld)
	{
		Quaternion q_newDirection = QuaternionMultiplication(g_player.q_orientation, { 0, { 1, 0, 0 } }, QuaternionConjugate(g_player.q_orientation));

		if (Options::mcControls)
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

		Quaternion q_newRotationAxis = QuaternionMultiplication(QuaternionConjugate(g_player.q_orientation), { 0, { 0, 1, 0 } }, g_player.q_orientation);

		Quaternion rotationQuaternion = CreateRotationQuaternion(q_newRotationAxis.vecPart, rotationSpeed);

		g_player.q_orientation = QuaternionMultiplication(g_player.q_orientation, rotationQuaternion);
	}

	if (GetKey(olc::Key::LEFT).bHeld)
	{
		NormalizeQuaternion(&g_player.q_orientation);

		Quaternion q_newRotationAxis = QuaternionMultiplication(QuaternionConjugate(g_player.q_orientation), { 0, { 0, 1, 0 } }, g_player.q_orientation);

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