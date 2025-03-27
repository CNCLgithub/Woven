import os, subprocess, re, sys, ast
from utils import runCmd, mkdirs, fileExist, rm, mkdir, rm_capital_for_render, mv, load_pos_vel
import json
import numpy as np
import random
import torch
import argparse
from shutil import copyfile
import shutil
import fnmatch

"""
##########################################################################################
Script Name                : main_simulate.py
Description                : This script runs FleX executable
Author                     : Wenyan Bi
Usage                      : 
Output                     : 
Date                       : 
##########################################################################################
"""

DEBUG=False ## [TODO]: Need check this
SAVE_AS_OBS = True # Valid only if DEBUG==True


parser = argparse.ArgumentParser(description='This script use Flex to simulate cloth dynamics.')
# Globals
parser.add_argument('--randomSeed', type=int, default=14, help='Fix the random seed.')
parser.add_argument('--flex_verbose', type=int, default=0, help='0 to inhibit printings from FleX')
# Experiments
if os.getenv('CALL_BY_JULIA') is None:
    parser.add_argument('--prev_obj_f', type=str, default="*.obj", help='.obj file for previous frame')
else:
    parser.add_argument('--cloth_velocity', type=str, default="[[0,0,0],[0,0,0],[0,0,0]]", help='Velocity for each vertice')
    parser.add_argument('--cloth_position', type=str, default="[[0,0,0],[0,0,0],[0,0,0]]", help='Position for each vertice')
    parser.add_argument('--object_velocity', type=str, default="[[0,0,0],[0,0,0],[0,0,0]]", help='Velocity for each vertice')
    parser.add_argument('--object_position', type=str, default="[[0,0,0],[0,0,0],[0,0,0]]", help='Position for each vertice')
parser.add_argument('--scene', type=str, default="wind", help='wind|drape|ball|rotate')
parser.add_argument('--mass', type=float, default=-1.0, help='invMass [Set -1 to use the value defined in --flexConfig]')
parser.add_argument('--bstiff', type=float, default=1.0, help='bend_stiffness')
parser.add_argument('--shstiff', type=float, default=0.0, help='shear stiffness, 0.0 to use bstiff value')
parser.add_argument('--ststiff', type=float, default=0.0, help='stretch stiffnessetch, 0.0 to use bstiff value')
parser.add_argument('--extforce', type=float, default=0.0, help='only valid for wind')

# Flex
parser.add_argument('--flexRootPath', type=str, default="FleX/", help='path to FleX root directory')
parser.add_argument('--flexConfig', type=str, default="FleXConfigs/flexConfig.yml", help='FleX config file')
parser.add_argument('--flex_input_root_path', type=str, default="dataset/trialObjs/", help='root path to FleX input .obj file')
parser.add_argument('--flex_velocity_position_root_path', type=str, default="dataset/inputObjs/", 
                                                          help='root path to FleX input .obj file that defines velocity and position')
parser.add_argument('--obj_input',  type=str, default="model1.obj", help='name of the FleX input .obj file')
parser.add_argument('--flex_output_root_path', type=str, default="experiments/simulation/trials/", help='root path to FleX output .obj files')
# Flex simulation paras
parser.add_argument('--input_t_frame', type=int, default=94, help='start at t-th frame')
parser.add_argument('--windstrength', type=float, default=0.3, help='wind strength')###
parser.add_argument('--scale', type=float, default=2.0, help='object scale')
parser.add_argument('--rot', default=(0,0,0), help='Rotation of the object.')
parser.add_argument('--local', type=bool, default=True, help='run Flex locally')
parser.add_argument('--floor', type=bool, default=False, help='')
parser.add_argument('--offline', type=bool, default=True, help='')
parser.add_argument('--useQuat', type=bool, default=False, help='')
parser.add_argument('--particleRadius', type=float, default=0.02, help='')
parser.add_argument('--clothNumParticles', type=int, default=105, help='')
parser.add_argument('--flexrandomSeed', type=int, default=-1, help='')
parser.add_argument('--visSaveClothPerSimStep', type=bool, default=False, help='')
parser.add_argument('--randomClothMinRes', type=int, default=145, help='')
parser.add_argument('--randomClothMaxRes', type=int, default=215, help='')
parser.add_argument('--clothLift', type=float, default=-1.0, help='')
parser.add_argument('--clothDrag', type=float, default=-1.0, help='')
parser.add_argument('--dynamicFriction', type=float, default=-1, help='')
parser.add_argument('--staticFriction', type=float, default=-1, help='')
parser.add_argument('--saveClothPerSimStep', type=int, default=1, help='')

#=============================================================================
# ----------Init--------------------------------------------------------------
#=============================================================================
args = parser.parse_args() if os.getenv('CALL_BY_JULIA') is None else parser.parse_args(sys.argv)
np.random.seed(args.randomSeed)
random.seed(args.randomSeed)
torch.manual_seed(args.randomSeed)
torch.cuda.manual_seed(args.randomSeed)

