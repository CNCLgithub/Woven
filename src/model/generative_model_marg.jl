using Dates
import Base.@kwdef

# Exported Symbols
export ConfigParams, StateSpace, default_config_params, gm_cloth
export DEPTH_MAP_VAR, MASS_VAR_SMALL, MASS_VAR_LARGE, MASS_BERNOULLI,
STIFF_VAR_SMALL, STIFF_VAR_LARGE, STIFF_BERNOULLI


# -------------------- Simulation Hyperparameters --------------------

# Configuration container for running a simulation experiment
@kwdef struct ConfigParams
    sim_num::Int64              # Scenario type (e.g., 1=wind, 2=drape, 3=ball, 4=rotate)
    time_interval::Float64      # Physics time step (e.g., 1/60 sec)
    extention::String           # Output path tag
    cloth_width::Int64          # Width of the cloth (mesh grid)
    cloth_height::Int64         # Height of the cloth
    mass_min::Float64           # Min range for sampling cloth mass
    mass_max::Float64           # Max range for sampling cloth mass
    stiffness_min::Float64      # Min range for sampling stiffness
    stiffness_max::Float64      # Max range for sampling stiffness
    ext_force_min::Float64      # Min range for sampling external force
    ext_force_max::Float64      # Max range for sampling external force
    total_masks::Int64          # Number of flow masks (i.e., depth frames per observation)
    init_frame_num::Int64       # Index for first frame in the sequence
end

# Default configuration
const default_config_params = ConfigParams(sim_num=1,
                                           time_interval=0.0166667,
                                           extention="",
                                           cloth_width=105,
                                           cloth_height=105,
                                           mass_min=0.002,
                                           mass_max=5.0,
                                           stiffness_min=0.003,
                                           stiffness_max=2.5,
                                           ext_force_min=0.0,
                                           ext_force_max=6.0,
                                           total_masks=-1,
                                           init_frame_num=1)

# -------------------- Latent State Representation --------------------
# Defines the full state of the simulated system at a timestep
@kwdef struct StateSpace
    cloth_pos::Array{Array{Float64, 1}, 1}
    cloth_vel::Array{Array{Float64, 1}, 1}
    object_pos::Array{Array{Float64, 1}, 1}
    object_vel::Array{Array{Float64, 1}, 1}
    depth_map_simulated::Array{Float64, 1}
    cloth_mass::Float64
    cloth_stiffness::Float64
    ext_force::Float64
end

# -------------------- Parameter Settings --------------------
MASS_VAR_SMALL = 0.04
MASS_VAR_LARGE = 0.8
MASS_BERNOULLI = 0.8

STIFF_VAR_SMALL = 0.02
STIFF_VAR_LARGE = 0.4
STIFF_BERNOULLI = 0.8

DEPTH_MAP_VAR = 8
WIND_VAR = 0.3

get_var_value_stiffness() = bernoulli(STIFF_BERNOULLI) ? STIFF_VAR_SMALL : STIFF_VAR_LARGE
get_var_value(rm_var::Float64, var_small::Float64, var_large::Float64) = bernoulli(rm_var) ? var_small : var_large
my_print(my_array::Array{Float64, 1}) = println(my_array)

# -------------------- Generative Model: Initial State --------------------
@gen (static) function sample_init_state(cloth_pos::Array{Array{Float64, 1}, 1},
                                         cloth_vel::Array{Array{Float64, 1}, 1},
                                         object_pos::Array{Array{Float64, 1}, 1},
                                         object_vel::Array{Array{Float64, 1}, 1},
                                         init_depth_map::Array{Float64, 1},
                                         cloth_mass_prior::Array{Float64, 1},
                                         cloth_bs_prior::Array{Float64, 1},
                                         cloth_prior_w::Array{Float64, 1},
                                         cparam::ConfigParams)
    # Sample latent physical parameters
    cloth_mass = cloth_mass_prior[categorical(cloth_prior_w)]
    cloth_stiffness = cloth_bs_prior[categorical(cloth_prior_w)]
    # Sample depth map as observation
    depth_map_simulated = @trace(broadcasted_normal(init_depth_map, [DEPTH_MAP_VAR]), :cloth_depth_map)
    ext_force = @trace(uniform(cparam.ext_force_min, cparam.ext_force_max), :ext_force)

    state = StateSpace(cloth_pos, cloth_vel,
                       object_pos, object_vel,
                       depth_map_simulated,
                       cloth_mass, cloth_stiffness,
                       ext_force)
    return state
