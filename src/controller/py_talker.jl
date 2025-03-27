module PyTalker

using ..Constants

ENV["PYTHON"] = "venv/bin/python3"
ENV["PYCALL_JL_RUNTIME_PYTHON"] = "venv/bin/python3"

using PyCall


PY_DIR_PATH = BASE_PY_PATH

# ----------------------- FleX ----------------------- #
PY_FLEX_FILE_NAME = joinpath(BASE_PY_PATH, "main_simulate.py")

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


# ----------------------- For Depth-map ----------------------- #
PY_DEPTHMAP_PATH = joinpath(BASE_PY_PATH, "depth_map", "depth_map_o3d")
PY_DEPTHMAP_FILENAME = joinpath(PY_DEPTHMAP_PATH, "depth_map.py")

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


# ----------------------- For save_img ----------------------- #
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


export simulate_next_frame_flex, py_get_depth_map, py_save_img

end
