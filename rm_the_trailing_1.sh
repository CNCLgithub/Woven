#!/bin/sh -e

folder_name=$1
start_idx=1
total_n=60
tmp_dir="tmp"

tmp_out_dir=${folder_name}/${tmp_dir}
echo ${tmp_out_dir}
mkdir -p ${tmp_out_dir}

for i in $(seq $start_idx $total_n)
do
    for x in ${folder_name}/result_${folder_name}_1${i}_*; do
        x_name=${x##*/};                  #result_wind_1.0_0.03125_110_ball_1.0_2.0_43.h5-7-07-08-02
        first_half="result_${folder_name}_1${i}_"
        second_half=${x_name##*${first_half}};
        mv ${folder_name}/${first_half}${second_half} ${tmp_out_dir}/result_${folder_name}_${i}_${second_half}
        echo "${folder_name}/${first_half}${second_half} => ${folder_name}/result_${folder_name}_${i}_${second_half}"
    done
done

mv ${tmp_out_dir}/* ${folder_name}
rmdir ${tmp_out_dir}