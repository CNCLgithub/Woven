#include "../core/types.h"
#include "../core/maths.h"
#include "../core/platform.h"
#include "../core/mesh.h"
#include "../core/voxelize.h"
#include "../core/sdf.h"
#include "../core/pfm.h"
#include "../core/tga.h"
#include "../core/perlin.h"
#include "../core/convex.h"
#include "../core/cloth.h"
#include "../external/SDL2-2.0.4/include/SDL.h"
#include <yaml-cpp/yaml.h>
#include "../include/NvFlex.h"
#include "../include/NvFlexExt.h"
#include "../include/NvFlexDevice.h"

#include <iostream>
#include <fstream>
#include <map>
#include <random>

#include "shaders.h"
#include "imgui.h"
#include <boost/algorithm/string.hpp>

using namespace std;

#include "globals.h"
#include "helpers.h"
#include "scenes.h"




void ParseConfig(const char* path, int& n_iters, Scene::ClothParams& cp, Scene::ObjParams& op) 
{
    typedef YAML::Node Node;
    using YAML::LoadFile;

    Node config;
    int randSeedNum;
    float epsilon=1e-20;
    float defaultValue=-1.0f;

    try {
        config = LoadFile(path);
    } catch (YAML::BadFile) {
        cerr << "Error: Improperly formatted YAML config." << endl;
        exit(-1);
    }

    if (config["steps"]) { 
        n_iters = config["steps"].as<int>();
    }

    if (config["substeps"]) {
        g_numSubsteps = config["substeps"].as<int>(g_numSubsteps);
    } else {
        g_numSubsteps = 7;
    }

    if (config["subiters"]) {
        g_params.numIterations = config["subiters"].as<int>(g_params.numIterations);
    }

    if (config["restitution"]) {
        g_params.restitution = config["restitution"].as<float>(g_params.restitution);
    }

    if (config["dissipation"]) {
        g_params.dissipation = config["dissipation"].as<float>(g_params.dissipation);
    }

    if (config["damping"]) {
        g_params.damping = config["damping"].as<float>(g_params.damping);
    }

    if (config["coll_distance"]) {
        g_params.collisionDistance = config["coll_distance"].as<float>(g_params.collisionDistance);
    }

    if (config["shape_coll_margin"]) {
        g_params.shapeCollisionMargin = config["shape_coll_margin"].as<float>(g_params.shapeCollisionMargin);
    }

    if (config["particle_coll_margin"]) { 
        g_params.particleCollisionMargin = config["particle_coll_margin"].as<float>(g_params.particleCollisionMargin);
    }
    

    if (config["extra_cp_spacing"]) {
        cp.extra_cp_spacing = config["extra_cp_spacing"].as<float>(cp.extra_cp_spacing);
    }

    if (config["extra_cp_rad_mult"]) {
        cp.extra_cp_rad_mult = config["extra_cp_rad_mult"].as<float>(cp.extra_cp_rad_mult);
    }

    if (abs(g_dynamicFriction-defaultValue) > epsilon) {
        g_params.dynamicFriction = g_dynamicFriction;
    } else if (config["dynamic_friction"]) {
        g_params.dynamicFriction = config["dynamic_friction"].as<float>(g_params.dynamicFriction);
    }

    if (abs(g_staticFriction-defaultValue) > epsilon) {
        g_params.staticFriction = g_staticFriction;
    } else if (config["static_friction"]) {
        g_params.staticFriction = config["static_friction"].as<float>(g_params.staticFriction);
    }

    if (abs(g_clothDrag-defaultValue) > epsilon) {
        g_params.drag = g_clothDrag;
    } else if (config["drag"]) {
        g_params.drag = config["drag"].as<float>(g_params.drag);
    } else {
        g_params.drag = 0.1f;
    }

    if (abs(g_clothLift-defaultValue) > epsilon) {
        g_params.lift = g_clothLift;
    } else if (config["lift"]) {
        g_params.lift = config["lift"].as<float>(g_params.lift);
    } else {
        g_params.lift = 0.1f;
    }

    if (cp.n_particles <= 0) {
        if (config["n_particles"]) {
            cp.n_particles = config["n_particles"].as<float>(cp.n_particles);
        } else {
            if (g_randomSeed != -1) {
                randSeedNum = g_randomSeed;
            } else {
                random_device rd;
                randSeedNum = rd();
            }

            mt19937 gen(randSeedNum);
            uniform_int_distribution<> dis(g_randomClothMinRes, g_randomClothMaxRes);
            cp.n_particles = dis(gen);
            cp.particle_radius = cp.particle_radius * (1.0+(1.0-(float(pow(cp.n_particles, 2.2))/float(pow(g_clothNumParticles, 2.2)))));
        }
    }
}



