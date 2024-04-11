#!/bin/bash
#SBATCH --job-name=setup_depth_map_for_obs
#SBATCH --partition=psych_gpu
#SBATCH --gres=gpu:1
#SBATCH --cpus-per-task=1
#SBATCH --mem=5G
#SBATCH --time=2-00:00:00
#SBATCH --mail-user=wenyan.bi@yale.edu
#SBATCH --mail-type=ALL
##SBATCH --output=job_%A.log
#SBATCH --output=job_%A_%a.out
#SBATCH --array=0-3

pwd; hostname; date
scenarios=("wind" "drape" "ball" "rotate")

possibilities=()
for i in ${!scenarios[@]}; do
      position=$(( $i + 1 ))
      possibilities+=("$position")
done

./run.sh python flex_julia/depth_map/depth_map_o3d/depth_map_with_bb_obs_preprocess.py --cur_scene_idx=${possibilities[$SLURM_ARRAY_TASK_ID]}

date
