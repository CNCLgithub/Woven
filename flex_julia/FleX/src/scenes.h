#pragma once



class Scene
{
public:
    Scene(const char* name) : mName(name) {}
    
    virtual void Initialize() = 0;
    virtual void PostInitialize() {}
    virtual void Destroy() {}
    virtual void Export(const char* basename) {}
    // update any buffers (all guaranteed to be mapped here)
    virtual void Update() {}    
    // send any changes to flex (all buffers guaranteed to be unmapped here)
    virtual void Sync() {}
    virtual void Draw(int pass) {}
    virtual void KeyDown(int key) {}
    virtual void DoGui() {}
    virtual void CenterCamera() {}
    virtual Matrix44 GetBasis() { return Matrix44::kIdentity; } 
    virtual const char* GetName() { return mName; }
    const char* mName;

    static const int AUTO_CLOTH_SIZE = -1;
    
    struct ClothParams 
    {
        int n_particles;
        float particle_radius;
        float invMass;
        float stretch_stiffness;
        float bend_stiffness;
        float shear_stiffness;
        float extra_cp_spacing;
        float extra_cp_rad_mult;

        ClothParams(int cs=64, float pr=0.05f, float mass=1.0, float sts=1.0f, float bs=0.8f, float shs=0.5f, float es=0.0f, float erm=1.0f):
            n_particles(cs), particle_radius(pr), invMass(mass), stretch_stiffness(sts),
            bend_stiffness(bs), shear_stiffness(shs), extra_cp_spacing(es), extra_cp_rad_mult(erm) {}
    };


    // The object that interacts with the cloth
    struct ObjParams 
    {
        float scale;
        Vec3 translate;
        Vec4 rotate;
        bool use_quat = true;

        ObjParams(float scale=1.0, Vec3 t=Vec3(0,0,0), Vec4 r=Vec4(0,0,0,0), bool use_quat=true):
            scale(scale), translate(t), rotate(r), use_quat(use_quat) {}
    };


    static void PrintProperties(ClothParams& cp) 
    {
        printf(" ---- Cloth Params ----\n");
        printf("n_particles (per dim): %d\n", cp.n_particles);
        printf("particle_radius:       %f\n", cp.particle_radius);
        printf("mass:                  %f\n", cp.invMass);    
        printf("stretch_stiffness:     %f\n", cp.stretch_stiffness);
        printf("bend_stiffness:        %f\n", cp.bend_stiffness);
        printf("shear_stiffness:       %f\n", cp.shear_stiffness);
        printf("extra_cp_spacing:      %f\n", cp.extra_cp_spacing);
        printf("extra_cp_rad_mult:     %f\n", cp.extra_cp_rad_mult);
        cout << endl;
    }


    static void PrintProperties(ObjParams& op) 
    {
        printf(" ---- Object Params ----\n");
        printf("scale:          %f\n", op.scale);
        printf("translate:      (%f, %f, %f)\n",
            op.translate.x,
            op.translate.y,
            op.translate.z);
        printf("rotate: (%f, %f, %f, %f)\n",
            op.rotate.x,
            op.rotate.y,
            op.rotate.z,
            op.rotate.w);
        printf("using quat?:    %s\n", (op.use_quat ? "yes" : "no"));
        cout << endl;
    }


};



#include "scenes/wind.h"
#include "scenes/rotate.h"
#include "scenes/drape.h"
#include "scenes/ball.h"
//#include "scenes/windChangeStiffness.h"
// #include "scenes/bag.h"