void InitSim() {
    NvFlexInitDesc desc;
    desc.deviceIndex = g_device;
    desc.enableExtensions = g_extensions;
    desc.renderDevice = 0;
    desc.renderContext = 0;
    desc.computeContext = 0;
    desc.computeType = eNvFlexCUDA;

    g_flexLib = NvFlexInit(NV_FLEX_VERSION, ErrorCallback, &desc);

    if (g_Error || g_flexLib == NULL) {
        printf("Could not initialize Flex, exiting.\n");
        exit(-1);
    }

    strcpy(g_deviceName, NvFlexGetDeviceName(g_flexLib));
}



void Shutdown() {
    
    DestroyBuffers(g_buffers);

    for (auto& iter : g_meshes) {
        NvFlexDestroyTriangleMesh(g_flexLib, iter.first);

        if (iter.second) {
            DestroyGpuMesh(iter.second);
        }
    }

    for (auto& iter : g_fields) {
        NvFlexDestroyDistanceField(g_flexLib, iter.first);

        if (iter.second){
            DestroyGpuMesh(iter.second);
        }
    }

    for (auto& iter : g_convexes) {
        NvFlexDestroyConvexMesh(g_flexLib, iter.first);

        if (iter.second){
            DestroyGpuMesh(iter.second);
        }
    }

    g_fields.clear();
    g_meshes.clear();
    g_convexes.clear();

    NvFlexDestroySolver(g_solver);
    NvFlexShutdown(g_flexLib);

    for (auto& s : g_scenes) {
        s->Destroy();
    }
}



void ResetSimGlobals() {

    if (g_buffers) {
        DestroyBuffers(g_buffers);
    }

    g_buffers = AllocBuffers(g_flexLib);

    MapBuffers(g_buffers);

    g_buffers->positions.resize(0);
    g_buffers->velocities.resize(0);
    g_buffers->phases.resize(0);

    g_buffers->rigidOffsets.resize(0);
    g_buffers->rigidIndices.resize(0);
    g_buffers->rigidMeshSize.resize(0);
    g_buffers->rigidRotations.resize(0);
    g_buffers->rigidTranslations.resize(0);
    g_buffers->rigidCoefficients.resize(0);
    g_buffers->rigidPlasticThresholds.resize(0);
    g_buffers->rigidPlasticCreeps.resize(0);
    g_buffers->rigidLocalPositions.resize(0);
    g_buffers->rigidLocalNormals.resize(0);

    g_buffers->springIndices.resize(0);
    g_buffers->springLengths.resize(0);
    g_buffers->springStiffness.resize(0);
    g_buffers->triangles.resize(0);
    g_buffers->triangleNormals.resize(0);
    g_buffers->uvs.resize(0);

    g_meshSkinIndices.resize(0);
    g_meshSkinWeights.resize(0);

    g_buffers->shapeGeometry.resize(0);
    g_buffers->shapePositions.resize(0);
    g_buffers->shapeRotations.resize(0);
    g_buffers->shapePrevPositions.resize(0);
    g_buffers->shapePrevRotations.resize(0);
    g_buffers->shapeFlags.resize(0);

    // remove collision shapes
    delete g_mesh; g_mesh = NULL;

 
    g_frame = 0;
    g_pause = false;

    g_dt = 1.0f / 60.0f;
    g_waveTime = 0.0f;
    g_windTime = 0.0f;
    g_windStrength = 0.0f;
    g_windFrequency = 0.1*(1.0f/g_dt);


    g_params.gravity[0] = 0.0f;
    g_params.gravity[1] = -9.8f;
    g_params.gravity[2] = 0.0f;
    g_params.radius = 0.15f;
    g_params.viscosity = 0.0f;
    g_params.freeSurfaceDrag = 0.0f;
    g_params.fluidRestDistance = 0.0f;
    g_params.solidRestDistance = 0.0f;
    g_params.anisotropyScale = 1.0f;
    g_params.anisotropyMin = 0.1f;
    g_params.anisotropyMax = 2.0f;
    g_params.smoothing = 1.0f;
    g_params.sleepThreshold = 0.0f;
    g_params.shockPropagation = 0.0f;
    g_params.maxSpeed = FLT_MAX;
    g_params.maxAcceleration = 100.0f;
    g_params.relaxationMode = eNvFlexRelaxationLocal;
    g_params.relaxationFactor = 1.0f;
    g_params.solidPressure = 1.0f;
    g_params.adhesion = 0.0f;
    g_params.cohesion = 0.025f;
    g_params.surfaceTension = 0.0f;
    g_params.vorticityConfinement = 0.0f;
    g_params.buoyancy = 1.0f;
    g_params.diffuseThreshold = 100.0f;
    g_params.diffuseBuoyancy = 1.0f;
    g_params.diffuseDrag = 0.8f;
    g_params.diffuseBallistic = 16;
    g_params.diffuseLifetime = 2.0f;

    if (g_hasGround) {
        g_params.numPlanes = 1;
    } else {
        g_params.numPlanes = 0;
    }

    g_waveFrequency = 0.5f;
    g_waveAmplitude = 1.5f;
    g_waveFloorTilt = 0.0f;

    g_emit = false;
    g_warmup = false;

    g_maxDiffuseParticles = 0;
    g_maxNeighborsPerParticle = 96;
    g_numExtraParticles = 0;

    g_sceneLower = FLT_MAX;
    g_sceneUpper = -FLT_MAX;
}



