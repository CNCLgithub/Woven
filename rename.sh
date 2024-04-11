#!/bin/sh -e

folder_name=$1
old_idx=$2
new_idx=$3
total_n=$4

# for file in ${folder_name}/*_${old_idx}.h5;
#     do [ -f "$file" ] || continue; 
#     name=${file##*/}; base=${name%_${old_idx}.h5};
#     mv ${folder_name}/$name ${folder_name}/${base}_${new_idx}.h5;
# done;


for i in $(seq 0 $total_n)
do
    echo "old_idx -> 1${old_idx}"
    echo "new_idx -> 1${new_idx}"
    for x in ${folder_name}/result_${folder_name}_1${old_idx}*; do
        x_name=${x##*/};                  #result_wind_1.0_0.03125_110_ball_1.0_2.0_43.h5-7-07-08-02
        first_half="result_${folder_name}_1${old_idx}_"
        second_half=${x_name##*${first_half}}; 
        mv ${folder_name}/${first_half}${second_half} ${folder_name}/result_${folder_name}_1${new_idx}_${second_half}
        echo "${first_half}${second_half} => result_${folder_name}_1${new_idx}_${second_half}"
    done
    old_idx=$((old_idx+1))
    new_idx=$((new_idx+1))
done