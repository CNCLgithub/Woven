#pragma once

class Wind : public Scene {
public:
    Wind(const char* name, const char* objpath, const char* inputpath, int input_t_frame, ClothParams cp, ObjParams op):
        Scene(name), objpath(objpath), inputpath(inputpath), input_t_frame(input_t_frame), cp(cp), op(op) {}

    void Initialize() {
        int group = 0;
        g_windStrength = 0.6f;
        g_params.radius = cp.particle_radius*1.0f;
        mTime = input_t_frame * 1.0f/60.0f;

        g_params.wind[0] = wind_t_frame_x;
        g_params.wind[1] = wind_t_frame_y;
        g_params.wind[2] = wind_t_frame_z;

        nx = cp.n_particles;
        ny = cp.n_particles;

        int phase = NvFlexMakePhase(group++, eNvFlexPhaseSelfCollide);
        cloth_start_idx = int(g_buffers->positions.size());
        
        string line;
        string si, sj, sk;
        char c;
        int i, j, k;
        double x, y, z;

        ifstream in( GetFilePathByPlatform(inputpath).c_str() );
        while ( getline( in, line ) ) {
            istringstream ss( line );
            ss >> c;
            switch ( c ) {
                case 'v':
                    ss >> x >> y >> z;
                    g_buffers->positions.push_back(Vec4(x, y, z, cp.invMass));
                    g_buffers->phases.push_back(phase);
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
        in.close();

        cloth_end_index = int(g_buffers->positions.size());
        cloth_tris = int(g_buffers->triangles.size());

        const int c1 = 0 + cloth_start_idx;
        const int c2 = nx - 1 + cloth_start_idx;

        g_buffers->positions[c1].w = 0.0f;
        g_buffers->positions[c2].w = 0.0f;
    }

    void Update() {
        mTime += g_dt;
        if (g_frame == 0) {
            g_params.wind[0] = wind_t_frame_x;
            g_params.wind[1] = wind_t_frame_y;
            g_params.wind[2] = wind_t_frame_z;
        } else if (g_frame == 1) {
            g_params.wind[0] = wind_t_plus_1_frame_x;
            g_params.wind[1] = wind_t_plus_1_frame_y;
            g_params.wind[2] = wind_t_plus_1_frame_z;
        }
    }


    void Export(const char* basename) {

        char clothPath[400];
        ofstream obj_file;
        char line[300];

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

        auto& particles = g_buffers->positions;

        // // ------------------------- 
        obj_file << "o cloth\n";
        obj_file << "# Vertices\n";
        for (int i=cloth_start_idx; i<cloth_end_index; i++) {
            sprintf(line, "v %f %f %f\n", particles[i].x, particles[i].y, particles[i].z);
            obj_file << line;
        }
        // // ------------------------- 
        auto& tris = g_buffers->triangles;
        obj_file << "# Faces\n";
        for (int i = 0; i < cloth_tris/3; i++) {
            sprintf(line, "f %d %d %d\n", tris[i*3+0]+1, tris[i*3+1]+1, tris[i*3+2]+1);
            obj_file << line;
        }
        // // ------------------------- 
        auto& velocities = g_buffers->velocities;
        obj_file << "# Velocities\n";
        for (int i=cloth_start_idx; i < cloth_end_index; i++) {
            sprintf(line, "s %f %f %f\n", velocities[i].x, velocities[i].y, velocities[i].z);
            obj_file << line;
        }

        obj_file.close();
    }


private:
    const char* objpath;
    const char* inputpath;
    int input_t_frame;
    ClothParams cp;
    ObjParams op;
    Mesh* obj;
    double mTime;
    Vec3 obj_lower;
    int flag = 0;
    int cloth_start_idx;
    int cloth_end_index;
    int cloth_tris;
    int nx, ny;
};