void ResetCoupledAssets() {
    for (auto& iter : g_meshes) {
        NvFlexDestroyTriangleMesh(g_flexLib, iter.first);
        DestroyGpuMesh(iter.second);
    }

    for (auto& iter : g_fields) {
        NvFlexDestroyDistanceField(g_flexLib, iter.first);
        DestroyGpuMesh(iter.second);
    }

    for (auto& iter : g_convexes) {
        NvFlexDestroyConvexMesh(g_flexLib, iter.first);
        DestroyGpuMesh(iter.second);
    }

    g_fields.clear();
    g_meshes.clear();
    g_convexes.clear();
}



void ResetSim() {
    if(g_solver) {
        NvFlexDestroySolver(g_solver);
        g_solver = NULL;
    }

    NvFlexSetSolverDescDefaults(&g_solverDesc);

    StartGpuWork();
    g_scenes[g_scene]->Initialize();
    EndGpuWork();

    uint32_t numParticles = g_buffers->positions.size();
    uint32_t maxParticles = numParticles + g_numExtraParticles * g_numExtraMultiplier;

    g_solverDesc.maxParticles = maxParticles;
    g_solverDesc.maxDiffuseParticles = g_maxDiffuseParticles;
    g_solverDesc.maxNeighborsPerParticle = g_maxNeighborsPerParticle;
    g_solver = NvFlexCreateSolver(g_flexLib, &g_solverDesc);
    
    if (g_params.solidRestDistance == 0.0f)
        g_params.solidRestDistance = g_params.radius;

    if (g_params.fluidRestDistance > 0.0f)
        g_params.solidRestDistance = g_params.fluidRestDistance;

    if (g_params.collisionDistance == 0.0f)
        g_params.collisionDistance = Max(g_params.solidRestDistance, g_params.fluidRestDistance)*0.5f;

    if (g_params.particleFriction == 0.0f)
        g_params.particleFriction = g_params.dynamicFriction*0.1f;

    if (g_params.shapeCollisionMargin == 0.0f)
        g_params.shapeCollisionMargin = g_params.collisionDistance*0.5f;

    Vec3 particleLower, particleUpper;
    GetParticleBounds(particleLower, particleUpper);

    GetShapeBounds(g_shapeLower, g_shapeUpper);

    g_sceneLower = Min(Min(g_sceneLower, particleLower), g_shapeLower);
    g_sceneUpper = Max(Max(g_sceneUpper, particleUpper), g_shapeUpper);

    g_sceneLower -= g_params.collisionDistance;
    g_sceneUpper += g_params.collisionDistance;

    Vec3 up = Normalize(Vec3(-g_waveFloorTilt, 1.0f, 0.0f));

    (Vec4&)g_params.planes[0] = Vec4(up.x, up.y, up.z, 0.0f);
    (Vec4&)g_params.planes[1] = Vec4(0.0f, 0.0f, 1.0f, -g_sceneLower.z);
    (Vec4&)g_params.planes[2] = Vec4(1.0f, 0.0f, 0.0f, -g_sceneLower.x);
    (Vec4&)g_params.planes[3] = Vec4(-1.0f, 0.0f, 0.0f, g_sceneUpper.x);
    (Vec4&)g_params.planes[4] = Vec4(0.0f, 0.0f, -1.0f, g_sceneUpper.z);
    (Vec4&)g_params.planes[5] = Vec4(0.0f, -1.0f, 0.0f, g_sceneUpper.y);

    g_wavePlane = g_params.planes[2][3];


    g_buffers->diffusePositions.resize(g_maxDiffuseParticles);
    g_buffers->diffuseVelocities.resize(g_maxDiffuseParticles);
    g_buffers->diffuseCount.resize(1, 0);

    g_buffers->smoothPositions.resize(maxParticles);

    g_buffers->normals.resize(0);
    g_buffers->normals.resize(maxParticles);

    int numTris = g_buffers->triangles.size() / 3;
    for (int i = 0; i < numTris; ++i) {
        Vec3 v0 = Vec3(g_buffers->positions[g_buffers->triangles[i * 3 + 0]]);
        Vec3 v1 = Vec3(g_buffers->positions[g_buffers->triangles[i * 3 + 1]]);
        Vec3 v2 = Vec3(g_buffers->positions[g_buffers->triangles[i * 3 + 2]]);

        Vec3 n = Cross(v1 - v0, v2 - v0);

        g_buffers->normals[g_buffers->triangles[i * 3 + 0]] += Vec4(n, 0.0f);
        g_buffers->normals[g_buffers->triangles[i * 3 + 1]] += Vec4(n, 0.0f);
        g_buffers->normals[g_buffers->triangles[i * 3 + 2]] += Vec4(n, 0.0f);
    }

    for (int i = 0; i < int(maxParticles); ++i)
        g_buffers->normals[i] = Vec4(SafeNormalize(Vec3(g_buffers->normals[i]), Vec3(0.0f, 1.0f, 0.0f)), 0.0f);


    if (g_mesh) {
        g_meshRestPositions = g_mesh->m_positions;
    } else {
        g_meshRestPositions.resize(0);
    }

    g_scenes[g_scene]->PostInitialize();

    g_buffers->activeIndices.resize(g_buffers->positions.size());
    for (int i = 0; i < g_buffers->activeIndices.size(); ++i)
        g_buffers->activeIndices[i] = i;

    g_buffers->positions.resize(maxParticles);
    g_buffers->velocities.resize(maxParticles);
    g_buffers->phases.resize(maxParticles);

    g_buffers->densities.resize(maxParticles);
    g_buffers->anisotropy1.resize(maxParticles);
    g_buffers->anisotropy2.resize(maxParticles);
    g_buffers->anisotropy3.resize(maxParticles);

    g_buffers->restPositions.resize(g_buffers->positions.size());
    for (int i = 0; i < g_buffers->positions.size(); ++i)
        g_buffers->restPositions[i] = g_buffers->positions[i];

    if (g_buffers->rigidOffsets.size()) {
        assert(g_buffers->rigidOffsets.size() > 1);

        const int numRigids = g_buffers->rigidOffsets.size() - 1;

        if (g_buffers->rigidTranslations.size() == 0)  {
            g_buffers->rigidTranslations.resize(g_buffers->rigidOffsets.size() - 1, Vec3());
            CalculateRigidCentersOfMass(&g_buffers->positions[0], g_buffers->positions.size(), &g_buffers->rigidOffsets[0], &g_buffers->rigidTranslations[0], &g_buffers->rigidIndices[0], numRigids);
        }

        g_buffers->rigidLocalPositions.resize(g_buffers->rigidOffsets.back());
        CalculateRigidLocalPositions(&g_buffers->positions[0], &g_buffers->rigidOffsets[0], &g_buffers->rigidTranslations[0], &g_buffers->rigidIndices[0], numRigids, &g_buffers->rigidLocalPositions[0]);

        g_buffers->rigidRotations.resize(g_buffers->rigidOffsets.size() - 1, Quat());
    }

    UnmapBuffers(g_buffers);

    NvFlexCopyDesc copyDesc;
    copyDesc.dstOffset = 0;
    copyDesc.srcOffset = 0;
    copyDesc.elementCount = numParticles;

    NvFlexSetParams(g_solver, &g_params);
    NvFlexSetParticles(g_solver, g_buffers->positions.buffer, &copyDesc);
    NvFlexSetVelocities(g_solver, g_buffers->velocities.buffer, &copyDesc);
    NvFlexSetNormals(g_solver, g_buffers->normals.buffer, &copyDesc);
    NvFlexSetPhases(g_solver, g_buffers->phases.buffer, &copyDesc);
    NvFlexSetRestParticles(g_solver, g_buffers->restPositions.buffer, &copyDesc);
    NvFlexSetActive(g_solver, g_buffers->activeIndices.buffer, &copyDesc);
    NvFlexSetActiveCount(g_solver, numParticles);
    
    if (g_buffers->springIndices.size()) {
        assert((g_buffers->springIndices.size() & 1) == 0);
        assert((g_buffers->springIndices.size() / 2) == g_buffers->springLengths.size());

        NvFlexSetSprings(g_solver, g_buffers->springIndices.buffer, g_buffers->springLengths.buffer, g_buffers->springStiffness.buffer, g_buffers->springLengths.size());
    }

    if (g_buffers->rigidOffsets.size()) {
        NvFlexSetRigids(g_solver, g_buffers->rigidOffsets.buffer, g_buffers->rigidIndices.buffer, g_buffers->rigidLocalPositions.buffer, g_buffers->rigidLocalNormals.buffer, g_buffers->rigidCoefficients.buffer, g_buffers->rigidPlasticThresholds.buffer, g_buffers->rigidPlasticCreeps.buffer, g_buffers->rigidRotations.buffer, g_buffers->rigidTranslations.buffer, g_buffers->rigidOffsets.size() - 1, g_buffers->rigidIndices.size());
    }

    if (g_buffers->inflatableTriOffsets.size()) {
        NvFlexSetInflatables(g_solver, g_buffers->inflatableTriOffsets.buffer, g_buffers->inflatableTriCounts.buffer, g_buffers->inflatableVolumes.buffer, g_buffers->inflatablePressures.buffer, g_buffers->inflatableCoefficients.buffer, g_buffers->inflatableTriOffsets.size());
    }

    if (g_buffers->triangles.size()) {
        NvFlexSetDynamicTriangles(g_solver, g_buffers->triangles.buffer, g_buffers->triangleNormals.buffer, g_buffers->triangles.size() / 3);
    }

    if (g_buffers->shapeFlags.size()) {
        NvFlexSetShapes(
            g_solver,
            g_buffers->shapeGeometry.buffer,
            g_buffers->shapePositions.buffer,
            g_buffers->shapeRotations.buffer,
            g_buffers->shapePrevPositions.buffer,
            g_buffers->shapePrevRotations.buffer,
            g_buffers->shapeFlags.buffer,
            int(g_buffers->shapeFlags.size()));
    }

    if (g_warmup) {
        printf("Warming up sim..\n");

        NvFlexParams copy = g_params;
        copy.numIterations = 4;

        NvFlexSetParams(g_solver, &copy);

        const int kWarmupIterations = 100;

        for (int i = 0; i < kWarmupIterations; ++i) {
            NvFlexUpdateSolver(g_solver, 0.0001f, 1, false);
            NvFlexSetVelocities(g_solver, g_buffers->velocities.buffer, NULL);
        }

        NvFlexGetParticles(g_solver, g_buffers->positions.buffer, NULL);
        NvFlexGetSmoothParticles(g_solver, g_buffers->smoothPositions.buffer, NULL);
        NvFlexGetAnisotropy(g_solver, g_buffers->anisotropy1.buffer, g_buffers->anisotropy2.buffer, g_buffers->anisotropy3.buffer, NULL);

        printf("Finished warm up.\n");
    }
}