#=============================================================================
# ----------Cloth Params------------------------------------------------------
#=============================================================================
scene = str(args.scene)
mass = float("{0:.9f}".format(args.mass)) 
bstiff = float("{0:.9f}".format(args.bstiff))
shstiff = float("{0:.9f}".format(args.shstiff))
shstiff = bstiff if shstiff<=0 else shstiff
ststiff = float("{0:.9f}".format(args.ststiff))
ststiff = bstiff if ststiff<=0 else ststiff
extforce = float("{0:.9f}".format(args.extforce))


if os.getenv('CALL_BY_JULIA') is None:  
    cloth_pos, cloth_vel, obj_pos, obj_vel = load_pos_vel(filename=args.prev_obj_f)
    if scene == "ball": 
        if int(args.input_t_frame) <= (95-38): 
            obj_f = os.path.join("experiments/simulation", 
                                 "{}_mass_{}_bs_{}_sh_{}_st_{}".format(scene, mass, bstiff, bstiff, bstiff), 
                                 "{}_cloth_{}.obj".format(scene, args.input_t_frame))
            _, _, obj_pos, obj_vel = load_pos_vel(filename=obj_f)     
    cloth_velocity = ast.literal_eval(cloth_vel)    
    cloth_position = ast.literal_eval(cloth_pos)    
    object_velocity = ast.literal_eval(obj_vel) 
    object_position = ast.literal_eval(obj_pos) 
else:
    cloth_velocity = ast.literal_eval(args.cloth_velocity)  
    cloth_position = ast.literal_eval(args.cloth_position)
    object_velocity = ast.literal_eval(args.object_velocity)
    object_position = ast.literal_eval(args.object_position) 


#=============================================================================
# ----------Sim---------------------------------------------------------------
#=============================================================================
input_vel_and_pos_obj_file = os.path.join(args.flex_velocity_position_root_path, scene+'.obj')
outputPath = os.path.join(args.flex_output_root_path)

superPath = "/".join(args.flex_output_root_path.split("/")[:-2])
if not os.path.exists(os.path.abspath(superPath)):
    mkdirs(os.path.abspath(superPath))
output_vel_and_pos_obj_file = os.path.join(superPath, scene+'.obj')

copyfile(input_vel_and_pos_obj_file, output_vel_and_pos_obj_file)
with open(output_vel_and_pos_obj_file, "a") as myfile:
    myfile.write("# Velocities\n")
    for tmp_vel in range(len(cloth_velocity)):
        myfile.write('s ' +
                     str(cloth_velocity[tmp_vel][0]) + ' ' +
                     str(cloth_velocity[tmp_vel][1]) + ' ' +
                     str(cloth_velocity[tmp_vel][2]) + ' ' +
                     "\n")

    myfile.write("# Vertices\n")
    for tmp_pos in range(len(cloth_position)):
        myfile.write('v ' +
                     str(cloth_position[tmp_pos][0]) + ' ' +
                     str(cloth_position[tmp_pos][1]) + ' ' +
                     str(cloth_position[tmp_pos][2]) + ' ' +
                     "\n")

    if scene == 'ball' and object_velocity != [[0.0]]:
        myfile.write("# Velocities\n")
        for tmp_vel in range(len(object_velocity)):
            myfile.write('S ' +
                         str(object_velocity[tmp_vel][0]) + ' ' +
                         str(object_velocity[tmp_vel][1]) + ' ' +
                         str(object_velocity[tmp_vel][2]) + ' ' +
                         "\n")

        myfile.write("# Vertices\n")
        for tmp_pos in range(len(object_position)):
            myfile.write('V ' +
                         str(object_position[tmp_pos][0]) + ' ' +
                         str(object_position[tmp_pos][1]) + ' ' +
                         str(object_position[tmp_pos][2]) + ' ' +
                         "\n")
myfile.close()

wind_t_frame_x = 0
wind_t_frame_y = 0
wind_t_frame_z = 0
wind_t_plus_1_frame_x = 0
wind_t_plus_1_frame_y = 0
wind_t_plus_1_frame_z = 0

objPath = None
if scene == 'rotate':
    objPath = os.path.join(args.flex_input_root_path, scene, 'table_0.obj')
elif scene == 'wind':
    objPath = os.path.join(args.flex_input_root_path, scene, args.obj_input)
    wind_file = os.path.join(args.flex_velocity_position_root_path, 'wind_info.txt')
    f = open(wind_file, "r")
    for x in f:
        x = x.rstrip('\n').split(',')
        if int(x[-1]) == int(args.input_t_frame)-1:
            wind_t_frame_x = x[0]
            wind_t_frame_y = x[1]
            wind_t_frame_z = x[2]
        if int(x[-1]) == int(args.input_t_frame)+0:
            wind_t_plus_1_frame_x = x[0]
            wind_t_plus_1_frame_y = x[1]
            wind_t_plus_1_frame_z = x[2]
            break
