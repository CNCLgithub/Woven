module PyTalker

using ..Constants

# --- Set environment for PyCall to use the correct virtual Python environment --- #
ENV["PYTHON"] = "venv/bin/python3"
ENV["PYCALL_JL_RUNTIME_PYTHON"] = "venv/bin/python3"

using PyCall

# Base Python directory, shared across all scripts
PY_DIR_PATH = BASE_PY_PATH

# ===================== FleX Physics Simulation ===================== #
# Main Python script that performs one step of simulation in NVIDIA FleX

PY_FLEX_FILE_NAME = joinpath(BASE_PY_PATH, "main_simulate.py")

# Call the FleX physics simulation Python wrapper.
function simulate_next_frame_flex(arguments,
                                  py_dir_path::String=PY_DIR_PATH,
                                  py_file_path::String=PY_FLEX_FILE_NAME)
    py"""
    def call_flex_wrapper(py_dir, py_file_path, arguments):
        import sys, os
        os.environ['CALL_BY_JULIA'] = '1'
        os.chdir(py_dir)
        if py_dir not in sys.path:
            sys.path.append(py_dir)
        sys.argv = arguments
        exec(open(py_file_path).read())
    """

    call_flex_wrapper = py"call_flex_wrapper"
    call_flex_wrapper(py_dir_path, py_file_path, arguments)
end


# ===================== Depth Map Rendering ===================== #
# Python depth map rendering script using Open3D

PY_DEPTHMAP_PATH = joinpath(BASE_PY_PATH, "depth_map", "depth_map_o3d")
PY_DEPTHMAP_FILENAME = joinpath(PY_DEPTHMAP_PATH, "depth_map.py")

# Call the Python script that renders a depth map and returns it as a Float64 array.
function py_get_depth_map(arguments,
                          py_dir_path::String=PY_DEPTHMAP_PATH,
                          py_file_path::String=PY_DEPTHMAP_FILENAME)
    py"""
    def call_python_wrapper_with_return(py_dir, py_file_path, arguments):
        import sys, os
        import numpy as np
        os.environ['CALL_BY_JULIA'] = '1'
        os.chdir(py_dir)
        if py_dir not in sys.path:
            sys.path.append(py_dir)
        sys.argv = arguments
        exec(open(py_file_path).read(), globals())
        return (globals()['depth_map'])
    """

    call_python_wrapper_with_return = py"call_python_wrapper_with_return"
    depth_map = call_python_wrapper_with_return(py_dir_path, py_file_path, arguments)
    return depth_map::Array{Float64,1}
end


# ===================== Save Image Utility ===================== #
# Python script for saving visual images from depth maps

PY_SAVEIMG_PATH = joinpath(BASE_PY_PATH, "depth_map")
PY_SAVEIMG_FILENAME = joinpath(PY_SAVEIMG_PATH, "save_img.py")

function py_save_img(arguments,
                     py_dir_path::String=PY_SAVEIMG_PATH,
                     py_file_path::String=PY_SAVEIMG_FILENAME)
    py"""
    def call_python_wrapper_saveimg(py_dir, py_file_path, arguments):
        import sys, os
        import numpy as np
        os.environ['CALL_BY_JULIA'] = '1'
        os.chdir(py_dir)
        if py_dir not in sys.path:
            sys.path.append(py_dir)
        sys.argv = arguments
        exec(open(py_file_path).read())
    """
    call_python_wrapper_saveimg = py"call_python_wrapper_saveimg"
    call_python_wrapper_saveimg(py_dir_path, py_file_path, arguments)
end


# ===================== Export Functions ===================== #
export simulate_next_frame_flex, py_get_depth_map, py_save_img

end