void Init() {
    RandInit();
    ResetSimGlobals();
    ResetCoupledAssets();
    ResetSim();
}



void UpdateWind() {}



void UpdateSimMapped() {
    if (!g_pause || g_step)    {
        UpdateWind();    
        g_scenes[g_scene]-> Update();
    }

    if (g_exportObjsFlag || g_saveClothPerSimStep) {
        g_scenes[g_scene]->Export(&g_exportBase[0]);
    }
}



void UpdateSimPostmap() {
    NvFlexSetParticles(g_solver, g_buffers->positions.buffer, NULL);
    NvFlexSetVelocities(g_solver, g_buffers->velocities.buffer, NULL);
    NvFlexSetPhases(g_solver, g_buffers->phases.buffer, NULL);
    NvFlexSetActive(g_solver, g_buffers->activeIndices.buffer, NULL);
    NvFlexSetActiveCount(g_solver, g_buffers->activeIndices.size());

    g_scenes[g_scene]->Sync();

    if (g_shapesChanged) {
        NvFlexSetShapes(
            g_solver,
            g_buffers->shapeGeometry.buffer,
            g_buffers->shapePositions.buffer,
            g_buffers->shapeRotations.buffer,
            g_buffers->shapePrevPositions.buffer,
            g_buffers->shapePrevRotations.buffer,
            g_buffers->shapeFlags.buffer,
            int(g_buffers->shapeFlags.size()));
    }

    if (!g_pause || g_step) {
        NvFlexSetParams(g_solver, &g_params);
        NvFlexUpdateSolver(g_solver, g_dt, g_numSubsteps, g_profile);

        g_frame++;
        g_step = false;
    }

    NvFlexGetParticles(g_solver, g_buffers->positions.buffer, NULL);
    NvFlexGetVelocities(g_solver, g_buffers->velocities.buffer, NULL);
    NvFlexGetNormals(g_solver, g_buffers->normals.buffer, NULL);

    if (g_buffers->triangles.size()) {
        NvFlexGetDynamicTriangles(g_solver, g_buffers->triangles.buffer, g_buffers->triangleNormals.buffer, g_buffers->triangles.size() / 3);
    }

    if (g_buffers->rigidOffsets.size()) {
        NvFlexGetRigids(g_solver, NULL, NULL, NULL, NULL, NULL, NULL, NULL, g_buffers->rigidRotations.buffer, g_buffers->rigidTranslations.buffer);
    }
}




