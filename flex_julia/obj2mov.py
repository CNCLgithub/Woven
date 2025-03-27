
import bpy
import subprocess, os, sys, argparse, glob, time, random, shutil
from pathlib import Path


"""
#############################################################################################
Script Name                : obj2mov.py
Description                : Use Blender to render image from .obj, must be called by Blender
Usage(2 ways)              : 1) run main_render.py
                           : 2) experiments/obj2mov/blender-2.79a-linux64/blender experiments/obj2mov/toRender_wind.blend --background --python obj2mov.py
Env                        :    blender-2.79a-linux64 (with pip3 installed)
Author                     : Wenyan Bi <wenyan.bi@yale.edu>
Date                       : 14/08/2020
Known Issues               : 1) Blender bundled python might complain error with numpy even it 
                                is installed (https://github.com/tensorflow/tensorflow/issues/559). 
                                [Solution]: 
                                $ cd experiments/obj2mov/blender-2.79a-linux64/2.79/python
                                $ ./bin/python3.5m bin/pip3 uninstall matplotlib numpy opencv-python
                                $ cd lib/python3.5/site-packages/
                                $ rm -rf numpy*
                                $ cd -
                                $./bin/python3.5m bin/pip3 install numpy opencv-python matplotlib
#################################################################################################
"""


""" 
For debugging:
experiments/obj2mov/blender-2.79a-linux64/blender experiments/obj2mov/toRender_wind.blend --background --python obj2mov.py
"""

# -------------------------------- utils --------------------------------------- #

def mkdirs(paths):
    try:
        if isinstance(paths, list) and not isinstance(paths, str):
            for path in paths:
                mkdir(path)
        else:
            mkdir(paths)
    except:
        time.sleep(random.random()/5)
        if isinstance(paths, list) and not isinstance(paths, str):
            for path in paths:
                mkdir(path)
        else:
            mkdir(paths)

def mkdir(path):
    if not os.path.exists(path):
        os.makedirs(path)
      
def fileExist(path):
    if path != '/':
        if os.path.isdir(path):
            return True
        else:
            temp = Path(path)
            return temp.is_file()
    else:
        return False

def rm(path):
    if fileExist(path):
        if os.path.isdir(path):
            shutil.rmtree(path)
        else:
            os.remove(path)       

class CustomError(Exception):
    pass

# ------------------------------------------------------------------------------- #


