#pragma once
#include <fstream>
#include "WorldDatatypes.h"

std::vector<Triangle> ParseOBJ(std::string filePath)
{
	std::ifstream file;
	file.open(filePath, std::ios::in);

	if (!file) // If file opening failed
	{
		std::cout << "Did not find scene in " << filePath << std::endl;
		return;
	}

	std::string line;
	std::vector<Triangle> scene;

	std::vector<Vec3D> vertices;
	std::vector<Vec2D> textureCoords;
	std::vector<Vec3D> normals;

	// Gather coordinate data
	while (getline(file, line)) // Jumps to new line every loop
	{
		std::vector<std::string> values = split(line, ' ');

		if (values[0] == "v") // Vertex
		{
			vertices.push_back({ stof(values[1]), stof(values[2]), stof(values[3]) });
		}
		else if (values[0] == "vt") // Texture coordinate
		{
			textureCoords.push_back({ stof(values[1]), stof(values[2]) });
		}
		else if (values[0] == "vn") // Normal
		{
			normals.push_back({ stof(values[1]), stof(values[2]), stof(values[3]) });
		}
		else if (values[0] == "f") // Indicies of vertex info
		{
			std::vector<std::string> values = split(line, ' ');
			std::vector<std::string> vertex1 = split(values[1], '/');
			std::vector<std::string> vertex2 = split(values[2], '/');
			std::vector<std::string> vertex3 = split(values[3], '/');

			// Add new triangle with vertex and texture coordinates
			if (vertex1.size == 1) // Check if triangle has texture coordinates
				scene.push_back({
					{ { vertices[stof(vertex1[0]) - 1] }, { vertices[stof(vertex2[0]) - 1] }, { vertices[stof(vertex3[0]) - 1] } } // Vertices
				});
			else
				scene.push_back({
					{ { vertices[stof(vertex1[0]) - 1] }, { vertices[stof(vertex2[0]) - 1] }, { vertices[stof(vertex3[0]) - 1] } }, // Vertices
					{ { textureCoords[stof(vertex1[1]) - 1] }, { textureCoords[stof(vertex2[1]) - 1] }, { textureCoords[stof(vertex3[1]) - 1] } } // Texture coordinates
				});
		}
	}

	file.close();

	return scene;
}

std::vector<std::string> split(const std::string& s, char delimiter)
{
	std::vector<std::string> tokens;
	std::string token;
	std::istringstream tokenStream(s);

	while (getline(tokenStream, token, delimiter))
	{
		tokens.push_back(token);
	}

	return tokens;
}