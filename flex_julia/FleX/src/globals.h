#pragma once
#include "../external/SDL2-2.0.4/include/SDL.h"


/* Note that this array of colors is altered by demo code, and is also read from global by graphics API impls */
Colour g_colors[] =
{
	Colour(0.0f, 0.5f, 1.0f),				// cyan
	Colour(0.797f, 0.354f, 0.000f),	// gold
	Colour(0.092f, 0.465f, 0.820f), // cyan
	Colour(0.000f, 0.349f, 0.173f), // moss green
	Colour(0.875f, 0.782f, 0.051f), // yellow
	Colour(0.000f, 0.170f, 0.453f), // navy blue
	Colour(0.673f, 0.111f, 0.000f), // orange
	Colour(0.612f, 0.194f, 0.394f), // orchid
	// custom
};


class Scene;
vector<Scene*> g_scenes;
int g_scene = 0;
char g_curScene[10] ="wind";

Vec3 g_sceneLower;
Vec3 g_sceneUpper;
Vec3 g_shapeLower;
Vec3 g_shapeUpper;


// mapping of collision mesh to render mesh
std::map<NvFlexConvexMeshId, GpuMesh*> g_convexes;
std::map<NvFlexTriangleMeshId, GpuMesh*> g_meshes;
std::map<NvFlexDistanceFieldId, GpuMesh*> g_fields;

// mesh used for deformable object rendering
Mesh* g_mesh;
vector<int> g_meshSkinIndices;
vector<float> g_meshSkinWeights;
vector<Point3> g_meshRestPositions;
const int g_numSkinWeights = 4;


// -------- FleX -------- //
#include "physics.h"

int g_numSubsteps = 5;
SimBuffers* g_buffers;

NvFlexSolver* g_solver;
NvFlexSolverDesc g_solverDesc;
NvFlexLibrary* g_flexLib;
NvFlexParams g_params = {0};

// a setting of -1 means Flex will use the device specified in the NVIDIA control panel
int g_device = -1;
char g_deviceName[256];


// ------- Profiling ------- //
float g_waitTime;		// the CPU time spent waiting for the GPU
float g_updateTime;     // the CPU time spent on Flex
float g_renderTime;		// the CPU time spent calling OpenGL to render the scene
                        // the above times don't include waiting for vsync
float g_simLatency;     // the time the GPU spent between the first and last NvFlexUpdateSolver() operation. Because some GPUs context switch, this can include graphics time.
bool g_profile = false;

NvFlexTimers g_timers;
int g_numDetailTimers;
NvFlexDetailTimer * g_detailTimers;

bool g_hasGround = true;


// ----- For wind scene only ////

float wind_t_frame_x = 0.0f;
float wind_t_frame_y = 0.0f;
float wind_t_frame_z = 0.0f;
float wind_t_plus_1_frame_x = 0.0f;
float wind_t_plus_1_frame_y = 0.0f;
float wind_t_plus_1_frame_z = 0.0f;


// ------- Sim State ------- //
int g_frame = 0;
bool g_pause = false;
bool g_step = false;
bool g_debug = false;
bool g_verbose = false;
bool g_quit = false;
bool g_Error = false;



// ----- Cloth  ----- //

// Cloth particles properties
int g_clothNumParticles = 210;
float g_particleRadius = 0.0078;
float g_clothLift = -1.0;
float g_clothStiffness = -1.0;
float g_clothDrag = -1.0;
float g_clothFriction = -1.0;
float g_dynamicFriction = -1.0;
float g_staticFriction = -1.0;


// Random cloth properties (note that the particle size will be chosen automatically depending on the randomly-sampled cloth particle numbers)
int g_randomSeed = -1;
int g_randomClothMinRes = 145;
int g_randomClothMaxRes = 215;


float g_windTime = 0.0f;
float g_windFrequency = 0.1f;
float g_windStrength = 0.0f;

float g_waveTime = 0.0f;
bool g_wavePool = false;
float g_wavePlane;
float g_waveFrequency = 1.5f;
float g_waveAmplitude = 1.0f;
float g_waveFloorTilt = 0.0f;


float g_dt = 1.0f / 60.0f;	// the time delta used for simulation
float g_realdt;				// the real world time delta between updates

bool g_extensions = true; // Enable or disable NVIDIA/AMD extensions in DirectX


int g_maxDiffuseParticles;
unsigned char g_maxNeighborsPerParticle;
int g_numExtraParticles;
int g_numExtraMultiplier = 1;


// flag to request collision shapes be updated
bool g_shapesChanged = false;


// ----- Export  ----- //
bool g_exportObjs = true;
bool g_saveClothPerSimStep = true;
bool g_exportObjsFlag = false;
char g_exportBase[200] = "out";


bool g_emit = false;
bool g_warmup = false;



// ------------------------------------------------------------------------------------------- //
// ------------------------------------   Functions  ----------------------------------------- //
// ------------------------------------------------------------------------------------------- //
void Init();


void ErrorCallback(NvFlexErrorSeverity severity, const char* msg, const char* file, int line)
{
    printf("Flex: %s - %s:%d\n", msg, file, line);
    g_Error = (severity == eNvFlexLogError);
}



bool exists(const char* p, bool verbose=false) {
    FILE *f = fopen(p, "r");
    if (f) {
        fclose(f);
        return true;
    } else {
        if (verbose) {
            fprintf(stderr, "Error: %s does not exist.\n", p);
        }
        return false;
    }
}


float sqr(float x) { return x*x; }



void PrintSimParams()
{
    printf("\n ---- Simulation Params ----\n");
    printf("substeps:                  %d\n", g_numSubsteps);
    printf("radius:                    %f\n", g_params.radius);
    printf("num_planes:                %d\n", g_params.numPlanes);
    printf("iterations:                %d\n", g_params.numIterations);
    printf("restitution:               %f\n", g_params.restitution);
    printf("dissipation:               %f\n", g_params.dissipation);
    printf("damping:                   %f\n", g_params.damping);
    printf("drag:                      %f\n", g_params.drag);
    printf("lift:                      %f\n", g_params.lift);
    printf("dynamic_friction:          %f\n", g_params.dynamicFriction);
    printf("static_friction:           %f\n", g_params.staticFriction);
    printf("particle_friction:         %f\n", g_params.particleFriction);
    printf("collision_distance:        %f\n", g_params.collisionDistance);
    printf("shape_collision_margin:    %f\n", g_params.shapeCollisionMargin);
    printf("particle_collision_margin: %f\n", g_params.particleCollisionMargin);
    printf("relaxation_factor:         %f\n", g_params.relaxationFactor);
    printf("relaxation_mode:           %d\n", g_params.relaxationMode);
    printf("viscosity:                 %f\n", g_params.viscosity);
    printf("saveClothPerSimStep:       %d\n", g_saveClothPerSimStep);
    printf("\n");
    printf("\n ---------------------------\n");
}

