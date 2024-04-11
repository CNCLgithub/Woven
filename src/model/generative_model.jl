using Dates
import Base.@kwdef
export ConfigParams, StateSpace, default_config_params, gm_cloth
export DEPTH_MAP_VAR, MASS_VAR_SMALL, MASS_VAR_LARGE, MASS_BERNOULLI,
STIFF_VAR_SMALL, STIFF_VAR_LARGE, STIFF_BERNOULLI

@kwdef struct ConfigParams
    sim_num::Int64  # simulation number (wind, drape etc.)
    time_interval::Float64
    extention::String
    cloth_width::Int64
    cloth_height::Int64
    mass_min::Float64
    mass_max::Float64
    stiffness_min::Float64
    stiffness_max::Float64
    ext_force_min::Float64
    ext_force_max::Float64
    total_masks::Int64
    init_frame_num::Int64
end
const default_config_params = ConfigParams(sim_num=1,
                                           time_interval=0.0166667,
                                           extention="",
                                           cloth_width=105,
                                           cloth_height=105,
                                           mass_min=0.002,
                                           mass_max=5.0,
                                           stiffness_min=0.003,
                                           stiffness_max=2.5,
                                           ext_force_min=1.0,
                                           ext_force_max=1.0,
                                           total_masks=-1,
                                           init_frame_num=1)

@kwdef struct StateSpace
    cloth_pos::Array{Array{Float64, 1}, 1}
    cloth_vel::Array{Array{Float64, 1}, 1}
    object_pos::Array{Array{Float64, 1}, 1}
    object_vel::Array{Array{Float64, 1}, 1}
    depth_map_simulated::Array{Float64, 1}
    cloth_mass::Float64
    cloth_stiffness::Float64
    external_force::Float64
end


## Noises in random walk paras mass & stiff
# mass: 0.1; stiff: Bern(0.9)
MASS_VAR_SMALL = 0.04   #0.04
MASS_VAR_LARGE = 0.8    #0.8
MASS_BERNOULLI = 0.8    #0.8

STIFF_VAR_SMALL = 0.02  #0.02
STIFF_VAR_LARGE = 0.4   #0.4
STIFF_BERNOULLI = 0.8

# observation noise
DEPTH_MAP_VAR = 8

get_var_value_stiffness() = bernoulli(STIFF_BERNOULLI) ? STIFF_VAR_SMALL : STIFF_VAR_LARGE
get_var_value(rm_var::Float64, var_small::Float64, var_large::Float64) = bernoulli(rm_var) ? var_small : var_large
my_print(my_array::Array{Float64, 1}) = println(my_array)

@gen (static) function sample_init_state(cloth_pos::Array{Array{Float64, 1}, 1},
                                         cloth_vel::Array{Array{Float64, 1}, 1},
                                         object_pos::Array{Array{Float64, 1}, 1},
                                         object_vel::Array{Array{Float64, 1}, 1},
                                         init_depth_map::Array{Float64, 1},
                                         cloth_mass_prior::Array{Float64, 1},
                                         cloth_bs_prior::Array{Float64, 1},
                                         cloth_prior_w::Array{Float64, 1},
                                         cparam::ConfigParams)
    cloth_mass = cloth_mass_prior[categorical(cloth_prior_w)]
    cloth_stiffness = cloth_bs_prior[categorical(cloth_prior_w)]
#     cloth_stiffness = @trace(uniform(cparam.stiffness_min, cparam.stiffness_max), :cloth_stiffness)
    depth_map_simulated = @trace(broadcasted_normal(init_depth_map, [DEPTH_MAP_VAR]), :cloth_depth_map)

    state = StateSpace(cloth_pos, cloth_vel,
                       object_pos, object_vel,
                       depth_map_simulated,
                       cloth_mass, cloth_stiffness,
                       cparam.ext_force_min)
    return state
end