void MainLoop(int n_iters) {

    bool quit = false;

    while (g_frame < n_iters && !quit && !g_quit) {

        bool isLast = g_frame == n_iters-1;

        if (isLast) 
        {
            if (g_exportObjs) 
            {
                g_exportObjsFlag = true;
            }
        }

    MapBuffers(g_buffers);
    UpdateSimMapped();
    UnmapBuffers(g_buffers);
    UpdateSimPostmap();
    }
}



int main(int argc, char* argv[]) {
    srand ( time(NULL) );
    char objpath[400];
    char inputpath[400];
    bool objpath_exists = false;
    bool inputpath_exists = false;
    float particle_radius = 0.0078f;
    float mass = -1.0f;
    float stretch_stiffness = -1.0f;
    float bend_stiffness = -1.0f;
    float shear_stiffness = -1.0f;
    float extra_cp_spacing = 0.0f;
    float extra_cp_rad_mult = 1.0f;
    int cloth_size = Scene::AUTO_CLOTH_SIZE;
    int iters = 200;
    float obj_scale = 2.0;
    Vec3 translate = Vec3(0,0,0);
    Vec4 rotate = Vec4(0,0,0,0);
    bool use_quat = false;
    char cfg[200];
    bool parse = false;
    int input_t_frame=0;

    for (int i = 1; i < argc; ++i) {
        int d;
        float f;
        char s[10];

        if (sscanf(argv[i], "-device=%d", &d)) {
            g_device = d;
        }

        if (sscanf(argv[i], "-extensions=%d", &d)) {
            g_extensions = d != 0;
        }

        if (sscanf(argv[i], "-multiplier=%d", &d) == 1) {
            g_numExtraMultiplier = d;
        }

        if (sscanf(argv[i], "-windstrength=%f", &f) == 1) {
            g_windStrength = f;
        }

        if (sscanf(argv[i], "-input_t_frame=%f", &f) == 1) {
            input_t_frame = f;
        }

        if (sscanf(argv[i], "-g_curScene=%s", s) == 1) {
            strcpy(g_curScene, s);
        } 

        if (sscanf(argv[i], "-obj=%s", objpath) == 1) {
            if (!exists(&objpath[0])) {
                exit(-1);
            }
            objpath_exists = true;
        }

        if (sscanf(argv[i], "-input_cloth_obj=%s", inputpath) == 1) {
            if (!exists(&inputpath[0])) {
                exit(-1);
            }
            inputpath_exists = true;
        }

        if (sscanf(argv[i], "-bstiff=%f", &f) == 1) {
            bend_stiffness = f;
        }

        if (sscanf(argv[i], "-shstiff=%f", &f) == 1) {
            shear_stiffness = f;
        }

        if (sscanf(argv[i], "-ststiff=%f", &f) == 1) {
            stretch_stiffness = f;
        }

        if (sscanf(argv[i], "-mass=%f", &f) == 1) {
            mass = f;
        }       

        if (sscanf(argv[i], "-scale=%f", &f) == 1) {
            obj_scale = f;
        }

        if (sscanf(argv[i], "-x=%f", &f) == 1) {
            translate.x = f;
        }

        if (sscanf(argv[i], "-y=%f", &f) == 1) {
            translate.y = f;
        }

        if (sscanf(argv[i], "-z=%f", &f) == 1) {
            translate.z = f;
        }

        if (sscanf(argv[i], "-rx=%f", &f) == 1) {
            rotate.x = f;
        }

        if (sscanf(argv[i], "-ry=%f", &f) == 1) {
            rotate.y = f;
        }

        if (sscanf(argv[i], "-rz=%f", &f) == 1) {
            rotate.z = f;
        }

        if (sscanf(argv[i], "-rw=%f", &f) == 1) {
            rotate.w = f;
        }

        if (string(argv[i]).find("-use_quat") != string::npos) {
            use_quat=true;
        }

        if (string(argv[i]).find("-use_euler") != string::npos) {
            use_quat=false;
        }

        if (sscanf(argv[i], "-dt=%f", &f) == 1) {
            g_dt = f;
        }

        if (string(argv[i]).find("-export") != string::npos) {
            g_exportObjs = true;
        }

        if (sscanf(argv[i], "-export=%s", g_exportBase) == 1) {
            g_exportObjs = true;
        }

        if (string(argv[i]).find("-saveClothPerSimStep") != string::npos) {
            g_saveClothPerSimStep = true;
        }

        if ((string(argv[i]).find("-randomSeed") != string::npos) & (sscanf(argv[i], "-randomSeed=%d", &d) == 1)) {
            g_randomSeed = d;
        }

        if ((string(argv[i]).find("-randomClothMinRes") != string::npos) & (sscanf(argv[i], "-randomClothMinRes=%d", &d) == 1)) {
            g_randomClothMinRes = d;
        }

        if ((string(argv[i]).find("-randomClothMaxRes") != string::npos) & (sscanf(argv[i], "-randomClothMaxRes=%d", &d) == 1)) {
            g_randomClothMaxRes = d;
        }

        if ((string(argv[i]).find("-particleRadius") != string::npos) & (sscanf(argv[i], "-particleRadius=%f", &f) == 1)) {
            particle_radius = f;
        }

        if ((string(argv[i]).find("-wind_t_frame_x") != string::npos) & (sscanf(argv[i], "-wind_t_frame_x=%f", &f) == 1)) {
            wind_t_frame_x = f;
        }
        if ((string(argv[i]).find("-wind_t_frame_y") != string::npos) & (sscanf(argv[i], "-wind_t_frame_y=%f", &f) == 1)) {
            wind_t_frame_y = f;
        }
        if ((string(argv[i]).find("-wind_t_frame_z") != string::npos) & (sscanf(argv[i], "-wind_t_frame_z=%f", &f) == 1)) {
            wind_t_frame_z = f;
        }

        if ((string(argv[i]).find("-wind_t_plus_1_frame_x") != string::npos) & (sscanf(argv[i], "-wind_t_plus_1_frame_x=%f", &f) == 1)) {
            wind_t_plus_1_frame_x = f;
        }
        if ((string(argv[i]).find("-wind_t_plus_1_frame_y") != string::npos) & (sscanf(argv[i], "-wind_t_plus_1_frame_y=%f", &f) == 1)) {
            wind_t_plus_1_frame_y = f;
        }
        if ((string(argv[i]).find("-wind_t_plus_1_frame_z") != string::npos) & (sscanf(argv[i], "-wind_t_plus_1_frame_z=%f", &f) == 1)) {
            wind_t_plus_1_frame_z = f;
        }

        if ((string(argv[i]).find("-clothLift") != string::npos) & (sscanf(argv[i], "-clothLift=%f", &f) == 1)) {
            g_clothLift = f;
        }

        if ((string(argv[i]).find("-clothStiffness") != string::npos) & (sscanf(argv[i], "-clothStiffness=%f", &f) == 1)) {
            g_clothStiffness = f;
        }

        if ((string(argv[i]).find("-clothDrag") != string::npos) & (sscanf(argv[i], "-clothDrag=%f", &f) == 1)) {
            g_clothDrag = f;
        }

        if ((string(argv[i]).find("-dynamicFriction") != string::npos) & (sscanf(argv[i], "-dynamicFriction=%f", &f) == 1)) {
            g_dynamicFriction = f;
        }

        if ((string(argv[i]).find("-staticFriction") != string::npos) & (sscanf(argv[i], "-staticFriction=%f", &f) == 1)) {
            g_staticFriction = f;
        }

        sscanf(argv[i], "-clothsize=%d", &d);
        if ((string(argv[i]).find("-clothsize") != string::npos) & (d == 0) & (cloth_size == -1)) {
            cloth_size = 0;
        } else if ((string(argv[i]).find("-clothsize") != string::npos) & (d > 0) & (cloth_size == -1)) {
            g_clothNumParticles = d;
            cloth_size = d;
        }
      
        if (string(argv[i]).find("-v") != string::npos) {
            g_verbose = true;
        }

        if (string(argv[i]).find("-nofloor") != string::npos) {
            g_hasGround = false;
        }

        if (sscanf(argv[i], "-config=%s", cfg) == 1) {
            if (!exists(&cfg[0], true)) {
                exit(-1);
            }
            parse = true;
        }
    }

    if (!objpath_exists || !inputpath_exists) {
        exit(-1);
    }


    Scene::ClothParams cp(cloth_size, 
        particle_radius, 
        mass, 
        stretch_stiffness, bend_stiffness, shear_stiffness, 
        extra_cp_spacing, extra_cp_rad_mult);

    Scene::ObjParams op(obj_scale, translate, rotate, use_quat);


    if (parse) {
        ParseConfig(&cfg[0], iters, cp, op);
    }


    if (boost::iequals(g_curScene, "wind")) 
    {
        g_scenes.push_back(new Wind("Wind", &objpath[0], &inputpath[0], input_t_frame, cp, op));
    } 
    else if (boost::iequals(g_curScene, "drape"))
    {
        g_scenes.push_back(new Drape("Drape", &objpath[0], &inputpath[0], cp, op));
    } 
    else if (boost::iequals(g_curScene, "rotate"))
    {
        g_scenes.push_back(new RotateTable("RotateTable", &objpath[0], &inputpath[0], input_t_frame, cp, op));
    }
    else if (boost::iequals(g_curScene, "ball"))
    {
        g_scenes.push_back(new Ball("Ball", &objpath[0], &inputpath[0], input_t_frame, cp, op));
    }

    else
    {
        cout << "[Error] No available scenes..." << endl;
        exit(-1);
    }
    
    g_scene = 0;

    InitSim();

    StartGpuWork();
    Init();
    EndGpuWork();

    MainLoop(iters);
    Shutdown();

    return 0;
} 