#pragma once
#include <fstream>
#include "WorldDatatypes.h"

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

void ParseMTL(std::string filePath, std::string mtlName, std::vector<Triangle>* scene)
{
	// Use same file path for MTL-file but without the file name of the OBJ-file
	std::vector<std::string> splitPath = split(filePath, '/');
	splitPath.pop_back();
	std::string newFilePath;
	for (std::string s : splitPath)
	{
		newFilePath += s + '/';
	}
	newFilePath += mtlName;

	// Start opening file
	std::ifstream file;
	file.open(filePath, std::ios::in);

	if (!file.is_open()) // If file opening failed
	{
		std::cout << "Could not find MTL-file in same folder as OBJ-file located in: " << filePath << std::endl;
		return;
	}

	std::string line;

	while (true)
	{
		std::string materialName;
		Vec3D tint;

		while (getline(file, line)) // Jumps to new line every loop
		{
			if (line != "")
			{
				std::vector<std::string> values = split(line, ' ');

				if (values[0] == "Ka") // Tint
				{
					tint = { stof(values[1]), stof(values[2]), stof(values[3]) };
				}
				else if (values[0] == "newmtl") // New group
				{
					if (materialName != "") // Go back to previous line and break if it reaches a new group while already parsing one
					{
						file.seekg(-1, std::ios::cur);
						break;
					}

					materialName = values[1];
				}
			}
		}

		// Goes through every triangle and adds the material data if they belonged in the group
		for (Triangle t : *scene)
		{
			if (t.material.name == materialName)
			{
				t.material.tint = tint;
			}
		}

		if (file.eof()) break;
	}
}

void ImportScene(std::vector<Triangle>* triangles, std::string filePath, float scale = 1, Vec3D v_displacement = { 0, 0, 0 }, olc::Sprite* texture = nullptr)
{
	std::ifstream file;
	file.open(filePath, std::ios::in);

	if (!file.is_open()) // If file opening failed
	{
		std::cout << "Could not find scene in: " << filePath << std::endl;
		return;
	}

	std::string line;
	std::vector<Triangle> scene;

	std::vector<Vec3D> vertices;
	std::vector<Vec2D> textureCoords;
	std::vector<Vec3D> normals;

	std::string mtlName;
	std::string materialName;

	// Gather coordinate data
	while (getline(file, line)) // Jumps to new line every loop
	{
		if (line != "")
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
#ifdef RAY_TRACER
				// Ray tracer
				if (vertex1.size() == 1) // Check if triangle has texture coordinates
					scene.push_back({
						{ { vertices[stof(vertex1[0]) - 1] }, { vertices[stof(vertex2[0]) - 1] }, { vertices[stof(vertex3[0]) - 1] } }, // Vertices
						{ { 1, 1, 1 }, 0.1, 0.4, materialName } // Material data
					});
				else
					scene.push_back({
						{ { VecScalarMultiplication3D(vertices[stof(vertex1[0]) - 1], scale) }, { VecScalarMultiplication3D(vertices[stof(vertex2[0]) - 1], scale) }, { VecScalarMultiplication3D(vertices[stof(vertex3[0]) - 1], scale) } }, // Vertices
						{ { 1, 1, 1 }, 0.1, 0.4, materialName }, texture, // Material data
						{ { textureCoords[stof(vertex1[1]) - 1] }, { textureCoords[stof(vertex2[1]) - 1] }, { textureCoords[stof(vertex3[1]) - 1] } } // Texture coordinates
					});
#else
				// Rasterizer
				if (vertex1.size() == 1) // Check if triangle has texture coordinates
					scene.push_back({
						{ { vertices[stof(vertex1[0]) - 1] }, { vertices[stof(vertex2[0]) - 1] }, { vertices[stof(vertex3[0]) - 1] } } // Vertices
					});
				else
					scene.push_back({
						{ { vertices[stof(vertex1[0]) - 1] }, { vertices[stof(vertex2[0]) - 1] }, { vertices[stof(vertex3[0]) - 1] } }, // Vertices
						{ { textureCoords[stof(vertex1[1]) - 1] }, { textureCoords[stof(vertex2[1]) - 1] }, { textureCoords[stof(vertex3[1]) - 1] } } // Texture coordinates
					});
#endif
			}
			else if (values[0] == "mtllib")
			{
				mtlName = values[1];
			}
			else if (values[0] == "usemtl")
			{
				materialName = values[1];
			}
		}
	}

	file.close();

	ParseMTL(filePath, mtlName, &scene);

	triangles->insert(triangles->end(), scene.begin(), scene.end());
}