# we define a generative function (kernel) that takes the prevous state as its second argument,
#   and returns the new state. The Unfold combinator takes the kernel and returns a new generative
#   function (chain) that applies kernel repeatedly.
@gen (static) function cloth_kernel_rand_walk(t::Int, prev_state::StateSpace, bb_map::Dict, cparam::ConfigParams)

    # ---------------------------- LATENT RANDOM WALK ---------------------------------
    ext_force = prev_state.external_force
    new_mass = prev_state.cloth_mass

    stiffness = prev_state.cloth_stiffness
    # [wb]: random walk
    stiffness_var_value = get_var_value_stiffness()
    #stiffness_var_value = STIFF_VAR_SMALL
    stiffness_boundary = Float64[cparam.stiffness_min, cparam.stiffness_max]
    new_stiffness = @trace(truncated_normal(stiffness, stiffness_var_value, stiffness_boundary), :cloth_stiffness)

    # ---------------------------- CLOTH STATE ---------------------------------
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
    # --------------------------------------------------------------------------
    # update the state via the flex engine
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
                                                           ext_force,
                                                           cparam.sim_num,
                                                           t,
                                                           t_for_flex,
                                                           cparam.time_interval,
                                                           cparam.extention,
                                                           cparam.total_masks,
                                                           bb_map_cur_time)

    new_depth_map_simulated_size = Int(length(new_depth_map_simulated)/(cparam.total_masks+1))
    new_summed_depth_map_simulated = get_weighted_depth_map_mask(new_depth_map_simulated, new_depth_map_simulated_size)
    new_summed_depth_map_simulated_rw = @trace(broadcasted_normal(new_summed_depth_map_simulated, [DEPTH_MAP_VAR]), :cloth_depth_map)

    #####================ [wb]: Uncomment these lines if DEPTH_MAP_CONFIG.debug_stiff is true ================####
    # new_mass = DEPTH_MAP_CONFIG.debug_mass_val
    # new_stiffness = DEPTH_MAP_CONFIG.debug_stiff_val

    # [debug]: raw dp ------------------------- #
    # julia_debug_dir = joinpath(DEPTH_MAP_CONFIG.debug_dp_julia_folder, string(t_for_flex_after_fm))
    # julia_debug_file_name = string(new_mass) * "_" * string(new_stiffness) *
    #                         "_sim_" * string(cparam.sim_num) *
    #                         "_t_" * string(t) *
    #                         "_flex_t_" * string(t_for_flex_after_fm) *
    #                         "_" * string(DEPTH_MAP_CONFIG.img_w) *
    #                         "_mask_" * string(cparam.total_masks) * "_SIM_" * string(now())* ".txt"
    # julia_debug_full_path = joinpath(julia_debug_dir, julia_debug_file_name)
    # tmp = save_array_to_txt(julia_debug_full_path, DEPTH_MAP_CONFIG.debug_dp,
    #                        string(new_summed_depth_map_simulated))
    ## end debug --------------------- #

    ## [debug]: dp with random-walk noise ------------------------- #
    # julia_debug_file_name = string(new_mass) * "_" * string(new_stiffness) *
    #                          "_sim_" * string(cparam.sim_num) *
    #                          "_t_" * string(t) *
    #                          "_flex_t_" * string(t_for_flex_after_fm) *
    #                          "_" * string(DEPTH_MAP_CONFIG.img_w) *
    #                          "_mask_" * string(cparam.total_masks) * "_SIM_WITH_DP_RW_" * string(now()) * ".txt"
    # julia_debug_full_path = joinpath(julia_debug_dir, julia_debug_file_name)
    # tmp = save_array_to_txt(julia_debug_full_path, DEPTH_MAP_CONFIG.debug_dp,
    #                         string(new_summed_depth_map_simulated_rw))
    ## end debug --------------------- #

    #####================ [wb]: Uncomment above lines if DEPTH_MAP_CONFIG.debug_stiff is true ================####
    state = StateSpace(new_cloth_pos, new_cloth_vel,
                       new_object_pos, new_object_vel,
                       new_summed_depth_map_simulated,
                       new_mass, new_stiffness, ext_force)
    return state
end



kernel_random_walk = Gen.Unfold(cloth_kernel_rand_walk)


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
