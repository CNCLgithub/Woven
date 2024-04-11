#!/bin/bash
#SBATCH --job-name=cloth_gen2_dp_for_cnn
#SBATCH --partition=psych_gpu
#SBATCH --gres=gpu:1
#SBATCH --cpus-per-task=1
#SBATCH --mem=10G
#SBATCH --time=12:00:00
#SBATCH --array=0-0

pwd; hostname; date

gz_obs_root_dir='/gpfs/milgram/project/yildirim/wb338/gen_test2/depth_map_for_cnn/depth_map_o3d_for_cnn'
gz_objs_dir=$gz_obs_root_dir'/in'
gz_objs_out_dir=$gz_obs_root_dir'/out'
# cd "$( cd "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

all_gz_files=`ls $gz_objs_dir`

possibilities=()
for i in $all_gz_files; do
  if [[ -d $gz_objs_dir/$i ]]; then
    possibilities+=($i)
  fi
done


cur_gz_file=-1
idx_start=$((SLURM_ARRAY_TASK_ID*150))
# echo $idx_start
for iii in {0..150}; do
  cur_idx=$((idx_start+iii))
  cur_gz_file=${possibilities[$cur_idx]}
  # echo "[$cur_idx]: ${cur_gz_file}"

  if [[ ! -d $gz_objs_out_dir/$cur_gz_file ]]; then
    echo "[$cur_idx]: ${cur_gz_file}"
    ./run.sh python ./depth_map_for_cnn/depth_map_o3d_for_cnn/depth_map.py --cloth_in_obj_dir=$cur_gz_file && \
    rm -r ${gz_objs_dir}/${cur_gz_file} && \
    unlink ${gz_objs_dir}/${cur_gz_file}.tar.gz
  fi
  cur_gz_file=-1
done

date




# # remove all dirs
# all_folders=$(find . -mindepth 1  -type d)
# for i in $all_folders; do
#   rm -r $i
# done