class Opt():
    def __init__(self):
        self.parser = argparse.ArgumentParser()
        self.initialized = False

    def initialize(self):
        # Globals
        self.parser.add_argument('--erasePrevious', type=int, default=0, choices=[0, 1], help='1 to remove the existing --output_*_RootPath.')
        self.parser.add_argument('--useConfig', type=int, default=0, choices=[0, 1], help='1 to read inputs from .yaml config file. 0 to accept user input')
        self.parser.add_argument('--configFile', type=str, default="experiments/renderConfig/renderConfig.yaml", help='Path to the render config file. This is valid only when --useConfig is set to True')
        self.parser.add_argument('--renderImgs', type=int, default=1, choices=[0, 1], help='1 to render images from the .obj files. 0 to skip rendering')
        self.parser.add_argument('--startFrameNum', type=int, default=-1, help='Render starting from frame number. Index from 1')
        self.parser.add_argument('--endFrameNum', type=int, default=-1, help='Render ending frame number. Index from 1')
        self.parser.add_argument('--renderAllFrames', type=int, default=1, choices=[0, 1], help='1 to render all frames')

        # Video
        self.parser.add_argument('--makeVideos', type=int, default=0, choices=[0, 1], help='1 to make video. 0 to skip.')
        self.parser.add_argument('--outputVidRootPath', type=str, default="experiments/video", help='The root path of output video. This is valid only when --makeVideos is True')


        # Images
        self.parser.add_argument('--inputRootPath', type=str, default="experiments/simulation", help='The root path of input .obj files')
        self.parser.add_argument('--outputImgRootPath', type=str, default="experiments/rendering", help='The root path of output .png image sequences')
        self.parser.add_argument('--folderName', type=str, default="wind_debug", help='Input and output have the same folder name.')
        self.parser.add_argument('--objBaseName', type=str, default="wind_cloth_", help='Base name of the input .obj file.')


        # Render globals
        self.parser.add_argument('--renderEngine', type=str, default="blender", choices=['cycles', 'blender', 'differentiable'], help='The rendering engine to be used in Blender [eevee|cycles]')
        self.parser.add_argument('--imgType', type=str, default="PNG", choices=['PNG'], help='')
        self.parser.add_argument('--sampleRate', type=int, default=100, help='')

        # Render env setting
        self.parser.add_argument('--renderingResolution', type=int, default=224, choices=[224, 448], help='The rendering resolution')
        self.parser.add_argument('--renderingLampsRadius', type=float, default=3.2, help='Determines the radius of a sphere on which the cameras are going to be placed')
        self.parser.add_argument('--renderingNumLamps', type=int, default=14, help='the number of lamps to be used to shed light on an object during rendering')

        # Cloth
        self.parser.add_argument('--scale_cloth', type=list, default=[1, 1, 1], help='Scale size of cloth, should be [x, y, z]')
        self.parser.add_argument('--addMaterial', type=int, default=1, choices=[0, 1], help='1 to add material. 0 to use Blender default material.')


        # Obstacles
        self.parser.add_argument('--useObstacle', type=int, default=1, choices=[0, 1], help='1 to render the obstacle object')
        self.parser.add_argument('--obstacleFile', type=str, default="dataset/trialObjs/wind/model1.obj", help='Full path to the obstacle object')
        self.parser.add_argument('--scale_obs', type=list, default=[1, 1, 1], help='Scale size of the obstacle, should be [x, y, z]')
        self.parser.add_argument('--stimuliRotLimitDegree', type=float, default=89.9, help='Rotate the 3D shapes withing the range [-stimuliRotLimitDegree, +stimuliRotLimitDegree] when generating the stimuli. It is recommended not to change the value of this argument to more than 89.9 in case you decide to work with quaternions at some point')

        # Camera
        self.parser.add_argument('--camera_rotation', type=list, default=[0, 0, 0], help='Camera rotation, should be [rx, ry, rz]')
        self.parser.add_argument('--camera_location', type=list, default=[0, 0, 0], help='Camera location, should be [x, y, z]')

        self.initialized = True



    def parse(self):

        argv = sys.argv
        if "--" not in argv:
            argv = []
        else:
            argv = argv[argv.index("--") + 1:]


        if not self.initialized:
            self.initialize()

        self.opt = self.parser.parse_known_args(argv)[0]
    

        # Manipulate Paths
        if self.opt.inputRootPath[len(self.opt.inputRootPath)-1] != '/':
            self.opt.inputRootPath = self.opt.inputRootPath + '/'

        if self.opt.outputImgRootPath[len(self.opt.outputImgRootPath)-1] != '/':
            self.opt.outputImgRootPath = self.opt.outputImgRootPath + '/'

        if self.opt.outputVidRootPath[len(self.opt.outputVidRootPath)-1] != '/':
            self.opt.outputVidRootPath = self.opt.outputVidRootPath + '/'

        if self.opt.renderImgs:
            if self.opt.erasePrevious and fileExist(self.opt.outputImgRootPath):
                rm(self.opt.outputImgRootPath)
            if not fileExist(self.opt.outputImgRootPath):
                mkdirs(self.opt.outputImgRootPath)

        if self.opt.makeVideos:
            if self.opt.erasePrevious and fileExist(self.opt.outputVidRootPath):
                rm(self.opt.outputVidRootPath)
            if not fileExist(self.opt.outputVidRootPath):
                mkdirs(self.opt.outputVidRootPath)

        if self.opt.useConfig and not fileExist(self.opt.configFile):
            sys.exit('[Error] Config file does not exist: ' + self.opt.configFile)


        # Set input & output
        self.opt.inputFolder = os.path.join(self.opt.inputRootPath, self.opt.folderName)
        self.opt.outputImgFolder = os.path.join(self.opt.outputImgRootPath, self.opt.folderName)
        self.opt.outputVidFile = os.path.join(self.opt.outputVidRootPath, self.opt.folderName + '.mov')


        # Input check
        if self.opt.endFrameNum<=0 or self.opt.startFrameNum<=0 or self.opt.endFrameNum<self.opt.startFrameNum:
            self.opt.renderAllFrames = 1



        return self.opt


    def print_args(self):
        if not self.initialized:
            self.parse()

        print("------------------------------  Render Arguments  ------------------------------\n")
        if self.opt.useConfig:
            print("Config File:             " + self.opt.configFile);
        print("Input folder:            " + self.opt.inputFolder);
        print("Output image folder:         " + self.opt.outputImgFolder);


        if self.opt.renderAllFrames:
            print("Render frame range:                "+ "All")
        else:
            print("Render frame range:             "+ "[" + self.opt.startFrameNum + ' , ' + self.opt.endFrameNum + "]")


        if self.opt.makeVideos:
            print("Output video:            " + self.opt.outputVidFile);
        print("\n---------------------------------------------------------------------------------")