else:
    objPath = os.path.join(args.flex_input_root_path, scene, args.obj_input)

# ----- Setup environment ------------- #
FLEX_BIN_PATH = os.path.join(args.flexRootPath, "bin", "linux64", "NvFlexDemoReleaseCUDA_x64_" + scene)
if not os.path.exists(FLEX_BIN_PATH):
    errorMessage = "==> Error: No FleX binary found. Make sure you have set the right path and compiled FleX.\n" \
                   "To compile FleX: singularity exec --nv kimImage.simg bash buildFleX.sh --build=true"
    sys.exit(errorMessage)
else:
    os.environ["FLEX_PATH"] = args.flexRootPath
# fix for increasing evn size
ld_path = os.environ.get('LD_LIBRARY_PATH', '')
if os.path.join(args.flexRootPath, "external") not in ld_path:
    os.environ["LD_LIBRARY_PATH"] += ":{}".format(os.path.join(args.flexRootPath, "external"))
# ----- End Setup environment --------- #


# ---------- Sim-----------------------#
sim_cmd = [FLEX_BIN_PATH,
           "-obj={}".format(os.path.abspath(objPath)),
           "-config={}".format(os.path.abspath(args.flexConfig)),
           "-export={}".format(os.path.abspath(outputPath)),
           not args.useQuat and "-rx={} -ry={} -rz={}".format(*args.rot)
           or "-rx={} -ry={} -rz={} -rw={}".format(*args.rot),
           ]

if not args.floor:
    sim_cmd.append("-nofloor")

if args.offline:
    sim_cmd.append("-offline")

if args.useQuat:
    sim_cmd.append("-use_quat")
else:
    sim_cmd.append("-use_euler")

if args.visSaveClothPerSimStep:
    sim_cmd.append("-saveClothPerSimStep")

if args.flex_verbose:
    sim_cmd.append("-v")

sim_cmd.append("-g_curScene={}".format(scene))
sim_cmd.append("-bstiff={0:f}".format(bstiff))
sim_cmd.append("-particleRadius={0:f}".format(args.particleRadius))
sim_cmd.append("-clothsize={0:d}".format(args.clothNumParticles))
sim_cmd.append("-randomSeed={0:d}".format(args.flexrandomSeed))
sim_cmd.append("-randomClothMinRes={0:d}".format(args.randomClothMinRes))
sim_cmd.append("-randomClothMaxRes={0:d}".format(args.randomClothMaxRes))
sim_cmd.append("-clothLift={0:f}".format(args.clothLift))
sim_cmd.append("-scale={0:f}".format(args.scale))
# sim_cmd.append("-windstrength={0:f}".format(args.windstrength))
sim_cmd.append("-input_t_frame={0:d}".format(args.input_t_frame))
sim_cmd.append("-wind_t_frame_x={0:f}".format(float(wind_t_frame_x)))
sim_cmd.append("-wind_t_frame_y={0:f}".format(float(wind_t_frame_y)))
sim_cmd.append("-wind_t_frame_z={0:f}".format(float(wind_t_frame_z)))
sim_cmd.append("-wind_t_plus_1_frame_x={0:f}".format(float(wind_t_plus_1_frame_x)))
sim_cmd.append("-wind_t_plus_1_frame_y={0:f}".format(float(wind_t_plus_1_frame_y)))
sim_cmd.append("-wind_t_plus_1_frame_z={0:f}".format(float(wind_t_plus_1_frame_z)))
sim_cmd.append("-mass={0:.9f}".format(float(mass)))
sim_cmd.append("-shstiff={0:.9f}".format(float(shstiff)))
sim_cmd.append("-ststiff={0:.9f}".format(float(ststiff)))
sim_cmd.append("-extforce={0:.9f}".format(float(extforce)))
sim_cmd.append("-clothDrag={0:f}".format(args.clothDrag))
sim_cmd.append("-dynamicFriction={0:f}".format(args.dynamicFriction))
sim_cmd.append("-staticFriction={0:f}".format(args.staticFriction))
sim_cmd.append("-saveClothPerSimStep={0:d}".format(args.saveClothPerSimStep))
sim_cmd.append("-input_cloth_obj={}".format(output_vel_and_pos_obj_file))

env = {}

if args.local:
    env["DISPLAY"] = ":0"
else:
    sim_cmd.insert(0, "vglrun")

lines_stdout = runCmd(" ".join(sim_cmd), extra_vars=env, verbose=args.flex_verbose)

if len(lines_stdout) < 1:
    sys.exit("lines_stdout<1")

