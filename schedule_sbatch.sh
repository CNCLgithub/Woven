#!/bin/bash
#SBATCH --job-name=stiff
#SBATCH --partition=gpu
#SBATCH --gres=gpu:1
#SBATCH --cpus-per-task=1
#SBATCH --mem=7G
#SBATCH --time=2:30:00
#SBATCH --mail-user=wenyan.bi@yale.edu
#SBATCH --mail-type=ALL
##SBATCH --output=job_%A.log
#SBATCH --output=job_%A_%a.out
#SBATCH --array=0-80


pwd; hostname; date
exp_cond='stiff'   #stiff|mass
debug=1
#SLURM_ARRAY_TASK_ID=$1 # debug purpose
#SLURM_ARRAY_JOB_ID=$1
echo $SLURM_ARRAY_JOB_ID $SLURM_ARRAY_TASK_ID

## =================== [wb] : Create dicts for scenes (e.g., wind -> 1) ====================
scenarios=("wind" "drape" "ball" "rotate")
masses=(0.25 0.5 1.0 2.0)
stiffnesses=(0.0078125 0.03125 0.125 0.5 2.0)
declare -A scene_idx_dicts

for i in ${!scenarios[@]}; do
  scene_idx_dicts[${scenarios[$i]}]="$(( $i + 1 ))"
done

if [[ debug ]]; then
  echo " "
  echo "============== debug: scene_idx_dicts =============="
  for tmp in "${!scene_idx_dicts[@]}"; do echo "$tmp -> ${scene_idx_dicts[$tmp]}"; done
  echo "===================================================="
fi

## =================== [wb] : Create dicts for possibilities ====================
possibilities=()
for i in ${!scenarios[@]}; do
  for stiffness in "${!stiffnesses[@]}"; do
    for mass in "${!masses[@]}"; do
      # position=$(( $i + 1 ))
      possibilities+=("${scenarios[$i]}_${masses[$mass]}_${stiffnesses[$stiffness]}")
    done
  done
done

## =================== [wb] : Read from csv files ====================
## [wb]: remove already saved files
csv_file="cond_file/${exp_cond}/${exp_cond}_${possibilities[$SLURM_ARRAY_TASK_ID]}.csv"
./run.sh python check_h5_exist_files.py --h5_path=${csv_file}
csv_file="cond_file/${exp_cond}/${exp_cond}_${possibilities[$SLURM_ARRAY_TASK_ID]}_checked_h5.csv"


target=($(tail -n +1 ${csv_file} | awk -F ',' '{print $1;}'))
prior=($(tail -n +1 ${csv_file} | awk -F ',' '{print $2;}'))
prior_model_idx=($(tail -n +1 ${csv_file} | awk -F ',' '{print $3;}'))
prior_mass=($(tail -n +1 ${csv_file} | awk -F ',' '{print $5;}'))
prior_stiff=($(tail -n +1 ${csv_file} | awk -F ',' '{print $7;}'))
prior_w=($(tail -n +1 ${csv_file} | awk -F ',' '{print $9;}'))

total_len=${#target[@]}
total_len=$(( $total_len - 1 ))

#[wb]: Get cur_scene
cur_cloth_scene_mass_bs=${target[1]}   ##### For the same cond file, the "cur_cloth_scene_mass_bs" are the same
IFS='_' read -r -a array <<< "$cur_cloth_scene_mass_bs"
cur_scene="${array[0]}"


if [[ debug -eq 1 ]]; then
  echo " "
  echo "=============== debug: ========================================================"
  echo "[@] [Cur_exp_cond]         -> ${exp_cond}"
  echo "[@] [Cond_file]            -> ${csv_file}"
  echo "[@] [Total_len]            -> ${total_len}"
  echo "[@] [Cur_infer_cloth]      -> ${scene_idx_dicts[$cur_scene]}/${cur_cloth_scene_mass_bs}"
  echo "[@] -------------------------------------------------"
  echo "==============================================================================="
fi


cur_idx=0

while [ $cur_idx -le $total_len ]; do

  #-------------------------------------------------------------------------------------------
  cur_idx=$(( $cur_idx + 1 ))
  if [[ debug -eq 1 ]]; then
    echo " "
    echo "=============== debug: ========================================================"
    echo "[@] [line_num]             -> ${cur_idx}"
    echo "[@] [prior_cloth]          -> ${prior[$cur_idx]}"
    echo "[@] [prior_model_idx]      -> ${prior_model_idx[$cur_idx]}"
    echo "[@] [prior_mass_prior]     -> ${prior_mass[$cur_idx]}"
    echo "[@] [prior_bs_prior]       -> ${prior_stiff[$cur_idx]}"
    echo "[@] [prior_w]              -> ${prior_w[$cur_idx]}"
    echo "==============================================================================="
  fi
  ./run.sh julia src/exp_basic.jl ${scene_idx_dicts[$cur_scene]}/${cur_cloth_scene_mass_bs} \
                            ${exp_cond} \
                            ${cur_idx}_${prior[$cur_idx]}_${prior_model_idx[$cur_idx]} \
                            ${prior_mass[$cur_idx]} \
                            ${prior_stiff[$cur_idx]} \
                            ${prior_w[$cur_idx]} \
                            ${SLURM_ARRAY_JOB_ID}
done


# for i in $(seq 1 $total_len); do
#   cur_idx=$(( $i + 0 ))
