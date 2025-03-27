#pragma once
#include <iostream>
#include <fstream>
using namespace std;


class Ball : public Scene {
public:
    Ball(const char* name, const char* objpath, const char* inputpath, int input_t_frame, ClothParams cp, ObjParams op):
        Scene(name), objpath(objpath), inputpath(inputpath), input_t_frame(input_t_frame), cp(cp), op(op) {}

    void Initialize() {

        int group = 0;
        
        slope = ImportMesh(GetFilePathByPlatform("dataset/trialObjs/ball/export_slope.obj").c_str());
        if (! slope) {
            printf("[Error] slope mesh does not exist.\n");
            exit(-1);
        } 
        slope -> GetBounds(slope_lower, slope_upper);
        NvFlexTriangleMeshId mesh_slope = CreateTriangleMesh(slope);
        AddTriangleMesh(mesh_slope, Vec3(), Quat(), 1.0f);

        nx = cp.n_particles;
        ny = cp.n_particles;

        cloth_start_idx = int(g_buffers->positions.size());
        int cloth_phase = NvFlexMakePhase(group, eNvFlexPhaseSelfCollide);

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
                    ss >> x >> y >> z;
                    g_buffers->positions.push_back(Vec4(x, y, z, cp.invMass));
                    g_buffers->phases.push_back(cloth_phase);
                    break;
                case 'n':
                    ss >> x >> y >> z;
                    g_buffers->triangleNormals.push_back(Vec3(x, y, z));
                    break;
                case 'f':
                    ss >> si >> sj >> sk;
                    i = stoi(si);  j = stoi(sj);  k = stoi( sk );
                    g_buffers->triangles.push_back(i-1);
                    g_buffers->triangles.push_back(j-1);
                    g_buffers->triangles.push_back(k-1);
                    break;
                case 's':
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
                    ss >> x >> y;                                  
                    g_buffers->springLengths.push_back(x);
                    if (abs(x-0.02f)<=1e-4 or abs(x-0.04f)<=1e-4 or abs(x-0.08f)<=1e-4 or abs(x-0.028284f)<=1e-4) {
                        g_buffers->springStiffness.push_back(cp.bend_stiffness);
                    } else {
                        g_buffers->springStiffness.push_back(y);
                    }
                    break;
                }
            }

        const int c1 = 0 + cloth_start_idx;
        const int c2 = nx-1 + cloth_start_idx;

        g_buffers->positions[c1].w = 0.0f;
        g_buffers->positions[c2].w = 0.0f;

        obj_start_idx = g_buffers->positions.size();
        int obj_phase;
        obj_phase = NvFlexMakePhase(group++, 0);
        
        if (DetectValidSticky()){
            scene_valid = true;
        }

        std::cout << scene_valid << std::endl;

        if (scene_valid){
            if (g_buffers->rigidIndices.empty()) {
                g_buffers->rigidOffsets.push_back(0);
            }
            ifstream in_object( GetFilePathByPlatform(inputpath).c_str() );

            while ( getline( in_object, line ) ) {
                istringstream ss_object( line );
                ss_object >> c;
                switch ( c ) {
                    case 'V':
                        ss_object >> x >> y >> z;
                        g_buffers->rigidIndices.push_back(int(g_buffers->positions.size()));
                        g_buffers->positions.push_back(Vec4(x, y, z, 0.35f));
                        g_buffers->phases.push_back(obj_phase);
                        break;
                    case 'S':
                        ss_object >> x >> y >> z;
                        g_buffers->velocities.push_back(Vec3(x, y, z));
                        break; 
                    }
                }

            g_buffers->rigidCoefficients.push_back(1.0f);
            g_buffers->rigidOffsets.push_back(int(g_buffers->rigidIndices.size()));
        }

        g_params.staticFriction = 0.4f;
        g_params.dynamicFriction = 0.4f;
        g_params.particleFriction = 1.0f;
        g_params.radius = cp.particle_radius*1.0f;
        g_params.damping = 0.15f;
        g_params.collisionDistance = 1.0f*cp.particle_radius;
        g_params.relaxationFactor = 1.0f;
        g_windStrength = 0.0f;
    }


    void Export(const char* basename) {
        char clothPath[400];
        char line[300];
        ofstream obj_file;

        if (g_saveClothPerSimStep) {
            sprintf(clothPath, "%s_cloth_%d.obj", basename, g_frame);
            if (g_verbose == true && g_frame % 40 == 0) {
                printf("Exporting cloth to %s\n", clothPath);
            }
        }
            
        obj_file.open(clothPath);
        if (!obj_file) {
            printf("Failed to write to %s\n", clothPath);
            exit(-1);
        }
        
        obj_file << "o cloth\n";

        // // ------------------------- 
        auto& particles = g_buffers->positions;
        obj_file << "# Vertices\n";
        for (int i=cloth_start_idx; i<obj_start_idx; i++) {
            sprintf(line, "v %f %f %f\n", particles[i].x, particles[i].y, particles[i].z);
            obj_file << line;
        }
        // // ------------------------- 
        auto& tris = g_buffers->triangles;
        obj_file << "# Faces\n";
        for (int i=0; i<tris.size()/3; i++) {
            sprintf(line, "f %d %d %d\n", tris[i*3+0]+1, tris[i*3+1]+1, tris[i*3+2]+1);
            obj_file << line;
        }
        // // ------------------------- 
        auto& velocities = g_buffers->velocities;
        obj_file << "# Velocities\n";
        for (int i=cloth_start_idx; i<obj_start_idx; i++) {
            sprintf(line, "s %f %f %f\n", velocities[i].x, velocities[i].y, velocities[i].z);
            obj_file << line;
        }
        // // ------------------------- 
        auto& normals = g_buffers->triangleNormals;
        obj_file << "# Normal\n";
        for (int i=0; i<normals.size(); i++) {
            sprintf(line, "n %f %f %f\n", normals[i].x, normals[i].y, normals[i].z);
            obj_file << line;
        }

        if (scene_valid){
            obj_file << "o object\n";
            obj_file << "# Vertices\n";

            for (int i=obj_start_idx; i<g_buffers->positions.size(); i++) {
                sprintf(line, "V %f %f %f\n", particles[i].x, particles[i].y, particles[i].z); 
                obj_file << line;
            }    

            obj_file << "# Velocities\n";
            for (int i=obj_start_idx; i<g_buffers->velocities.size(); i++) {
                sprintf(line, "S %f %f %f\n", velocities[i].x, velocities[i].y, velocities[i].z);
                obj_file << line;
            }
        }

        obj_file.close();
    }


    bool DetectValidSticky() {
        auto& particles = g_buffers->positions;
        float cloth_lowest = FLT_MAX;
        for (int i = 0; i < particles.size(); ++i) {
            auto& p = particles[i];
            cloth_lowest = (p.y < cloth_lowest) ? p.y : cloth_lowest;
        }
               
        if ((slope_lower.y - 0.0f) < cloth_lowest) {
            return true;
        } else {
            return false;
        }
    }


private:
    Mesh* obj;
    Mesh* slope;
    const char* objpath;
    const char* inputpath;
    int input_t_frame;
    ClothParams cp;
    ObjParams op;
    int cloth_start_idx;
    int obj_start_idx;
    int nx, ny;
    float debug_ball_pos = -1.0f;
    float debug_ball_vel = -1.0f;
    Vec3 slope_lower, slope_upper;
    bool scene_valid = false;

};
