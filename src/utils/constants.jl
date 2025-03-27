module Constants

export CUR_SCENE_MASS_STIFF_COMB, JOB_ID, TOTAL_INFER_ITERATIONS,
       PRIOR_CLOTH, EXP_COND, EXT_FOR_CUR_JOB
export BASE_DIR_PATH, BASE_LIB_PATH, BASE_PY_PATH, RESULTS_PATH,
       FLEX_SIM_PATH, DP_PATH,
       TIME_INTERVAL, BALL_SCENARIO_START_INDEX, DEPTH_MAP_CONFIG

CUR_SCENE_MASS_STIFF_COMB = "wind_2.0_2.0"
JOB_ID = "00000000"
TOTAL_INFER_ITERATIONS = 0
PRIOR_CLOTH = "0_drape_0.0_0.0_0"
EXP_COND = "mass_or_stiff"
EXT_FOR_CUR_JOB = "00000000"

const BASE_DIR_PATH = joinpath(dirname(dirname(dirname(@__FILE__))))
const BASE_LIB_PATH = joinpath(BASE_DIR_PATH, "library")
const BASE_PY_PATH = joinpath(BASE_DIR_PATH, "flex_julia")
const RESULTS_PATH = joinpath(BASE_DIR_PATH, "out")
const FLEX_SIM_PATH = joinpath(BASE_PY_PATH, "experiments", "simulation")
const DP_PATH = joinpath(BASE_PY_PATH, "depth_map", "depth_map_o3d")
const TIME_INTERVAL = 0.0166667
const BALL_SCENARIO_START_INDEX = 54
const DEPTH_MAP_CONFIG = (;img_w=540,
                           img_h=540,
                           mesh_or_points="mesh",
                           weight_decay="linear",
                           crop_with_bb=1,
                           save_dp=0,
                           debug_dp=false,
                           debug_stiff=false,
                           debug_mass_val=1.0,
                           debug_stiff_val=0.125,
                           debug_dp_root_folder=joinpath(BASE_DIR_PATH, "depth_map", "julia_debug"),
                           debug_dp_julia_folder=joinpath(DP_PATH, "out"))


## Create necessary folders
(DEPTH_MAP_CONFIG.debug_dp) && (mkpath(DEPTH_MAP_CONFIG.debug_dp_julia_folder))

end
