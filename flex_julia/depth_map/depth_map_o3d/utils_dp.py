#!/usr/bin/env python
# coding: utf-8

import os, sys
import numpy as np
import matplotlib.pyplot as plt
from scipy.spatial.transform import Rotation as R
from ast import literal_eval
import meshio
import open3d, cv2
from visualization import DepthMapOpen3D
import json, codecs
from skimage.transform import resize
from datetime import datetime

MASS_LIST = ["0.25", "0.5", "1.0", "2.0", "4.0"]
STIFF_LIST = ["0.0078125", "0.03125", "0.125", "0.5", "2.0"]
CUR_SCENE_DICT = {1: "wind", 2: "drape", 3: "ball", 4: "rotate"}

BB_SIZE_DICT = {}

# --------------------------------#
BB_SIZE_DICT[540] = {}
BB_SIZE_DICT[540][0] = {"wind":[469+20, 382+20, 10, 5], 
                        "drape":[540, 171+40, 0, 20], 
                        "ball":[275+40, 519+20, 40-10, 20-10],
                        "rotate":[473+20, 285+20, 18, 5]}

BB_SIZE_DICT[540][2] = {"wind":[469+20, 388+20, 10, 5], 
                        "drape":[540, 172+40, 0, 20], 
                        "ball":[284+40, 512+20, 40-10, 20-10],
                        "rotate":[475+20, 285+20, 18, 5]}

BB_SIZE_DICT[540][3] = {"wind":[469+20, 394+20, 10, 5], 
                        "drape":[540, 173+40, 0, 20], 
                        "ball":[290+40, 519+20, 40-10, 20-10],
                        "rotate":[475+20, 285+20, 18, 5]}

BB_SIZE_DICT[540][4] = {"wind":[469+20, 396+20, 10, 5], 
                        "drape":[540, 172+40, 0, 20], 
                        "ball":[295+40, 519+20, 40-10, 20-10],
                        "rotate":[479+20, 285+20, 18, 5]}

BB_SIZE_DICT[54] = {}
BB_SIZE_DICT[54][2] = {"ball":[0+4, 0+2, 4-1, 2-1]}

BLENDER_CAM = {"wind": {"intrinsic": [[590.625, 0.0, 269.5], 
                                      [0.0, 590.625, 269.5], 
                                      [0.0, 0.0, 1.0]],
                        "extrinsic": [[0.99998, 0.007, -0.0, -0.01913], 
                                      [-0.0, 0.0, -1.0, 1.43756], 
                                      [-0.007, 0.99998, 0.0, 3.20021], 
                                      [0.0, 0.0, 0.0, 1.0]],
                        "pos": [0.04153, -3.2, 1.43756],
                        "viewup": [0.0, 0.0, 1.0],
                        "dir": [-0.007, 0.99998, 0.0],
                        "focal_dis": 10,
                        "clipping_range": [0.1, 100.0],
                        "cloth_rot": [90, 0, 0],
                        "res": [540, 540],
                        "view_angle": 49.13434,
                        "min_distance":0,
                        "max_distance":5},
                "drape": {"intrinsic": [[590.625, 0.0, 269.5], 
                                        [0.0, 590.625, 269.5], 
                                        [0.0, 0.0, 1.0]],
                        "extrinsic": [[0.99998, 0.007, -0.0, -0.01913], 
                                      [0.00329, -0.47061, -0.88233, -0.2377], 
                                      [-0.00618, 0.88231, -0.47063, 3.5002], 
                                      [0.0, 0.0, 0.0, 1.0]],
                        "pos": [0.04153, -3.2, 1.43756],
                        "viewup": [-0.00329, 0.47061, 0.88233],
                        "dir": [-0.00618, 0.88231, -0.47063],
                        "focal_dis": 10,
                        "clipping_range": [0.1, 100.0],
                        "cloth_rot": [90, 0, 0],
                        "res": [540, 540],
                        "view_angle": 49.13434,
                        "min_distance":0,
                        "max_distance":5},
                "ball": {"intrinsic": [[590.625, 0.0, 269.5], 
                                       [0.0, 590.625, 269.5], 
                                       [0.0, 0.0, 1.0]],
                        "extrinsic": [[0.98481, 0.17365, -0.0, 0.40968], 
                                      [-0.0, 0.0, -1.0, 1.74844], 
                                      [-0.17365, 0.98481, 0.0, 3.48176], 
                                      [0.0, 0.0, 0.0, 1.0]],
                        "pos": [0.20114, -3.5, 1.74844],
                        "viewup": [0.0, -0.0, 1.0],
                        "dir": [-0.17365, 0.98481, 0.0],
                        "focal_dis": 10,
                        "clipping_range": [0.1, 100.0],
                        "cloth_rot": [90, 0, 0],
                        "res": [540, 540],
                        "view_angle": 49.13434,
                        "min_distance":0,
                        "max_distance":5},
                "rotate": {"intrinsic": [[590.625, 0.0, 269.5], 
                                         [0.0, 590.625, 269.5], 
                                         [0.0, 0.0, 1.0]],
                        "extrinsic": [[0.99998, 0.007, -0.0, -0.01913], 
                                      [0.00329, -0.47061, -0.88233, -0.2377], 
                                      [-0.00618, 0.88231, -0.47063, 3.5002], 
                                      [0.0,  0.0,  0.0,  1.0]],
                        "pos": [0.04153, -3.2, 1.43756],
                        "viewup": [-0.00329, 0.47061, 0.88233],
                        "dir": [-0.00618, 0.88231, -0.47063],
                        "focal_dis": 10,
                        "clipping_range": [0.1, 100.0],
                        "cloth_rot": [90, 0, 0],
                        "res": [540, 540],
                        "view_angle": 49.13434,
                        "min_distance":0,
                        "max_distance":5}
               }