end


# -------------------- Generative Model: Dynamics Kernel --------------------
@gen (static) function cloth_kernel_rand_walk(t::Int, prev_state::StateSpace, bb_map::Dict, cparam::ConfigParams)

    new_mass = prev_state.cloth_mass

    stiffness = prev_state.cloth_stiffness
    # Sample new latent values via random walk
    stiffness_var_value = get_var_value_stiffness()
    stiffness_boundary = Float64[cparam.stiffness_min, cparam.stiffness_max]
    new_stiffness = @trace(truncated_normal(stiffness, stiffness_var_value, stiffness_boundary), :cloth_stiffness)
    
    ext_force = prev_state.ext_force
    ext_force_var_value = WIND_VAR
    ext_force_boundary = Float64[cparam.ext_force_min, cparam.ext_force_max]
    new_ext_force = @trace(truncated_normal(ext_force, ext_force_var_value, ext_force_boundary), :ext_force)

    # ------------ CLOTH STATE ----------------
    prev_cloth_pos = prev_state.cloth_pos
    prev_cloth_vel = prev_state.cloth_vel
    prev_object_pos = prev_state.object_pos
    prev_object_vel = prev_state.object_vel
    prev_depth_map_simulated = prev_state.depth_map_simulated

    new_cloth_pos = Array{Array{Float64, 1}, 1}[]
    new_cloth_vel = Array{Array{Float64, 1}, 1}[]
    new_object_pos = Array{Array{Float64, 1}, 1}[]
    new_object_vel = Array{Array{Float64, 1}, 1}[]
    new_depth_map_simulated = Array{Float64, 1}[]
    # ------------------------------------------
    
    # Propagate simulation forward
    t_for_flex = t*(cparam.total_masks+1) + cparam.init_frame_num - 1
    bb_map_cur_time = bb_map[t]

    new_cloth_pos, new_cloth_vel,
    new_object_pos, new_object_vel,
    new_depth_map_simulated,
    t_for_flex_after_fm = get_simulated_data_after_n_frame(prev_cloth_pos,
                                                           prev_cloth_vel,
                                                           prev_object_pos,
                                                           prev_object_vel,
                                                           new_mass,
                                                           new_stiffness,
                                                           new_ext_force,
                                                           cparam.sim_num,
                                                           t,
                                                           t_for_flex,
                                                           cparam.time_interval,
                                                           cparam.extention,
                                                           cparam.total_masks,
                                                           bb_map_cur_time)

    # Post-process depth map: aggregate over flow masks and inject observation noise
    new_depth_map_simulated_size = Int(length(new_depth_map_simulated)/(cparam.total_masks+1))
    new_summed_depth_map_simulated = get_weighted_depth_map_mask(new_depth_map_simulated, new_depth_map_simulated_size)
    new_summed_depth_map_simulated_rw = @trace(broadcasted_normal(new_summed_depth_map_simulated, [DEPTH_MAP_VAR]), :cloth_depth_map)

    state = StateSpace(new_cloth_pos, new_cloth_vel,
                       new_object_pos, new_object_vel,
                       new_summed_depth_map_simulated,
                       new_mass, new_stiffness, new_ext_force)
    return state
end

# Wrap kernel in unfold for unrolling across T steps
kernel_random_walk = Gen.Unfold(cloth_kernel_rand_walk)


# -------------------- Full Generative Model --------------------
@gen (static) function gm_cloth(T::Int,
                       cloth_pos::Array{Array{Float64, 1}, 1},
                       cloth_vel::Array{Array{Float64, 1}, 1},
                       object_pos::Array{Array{Float64, 1}, 1},
                       object_vel::Array{Array{Float64, 1}, 1},
                       init_depth_map::Array{Float64, 1},
                       bb_map::Dict,
                       cloth_mass_prior::Array{Float64, 1},
                       cloth_bs_prior::Array{Float64, 1},
                       cloth_prior_w::Array{Float64, 1},
                       cparam::ConfigParams)

    init_state = @trace(sample_init_state(cloth_pos, cloth_vel,
                                          object_pos, object_vel,
                                          init_depth_map, cloth_mass_prior,
                                          cloth_bs_prior, cloth_prior_w, cparam), :init_state)

    states = @trace(kernel_random_walk(T, init_state, bb_map, cparam), :kernel)
    return states
end
