from utils import mkdirs, savePickle, fileExist, rm
import os, sys
import subprocess, argparse, copy

"""
#############################################################################################
Script Name                : main_render.py
Run                        : python main_render.py --blenderBin=experiments/obj2mov/blender-2.79a-linux64/blender \
                                --blenderFile=experiments/obj2mov/wind.blend --outputError=0
Description                : Main code for render images and make videos from .obj file.
Usage                      : main_render.py --blenderBin=str --blenderFile=BLENDERFILE --outputError=True|False[--obj2mov.py args]
                                the first 3 args are required.
Author                     : Wenyan Bi <wenyan.bi@yale.edu>
Date                       : 15/08/2020
Notes                      : 1) proc.stderr.readline() with subprocess.PIPE will fall into deadlock,
                                thus this script can't print stderr in realtime. 
                                When --outputError=1, it uses proc.communicate() to print stderr afterwards.
#################################################################################################
"""


def run(
    cmd,
    outputError=0
    ):
    
    proc = subprocess.Popen(
        cmd,
        stdout = subprocess.PIPE,
        stderr = subprocess.PIPE,
        shell=True)

    if outputError:
        stdout, stderr = proc.communicate()
        stdout = stdout.decode("ascii").rstrip()
        stderr = stderr.decode("ascii").rstrip()
        print(stderr)
    else:
        stdout = []
        stderr = []
        while proc.poll() is None:
            line = proc.stdout.readline().decode("ascii").rstrip()
            if line != "":
                print(line)

    return proc.returncode, stdout, stderr



if __name__ == "__main__":
    argv = sys.argv

    if "=" in argv or '' in argv:
        print(argv[0] + ': error: There should not be space around "=" in arguments')
        sys.exit(1)

    if len(argv) < 4:
        print('Usage: python' + argv[0] + '--blenderBin=BlENDERPATH --blenderFile=BLENDERFILE --outputError=0|1 [--obj2mov.py args]')
        print (argv[0] + ': error: missing required arguments.')
        sys.exit(1)

    blender_bin = argv[1].split('=')
    if len(blender_bin) != 2 or blender_bin[0] != '--blenderBin' or not blender_bin[1]:
        print('Usage: python' + argv[0] + '--blenderBin=BlENDERPATH --blenderFile=BLENDERFILE --outputError=0|1 [--obj2mov.py args]')
        print (argv[0] + ': error: missing required arguments: --blenderBin=str')
        sys.exit(1)        

    blender_file = argv[2].split('=')
    if len(blender_file) != 2 or blender_file[0] != '--blenderFile' or not blender_file[1]:
        print('Usage: python' + argv[0] + '--blenderBin=BlENDERPATH --blenderFile=BLENDERFILE --outputError=0|1 [--obj2mov.py args]')
        print (argv[0] + ': error: missing required arguments: --blenderFile=str')
        sys.exit(1)

    outputError = argv[3].split('=')
    if len(outputError) != 2 or outputError[0] != '--outputError' or not outputError[1]:
        print('Usage: python' + argv[0] + '--blenderBin=BlENDERPATH --blenderFile=BLENDERFILE --outputError=0|1 [--obj2mov.py args]')
        print (argv[0] + ': error: missing required arguments: --outputError=True|False')
        sys.exit(1)

    argv_obj2mov = " ".join(argv[4:])

    cmd = [blender_bin[1] + " -b -noaudio " +  blender_file[1] + " --python obj2mov.py -- " + argv_obj2mov]
    returncode, stdout, stderr = run(cmd, outputError=int(outputError[1]))