class Render():
    def __init__(self, opt):
        self.opt = opt


    def render_images(self):
        if self.opt.renderAllFrames:
            startFrameNum = 0
            endFrameNum = 200
        else:
            startFrameNum = self.opt.startFrameNum
            endFrameNum = self.opt.endFrameNum

        for i in range(startFrameNum, endFrameNum):
            input_file = os.path.join(self.opt.inputFolder, self.opt.objBaseName + str(i) + '.obj')            
            output_file = os.path.join(self.opt.outputImgFolder, self.opt.objBaseName + str(i) + '.png')

            imported_object = bpy.ops.import_scene.obj(filepath=input_file)

            num_object = len(bpy.context.selected_objects)

            if (num_object == 1):
                clothName = bpy.context.selected_objects[0].name
            elif (num_object == 2):
                clothName = bpy.context.selected_objects[0].name
                objName = bpy.context.selected_objects[1].name
                if clothName[0:5] != 'cloth':
                    clothName, objName = objName, clothName
            else:
                errorMessage="==> Error: More than 2 objects are imported..."
                sys.exit(errorMessage)

            # material: cloth
            if self.opt.addMaterial:
                cloth_mat = bpy.data.materials['Red']
            else:
                cloth_mat = bpy.data.materials['default']

            # material: obj
            if (num_object == 2):
                obj_mat = bpy.data.materials['default']

            bpy.data.objects[clothName].data.materials.append(cloth_mat)

            if (num_object == 2):
                bpy.data.objects[objName].data.materials.append(obj_mat)
        
            # resize
            bpy.data.objects[clothName].scale[0] = self.opt.scale_cloth[0]
            bpy.data.objects[clothName].scale[1] = self.opt.scale_cloth[1]
            bpy.data.objects[clothName].scale[2] = self.opt.scale_cloth[2]

        
            # render setting
            bpy.data.scenes["Scene"].render.image_settings.file_format = 'PNG'
            bpy.data.scenes["Scene"].render.filepath = output_file

            bpy.context.scene.cycles.samples = self.opt.sampleRate
            #bpy.context.user_preferences.system.compute_device_type = 'CUDA'
            #bpy.context.user_preferences.system.compute_device = 'CUDA_0'
            #bpy.context.scene.cycles.device = 'GPU'
            
            bpy.ops.render.render(write_still = 1)
        
            # remove the cloth mesh
            bpy.ops.object.delete(use_global = False)



if __name__ == "__main__":
    opt =  Opt()
    my_opt = opt.parse()
    ## Print args
    opt.print_args()
    my_render = Render(my_opt)
    my_render.render_images()