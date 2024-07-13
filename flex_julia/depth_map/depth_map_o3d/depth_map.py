#!/usr/bin/env python

# coding: utf-8
import os, sys, argparse
import numpy as np
from utils_dp import MASS_LIST, STIFF_LIST, CUR_SCENE_DICT, BLENDER_CAM, mkdir, get_depth_map

parser = argparse.ArgumentParser(description='')
parser.add_argument('--cur_scene_idx', type=int, default=1, help='wind=1|drape=2|ball=3|rotate=4')
parser.add_argument('--cloth_position', type=str, default=None, help='input cloth positions, or .obj file path')
parser.add_argument('--mesh_or_points', type=str, default="mesh", help='mesh|points')
parser.add_argument('--file_path', type=str, default=None, help='for saving purpose(observation)')
parser.add_argument('--file_mass', type=str, default=None, help='for saving purpose(simulation)')
parser.add_argument('--file_stiff', type=str, default=None, help='for saving purpose(simulation)')
parser.add_argument('--frame_t', type=str, default=None, help='for saving purpose(simulation)')
parser.add_argument('--img_w', type=int, default=540, help='width of the depth map')
parser.add_argument('--img_h', type=int, default=540, help='height of the depth map')
parser.add_argument('--crop_with_bounding_box', type=int, default=0, help='1 to crop the img image')
parser.add_argument('--bb_x', type=int, default=0, help='valid only when crop_with_bounding_box=1')
parser.add_argument('--bb_y', type=int, default=0, help='valid only when crop_with_bounding_box=1')
parser.add_argument('--flow_mask_n', type=int, default=0, help='num of flow mask; total img num is flow_mask_n+1')
parser.add_argument('--save_depth_map', type=int, default=1, help='1 to save depth-map img; 0 to disable')
parser.add_argument('--debug', type=int, default=0, help='1 to print debug message')
parser.add_argument('--add_noise', type=int, default=0, help='1 to add noises to background')
parser.add_argument('--ll_func', type=str, default="px_dp", help='px_dp|px_img|fc1_dp|fc1_img')
args = parser.parse_args() if os.getenv('CALL_BY_JULIA') is None else parser.parse_args(sys.argv)

ll_func = args.ll_func
ll_func = ll_func.split("_")
likelihood_feature = ll_func[0]
likelihood_use_dp_or_img = ll_func[1]

depth_map = get_depth_map(cur_scene_idx=args.cur_scene_idx,
                          cloth_position=args.cloth_position,
                          mesh_or_points=args.mesh_or_points,
                          file_path=args.file_path,
                          file_mass=args.file_mass,
                          file_stiff=args.file_stiff,
                          frame_t=args.frame_t,
                          w=args.img_w,
                          h=args.img_h,
                          crop_with_bounding_box=args.crop_with_bounding_box,
                          bb_x=args.bb_x,
                          bb_y=args.bb_y,
                          flow_mask_n=args.flow_mask_n,
                          save_depth_map=args.save_depth_map,
                          return_type=likelihood_use_dp_or_img,
                          debug=args.debug)

depth_map = depth_map.tolist()
depth_map = [item for sublist in depth_map for item in sublist]