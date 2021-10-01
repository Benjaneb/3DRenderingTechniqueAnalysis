#pragma once
#include <fstream>

// material information about a specific part of a mesh. For example, the legs of a chair
struct MeshPart
{
	Material material;
	std::string name;
	olc::Sprite* normalMap = nullptr;
};

std::mutex trianglesMutex;

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

void ParseMTL(std::string objPath, std::string mtlName, std::vector<Triangle>* scene, std::vector<MeshPart> meshParts)
{
	// Use same file path for MTL-file but without the file name of the OBJ-file
	std::vector<std::string> splitPath = split(objPath, '/');
	splitPath.pop_back();
	std::string assetsPath;
	for (std::string s : splitPath)
	{
		assetsPath += s + '/';
	}
	std::string mtlPath = assetsPath + mtlName;

	// Start opening file
	std::ifstream file;
	file.open(mtlPath, std::ios::in);

	if (!file.is_open()) // If file opening failed
	{
		std::cout << "Could not find MTL-file in same folder as OBJ-file located in: " << mtlPath << std::endl;
		return;
	}

	std::string line;

	while (true)
	{
		std::string meshPartName;
		Vec3D tint;
		olc::Sprite* texture;

		while (getline(file, line)) // Jumps to new line every loop
		{
			if (line != "")
			{
				std::vector<std::string> values = split(line, ' ');

				if (values[0] == "Ka") // Tint
				{
					tint = { stof(values[1]), stof(values[2]), stof(values[3]) };
				}
				if (values[0] == "map_Kd") // Texture
				{
					texture = new olc::Sprite(assetsPath + values[1]);
				}
				else if (values[0] == "newmtl") // New group
				{
					if (meshPartName != "") // Go back to previous line and break if it reaches a new group while already parsing one
					{
						file.seekg(-1, std::ios::cur);
						break;
					}

					meshPartName = values[1];
				}
			}
		}

		MeshPart meshPart;

		for (int i = 0; i < meshParts.size(); i++)
		{
			if (meshParts[i].name == meshPartName)
			{
				meshPart = meshParts[i];
			}
		}

		// Goes through every triangle and adds the material data if they belonged in the group
		for (int i = 0; i < scene->size(); i++)
		{
			if (scene->at(i).meshPartName == meshPartName)
			{
				scene->at(i).tint = tint;
				scene->at(i).texture = texture;
				scene->at(i).material = meshPart.material;
				scene->at(i).normalMap = meshPart.normalMap;
			}
		}

		if (file.eof()) break;
	}
}

void ImportScene(std::vector<Triangle>* triangles, std::string filePath, std::vector<MeshPart> meshParts, Vec3D v_displacement = ZERO_VEC3D, float scale = 1)
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
	//std::vector<Vec3D> normals;

	std::string mtlName;
	std::string meshPartName;

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
			/*else if (values[0] == "vn") // Normal
			{
				normals.push_back({ stof(values[1]), stof(values[2]), stof(values[3]) });
			}*/
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
					scene.push_back(
					{
						{ 
							{ AddVec3D(VecScalarMultiplication3D(vertices[stof(vertex1[0]) - 1], scale), v_displacement) },
							{ AddVec3D(VecScalarMultiplication3D(vertices[stof(vertex2[0]) - 1], scale), v_displacement) },
							{ AddVec3D(VecScalarMultiplication3D(vertices[stof(vertex3[0]) - 1], scale), v_displacement) }
						}, // Vertices
						{ 1, 1, 1 }, // tint
						STANDARD_MATERIAL, // Material data
						meshPartName,
					});
				else
					scene.push_back(
					{
						{
							{ AddVec3D(VecScalarMultiplication3D(vertices[stof(vertex1[0]) - 1], scale), v_displacement) },
							{ AddVec3D(VecScalarMultiplication3D(vertices[stof(vertex2[0]) - 1], scale), v_displacement) },
							{ AddVec3D(VecScalarMultiplication3D(vertices[stof(vertex3[0]) - 1], scale), v_displacement) }
						}, // Vertices
						{ 1, 1, 1 }, // tint
						STANDARD_MATERIAL, // Material data
						meshPartName,
						nullptr, // Texture, set to nullptr for now
						{ { textureCoords[stof(vertex1[1]) - 1] }, { textureCoords[stof(vertex2[1]) - 1] }, { textureCoords[stof(vertex3[1]) - 1] } }, // Texture vertices
						nullptr, // Normal map, set to nullptr for now
						{ { textureCoords[stof(vertex1[1]) - 1] }, { textureCoords[stof(vertex2[1]) - 1] }, { textureCoords[stof(vertex3[1]) - 1] } } // Normal map vertices
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
				meshPartName = values[1];
			}
		}
	}

	file.close();

	ParseMTL(filePath, mtlName, &scene, meshParts);

	std::lock_guard<std::mutex> lock(trianglesMutex);

	triangles->insert(triangles->end(), scene.begin(), scene.end());
}