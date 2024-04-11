import json
import matplotlib.pyplot as plt
import numpy as np
from ast import literal_eval
import argparse
import os.path
import ffmpeg

parser = argparse.ArgumentParser(description='')
parser.add_argument('--cur_scene', type=str, default="2/drape_0.25_0.0078125", help='')
parser.add_argument('--mask_dir', type=str, default="mask_0", help='')
parser.add_argument('--make_vid', type=int, default=1, help='1 is true; 0 is false')
parser.add_argument('--n_max', type=int, default=198, help='')

args = parser.parse_args()
n_max=args.n_max
cur_scene = args.cur_scene
mask_dir = args.mask_dir



in_file_root_dir = "/home/wbi/Code/Z_Cloth_Project/a_github_cloth_gen/a_github_cloth_gen_model_open3d/library/"
in_out_root_dir = os.path.join(in_file_root_dir, cur_scene, mask_dir)

for n in range(1, n_max):
    in_file = os.path.join(in_out_root_dir, "julia_" + str(n) +".json")
    if not os.path.isfile(in_file):
        n_max=n-1
        break

    with open(in_file) as f:
            data = json.load(f)
    data= np.array(literal_eval(data))

    data = data.reshape(540, 540).astype(np.float64)
    out_file = os.path.join(in_out_root_dir, "julia_" + str(n) +".png")
    plt.imsave(out_file, data)



## Make_Vids
if args.make_vid:
    img_file_template=str(os.path.join(in_out_root_dir,"julia_%d.png"))

    out_file = str(os.path.join(in_out_root_dir, cur_scene.split('/')[-1] + ".mp4"))
    os.system("ffmpeg -framerate 24 -i " + img_file_template + " -c:v libx264 -r 30 -pix_fmt yuv420p " + out_file)