def crop_fastest(arr):
    return cv2.boundingRect(cv2.findNonZero(arr))

def load_json(inpath):
    with open(inpath) as _:
        f = json.load(_)
    return f

def save_json(data, outpath):
    if isinstance(data, np.ndarray):
        json.dump(data.tolist(), codecs.open(outpath, 'w', encoding='utf-8'))
    else:        
        with open(outpath, 'w') as f:
            json.dump(data, f)
    return

def mkdir(path):
    if not os.path.exists(path):
        os.makedirs(path)

def to_np_array(data):
    if type(data) is np.ndarray:
        return data
    if type(data) is str:
        return np.array(literal_eval(data))
    sys.exit("Error[to_np_array]! Invalid type(data)={}".format(type(data)))


def get_depth_map(cur_scene_idx=2,
                  cloth_position=None,
                  mesh_or_points="mesh",
                  file_path=None,
                  file_mass=None,
                  file_stiff=None,
                  frame_t=None,
                  w=540,
                  h=540,
                  crop_with_bounding_box=0,
                  bb_x=None,
                  bb_y=None,
                  flow_mask_n=0,
                  save_depth_map=0,
                  return_type="dp",
                  debug=0):

    crop_with_bounding_box = bool(crop_with_bounding_box)
    bb_x = int(bb_x) if bb_x else bb_x
    bb_y = int(bb_y) if bb_y else bb_y
    save_depth_map = bool(save_depth_map)
    flow_mask_n = int(flow_mask_n)
    cur_scene_idx = int(cur_scene_idx)
    cur_scene = CUR_SCENE_DICT[cur_scene_idx]

    if debug:
        save_depth_map = bool(1)
        if cloth_position is None:
            sys.path.insert(0, './debug_data')
            test_v = __import__("test_v_" + cur_scene)
            cloth_position = test_v.V


    rot = R.from_euler('xyz', BLENDER_CAM[cur_scene]['cloth_rot'], degrees=True)
    rot = rot.as_matrix()
    if os.path.isfile(cloth_position):
        mesh = meshio.read(cloth_position)
        old_points = np.array(mesh.points)
    else:
        old_points = np.array(literal_eval(cloth_position))
        old_points_shape = old_points.shape
        if len(old_points_shape) == 1:
            old_points = old_points.reshape(-1, 3)
        elif len(old_points_shape) == 2 and old_points_shape[1] == 3:
            pass
        else:
            sys.exit("---Error[get_depth_map]: [--cloth_position] has wrong shape!")
    new_points = np.dot(rot, old_points.transpose())
    new_points = new_points.transpose()


    if mesh_or_points == "points" or mesh_or_points == "point":
        pcd = open3d.geometry.PointCloud()
        pcd.points = open3d.utility.Vector3dVector(new_points)
    elif mesh_or_points == "mesh":
        from debug_data.test_f import FACES as faces
        pcd = open3d.geometry.TriangleMesh()
        pcd.vertices = open3d.utility.Vector3dVector(new_points)
        pcd.triangles = open3d.utility.Vector3iVector(faces)
        pcd.compute_vertex_normals()
    else:
        sys.exit("---Error[get_depth_map]: Wrong value for [--mesh_or_points]!")


    CAM_WIDTH = BLENDER_CAM[cur_scene]['res'][0]
    CAM_HEIGHT = BLENDER_CAM[cur_scene]['res'][1]
    INTRINSIC = np.array(BLENDER_CAM[cur_scene]['intrinsic'])
    EXTRINSIC = np.array(BLENDER_CAM[cur_scene]['extrinsic'])
    IMG_SCALE = w*1.0/CAM_WIDTH

    vis = DepthMapOpen3D(img_width=CAM_WIDTH, img_height=CAM_HEIGHT, visible=False)
    vis.add_geometry(pcd)
    vis.update_view_point(INTRINSIC, EXTRINSIC)

    depth = vis.capture_depth_float_buffer(show=False)
    depth = np.array(depth)
    image = vis.capture_screen_float_buffer(show=False)
    image = np.asarray(image)

    if int(w) != int(h):
        sys.exit("---Error[get_depth_map]: depth_map width [-w] and height [-h] have to be the same!")
    if int(IMG_SCALE) != 1:
        depth = resize(depth, (h, w))
        image = resize(image, (h, w))

    if return_type == "img":
        depth = image
    elif return_type == "dp":
        pass
    else:
        sys.exit("---Error[get_depth_map]: invalid values for --return_type={} [img|dp]!".format(return_type))


    if crop_with_bounding_box:
        cur_scene_crop_w = BB_SIZE_DICT[w][flow_mask_n][cur_scene][0]
        cur_scene_crop_h = BB_SIZE_DICT[w][flow_mask_n][cur_scene][1]
        depth = depth[bb_y:(bb_y+cur_scene_crop_h), bb_x:(bb_x+cur_scene_crop_w)]
        
    if save_depth_map:
        if file_path:
            save_file_prefix = file_path.split('/')[-1]
            outdir = os.path.join("out", "observation")
        elif file_mass and file_stiff and frame_t:
            save_file_prefix = "{}_{}_{}".format(cur_scene, file_mass, file_stiff)
            outdir = os.path.join("out", str(frame_t))
        else:
            save_file_prefix = "DEBUG_" + datetime.now().strftime("%H:%M:%S") + "_"
            outdir = "out"
        mkdir(outdir)
        np.savetxt(os.path.join(outdir, "{}_old_points.txt".format(save_file_prefix)), old_points)

        img_fpth = os.path.join(outdir, "{}_img_{}_{}.png".format(save_file_prefix, cur_scene, w))
        depth_fpth = os.path.join(outdir, "{}_img_depth_{}_{}.png".format(save_file_prefix, cur_scene, w))

        if crop_with_bounding_box:
            img_fpth = "{}_img_{}_[{}-{}]_[{}-{}]_{}.png".format(save_file_prefix, cur_scene, 
                                                              bb_x, bb_x+cur_scene_crop_w,
                                                              bb_y, bb_y+cur_scene_crop_h,
                                                              str(datetime.now().strftime("%d-%m-%Y-%H:%M:%S")))
            img_fpth = os.path.join(outdir, img_fpth)

            depth_fpth = "{}_img_depth_{}_[{}-{}]_[{}-{}]_{}.png".format(save_file_prefix, cur_scene, 
                                                                      bb_x, bb_x+cur_scene_crop_w,
                                                                      bb_y, bb_y+cur_scene_crop_h,
                                                                      str(datetime.now().strftime("%d-%m-%Y-%H:%M:%S")))
            depth_fpth = os.path.join(outdir, depth_fpth)

        plt.imsave(img_fpth, image)
        plt.imsave(depth_fpth, depth)    

    depth = 255.0*(depth-depth.min())/(depth.max()-depth.min())
    return depth



