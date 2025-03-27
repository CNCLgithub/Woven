#include <iostream>
#include <fstream>
#include <sstream>
#include <string>
#include <vector>
#pragma once


class RotateTable : public Scene
{
public:
    RotateTable(const char* name, const char* objpath, const char* inputpath, int input_t_frame, ClothParams cp, ObjParams op):
        Scene(name), objpath(objpath), inputpath(inputpath), input_t_frame(input_t_frame), cp(cp), op(op) {}

    virtual void Initialize()
    {
        PrintProperties(cp);
        PrintProperties(op);
        mTime = input_t_frame * 1.0f/60.0f;

        obj = ImportMesh(GetFilePathByPlatform(objpath).c_str());

        Vec3 obj_lower, obj_upper;
        obj->GetBounds(obj_lower, obj_upper);
        NvFlexTriangleMeshId mesh = CreateTriangleMesh(obj);
        AddTriangleMesh(mesh, Vec3(), Quat(), 1.0f);
        
        int phase = NvFlexMakePhase(0, eNvFlexPhaseSelfCollide);
        string line;
        char c;
        int i, j, k;
        double x, y, z;
        string si, sj, sk;

        ifstream in( GetFilePathByPlatform(inputpath).c_str() );
        while ( getline( in, line ) ) {
            istringstream ss( line );
            ss >> c;
            switch ( c ) {
                case 'v':
                case 'V':
                    ss >> x >> y >> z;
                    g_buffers->positions.push_back(Vec4(x, y, z, cp.invMass));
                    g_buffers->phases.push_back(phase);
                    break;
                case 'f':
                case 'F':
                    ss >> si >> sj >> sk;
                    i = stoi(si);  j = stoi(sj);  k = stoi( sk );
                    g_buffers->triangles.push_back(i-1);
                    g_buffers->triangles.push_back(j-1);
                    g_buffers->triangles.push_back(k-1);
                    break;
                case 's':
                case 'S':
                    ss >> x >> y >> z;
                    g_buffers->velocities.push_back(Vec3(x, y, z));
                    break;    
                case 'i':
                case 'I':
                    ss >> si;
                    i = stoi(si);
                    g_buffers->springIndices.push_back(i);
                    break;   
                case 'l':
                case 'L':
                    ss >> x;
                    g_buffers->springLengths.push_back(x);
                    g_buffers->springStiffness.push_back(cp.bend_stiffness);
                    break;             
          }
       }

       in.close();

        g_params.radius = cp.particle_radius*1.0f;
        g_windStrength = 0.0f;
        g_shapesChanged = true;
        g_params.collisionDistance = 1.0f*cp.particle_radius;
    }


    void Export(const char* basename) {

        char clothPath[400];
        if (g_saveClothPerSimStep) {
            sprintf(clothPath, "%s_cloth_%d.obj", basename, g_frame);


            if (g_verbose == true) {
                if (g_frame % 40 == 0) {
                    printf("Exporting cloth to %s\n", clothPath);
                }
            }
        }

        ofstream obj_file;
        obj_file.open(clothPath);

        if (!obj_file) {
            printf("Failed to write to %s\n", clothPath);
            exit(-1);
        }

        char line[300];

        auto& particles = g_buffers->positions;
        obj_file << "# Vertices\n";
        obj_file << "o cloth\n";
        for (int i = 0; i < g_buffers->positions.size(); i++)
        {
            sprintf(line, "v %f %f %f\n", particles[i].x, particles[i].y, particles[i].z);
            obj_file << line;
        }

        auto& tris = g_buffers->triangles;
        obj_file << "\n# Faces\n";
        for (int i = 0; i < tris.size()/3; i++)
        {
            sprintf(line, "f %d %d %d\n", tris[i*3+0]+1, tris[i*3+1]+1, tris[i*3+2]+1);
            obj_file << line;
        }

        auto& velocities = g_buffers->velocities;
        obj_file << "# Velocities\n";
        for (int i = 0; i < g_buffers->velocities.size(); i++)
        {
          sprintf(line, "s %f %f %f\n", velocities[i].x, velocities[i].y, velocities[i].z);
          obj_file << line;
        }

        obj_file.close();
    }

    void Update() {
        mTime += g_dt;

        float startTime = 1.0f;
        float thistime = Max(0.0f, mTime-startTime);
        float lastTime = Max(0.0f, thistime-g_dt);

        const float rotationSpeed = 1.0f;
        Quat rot = QuatFromAxisAngle(Vec3(0.0f, 1.0f, 0.0f), kPi*(1.0f-cosf(rotationSpeed*thistime))/1.5f);
        Quat prevRot = QuatFromAxisAngle(Vec3(0.0f, 1.0f, 0.0f), kPi*(1.0f-cosf(rotationSpeed*lastTime))/1.5f);
        
        g_buffers->shapeRotations[0] = rot;        
        g_buffers->shapePrevRotations[0] = prevRot;

        return ;
    }


private:
    const char* objpath;
    const char* inputpath;
    int input_t_frame;
    ClothParams cp;
    ObjParams op;
    Mesh* obj;
    float mTime;
    int cloth_base_idx;
    int nx, ny;
};
