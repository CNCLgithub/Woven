usage="Syntax: $(basename "$0") [-h|--help] [COMPONENTS...] -- will make video from image sequences
where:
    -h | --help     Print this help
    COMPONENTS...   Specify component to set up

Valid COMPONENTS:
    wind:
    drape:
    ball:
    rotate:
    "


if [[ $# -eq 0 ]] || [[ "$@" =~ "--help" ]] || [[ "$@" =~ "-h" ]];then
    echo "$usage"
    exit 0
fi



scene="${@}"

# Rename
cd flex_julia/depth_map/depth_map_o3d/out/observation

for file_name in *obj_img_depth_${scene}.png
do
    new_file_name=${file_name%*.obj_img_depth_${scene}*}.png
    mv "$file_name" "$new_file_name";
done

# Make vids
ffmpeg -framerate 24 -i ${scene}_cloth_%d.png -c:v libx264 -r 30 -pix_fmt yuv420p ${scene}.mp4

cd -