def get_depth_map_observation(cur_scene_idx=2,
                              cloth_position_f="./",
                              mesh_or_points="mesh",
                              w=540,
                              h=540,
                              save_depth_map=0,
                              return_type="dp",
                              get_bounding_box=0):
    """
    Load pre-calculated raw depth-map .json file, generate the .json file if doesn't exist;
    Calculate the bounding box for each frame. Doesn't do the crop.

    Param:
    :cur_scene_idx              : 1|2|3|4
    :cloth_position_f           : full .obj file path. e.g., ../../../library/3/ball_0.25_0.0078125/ball_cloth_0.obj
    :mesh_or_points             : "mesh" | points"
    :return_type                : "img"|"dp"
    :get_bounding_box           : 1 to crop the depth img | 0 to return the raw depth img
    
    """

    cloth_position_f_ls = cloth_position_f.split('/')
    depth_f_dir = "/".join(cloth_position_f_ls[0:-1])
    depth_f_name = cloth_position_f_ls[-1].split(".")[0]
    depth_img_f = os.path.join(depth_f_dir, "{}_{}_{}.json".format(depth_f_name, w, mesh_or_points))
    print(depth_img_f)

    if os.path.isfile(depth_img_f):
        with open(depth_img_f) as f:
            raw_depth = np.array(json.load(f))
            raw_depth = raw_depth.reshape(h, w)
    else:
        raw_depth = get_depth_map(cur_scene_idx=cur_scene_idx,
                                  cloth_position=cloth_position_f,
                                  mesh_or_points=mesh_or_points,
                                  w=w, 
                                  h=h,
                                  return_type=return_type,
                                  crop_with_bounding_box=0,
                                  save_depth_map=save_depth_map)
        raw_depth_list = raw_depth.tolist()
        raw_depth_list = [item for sublist in raw_depth_list for item in sublist]
        save_json(data=raw_depth_list, outpath=depth_img_f)


    x_box, y_box, w_box, h_box = -1, -1, -1, -1
    if get_bounding_box:
        x_box, y_box, w_box, h_box = crop_fastest(raw_depth)
        if x_box < 0 or y_box < 0 or w_box < 0 or h_box < 0:
            sys.exit("---Error[get_depth_map_observation]: Wrong bounding box for for {}!".format(depth_f_name))

    return raw_depth, x_box, y_box, w_box, h_box