module OBJObservations

using ..PyTalker
using ..OBJUtils
using ..Constants
using Formatting
using Statistics
using Distances
import JSON

export ScenarioType, wind, drape, ball, rotate, get_init_obs, get_curr_obs,
       get_final_flattened_obs, get_simulated_data,
       get_weighted_depth_map_mask, get_simulated_data_after_n_frame,
       load_obs_depth, load_json, save_array_to_txt


@enum ScenarioType wind=1 drape ball rotate


get_init_obs(obj_path::String) = get_obj_data(obj_path)


function load_json(obj_path::String)
    """
    obj_path : depth_map json file
    """

    out_str = ""
    out_parsed = []
    open(obj_path, "r") do f
        out_str = read(f, String)
        out_parsed=JSON.parse(out_str)
    end
    return out_parsed
end


function load_obs_depth(obj_path::String)
    out_parsed = load_json(obj_path)
    out_float_array = convert(Array{Float64,1}, out_parsed)
    return out_float_array
end



function get_curr_obs(curr_file_path::String)
    """
    prev_file_path : path to the obj file in the previous time step
    curr_file_path : path to the obj file in the current time step
    """
    return get_obj_data(curr_file_path)
end



function get_weighted_depth_map_mask(depth_map::Array{Float64, 1},
                                     points_per_map::Int64)

    total_depth_map_n = Int(length(depth_map)/points_per_map)
    if DEPTH_MAP_CONFIG.weight_decay == "linear"
        weight_decay_rate = collect(range(0.2, stop = 1.0, length = max(5,total_depth_map_n)))
    elseif DEPTH_MAP_CONFIG.weight_decay == "exp"
        weight_decay_rate = map(exp, collect(range(min(-5,-total_depth_map_n), stop=0, length=max(5+1,total_depth_map_n+1))))
    else
        error("invalid [weight_decay_rate] value -- linear|exp")
    end
    weight_decay_rate = weight_decay_rate[end-total_depth_map_n+1:end]
    summed_depth_map_mask = zeros(points_per_map)
    idx_start = 1
    for i in 1:total_depth_map_n
        idx_end = idx_start + points_per_map-1
        depth_map[idx_start:idx_end] = depth_map[idx_start:idx_end] .* weight_decay_rate[i]
        summed_depth_map_mask = summed_depth_map_mask + depth_map[idx_start:idx_end]
        idx_start = idx_end + 1
    end
    tmp_min = min(summed_depth_map_mask...)
    tmp_max = max(summed_depth_map_mask...)
    summed_depth_map_mask = 255.0 .* (summed_depth_map_mask .- tmp_min) ./(tmp_max - tmp_min)
    return summed_depth_map_mask
end



function get_final_flattened_obs(prev_flattened_cloth::Array{Float64, 1},
                                 curr_flattened_cloth::Array{Float64, 1},
                                 total_points_per_mask::Int64,
                                 total_masks::Int64,
                                 time_step_num::Int64)
    """
    # Arguments
    - `prev_flattened_cloth`:
    - `curr_flattened_cloth`: length of the curr_unflattened_cloth * dim (e.g., if [x,y,z], dim=3)
    - `total_points_per_mask`: length of the curr_unflattened_cloth
    - `total_masks`: start from 0 (i.e., no flow mask, only use the curr_flattened_cloth)
    - `time_step_num`: run the web server task asynchronously
    # Return
    - `returned`: [new_flattened_masked; prev_flattened_cloth]
    - `summed_obs`: size is the same as "curr_flattened_cloth", with pixel number summed-up

    """

    if total_masks < 5
        weight_decay_rate = [1.0, 0.8, 0.6, 0.4, 0.2]
    else
        weight_decay_rate = range(1.0, stop = 0.2, length = total_masks+1)
    end

    summed_obs = zeros(total_points_per_mask)

    if total_masks == 0 || time_step_num == 1
        return deepcopy(curr_flattened_cloth), deepcopy(curr_flattened_cloth)
    end

    returned = [deepcopy(curr_flattened_cloth); deepcopy(prev_flattened_cloth)]
    while length(returned) > total_points_per_mask * (total_masks + 1)
        returned = returned[1:end - total_points_per_mask]
    end
    cur_mask_n = Int(length(returned) / total_points_per_mask)


    for i in 1:cur_mask_n
        summed_obs = summed_obs + (weight_decay_rate[i] .* returned[(i-1)*total_points_per_mask+1: i*total_points_per_mask])
    end

    return deepcopy(returned), deepcopy(summed_obs)
end


function get_simulated_data(cloth_positions::Array{Array{Float64, 1}, 1},
                            cloth_velocities::Array{Array{Float64, 1}, 1},
                            object_positions::Array{Array{Float64, 1}, 1},
                            object_velocities::Array{Array{Float64, 1}, 1},
                            mass::Float64,
                            stiffness::Float64,
                            external_force::Float64,
                            sim_num::Int64,
                            time_step_num::Int64,
                            time_step_flex::Int64,
                            time_interval::Float64,
                            extention::String)
    """
    positions       : the array of all position vectors (vertices)
    velocities      : the array of all velocity vectors
    sim_num         : the simulation number designating the scenario being played
    t               : the time step to be queried
    """

    flex_f_prefix = "trials"
    

    if EXP_COND != "mass_or_stiff"
        extention = EXT_FOR_CUR_JOB * '_' * extention
    end



    arguments = ["--scene", string(ScenarioType(sim_num)),
                 "--input_t_frame", string(time_step_flex),
                 "--cloth_position", string(cloth_positions),
                 "--cloth_velocity", string(cloth_velocities),
                 "--object_position", string(object_positions),
                 "--object_velocity", string(object_velocities),
                 "--mass", string(mass),
                 "--bstiff", string(stiffness),
                 "--shstiff", string(stiffness),
                 "--ststiff", string(stiffness),
                 "--flex_output_root_path", string("experiments/simulation/" * extention * "/" * flex_f_prefix * "/")]

    if EXP_COND == "mass_or_stiff"
        push!(arguments, "--extforce")
        push!(arguments, string(external_force))
    else
        ext_force = -1
    end

                 
    simulate_next_frame_flex(arguments)

    sim_path = joinpath(BASE_PY_PATH, "experiments/simulation/" * extention)
    obj_path_curr = joinpath(sim_path, flex_f_prefix * "_cloth_1.obj")
    obj_data = get_obj_data(obj_path_curr)

    if sim_num == 3 && time_step_flex < BALL_SCENARIO_START_INDEX
        obj_data.object_positions = deepcopy(object_positions)
        obj_data.object_velocities = deepcopy(object_velocities)
    end


    return obj_data
end


function save_array_to_txt(path::String, save_flag::Bool,
                           array_data::String)
    if save_flag
        open(path, "w") do io
            write(io, array_data)
        end
    end
    return 0
end

function get_simulated_data_after_n_frame(prev_cloth_pos::Array{Array{Float64, 1}, 1},
                                          prev_cloth_vel::Array{Array{Float64, 1}, 1},
                                          prev_object_pos::Array{Array{Float64, 1}, 1},
                                          prev_object_vel::Array{Array{Float64, 1}, 1},
                                          new_mass::Float64,
                                          new_stiffness::Float64,
                                          ext_force::Float64,
                                          sim_num::Int64,
                                          t::Int64,
                                          t_for_flex::Int64,
                                          time_interval::Float64,
                                          extention::String,
                                          total_masks::Int64,
                                          bb_map_cur_time)
    """
    Simulate n=total_masks+1 consecutive frames and save the concatenated depth-maps as a vector
    """

    new_cloth_pos = Array{Float64, 1}[]
    new_cloth_vel = Array{Float64, 1}[]
    new_object_pos = Array{Float64, 1}[]
    new_object_vel = Array{Float64, 1}[]
    new_depth_map_simulated = Float64[]


    println("\n")
    for i = 1:total_masks+1
        data = get_simulated_data(prev_cloth_pos, prev_cloth_vel,
                                  prev_object_pos, prev_object_vel,
                                  new_mass, new_stiffness, ext_force,
                                  sim_num,
                                  t,
                                  t_for_flex,
                                  time_interval,
                                  extention)

        new_cloth_pos = data.cloth_positions
        new_cloth_vel = data.cloth_velocities
        new_object_pos = data.object_positions
        new_object_vel = data.object_velocities

        arguments = ["--cloth_position", string(new_cloth_pos),
                     "--cur_scene_idx", string(sim_num),
                     "--frame_t", string(t_for_flex),
                     "--file_mass", string(new_mass),
                     "--file_stiff", string(new_stiffness),
                     "--mesh_or_points", string(DEPTH_MAP_CONFIG.mesh_or_points),
                     "--img_w", string(DEPTH_MAP_CONFIG.img_w),
                     "--img_h", string(DEPTH_MAP_CONFIG.img_h),
                     "--crop_with_bounding_box", string(DEPTH_MAP_CONFIG.crop_with_bb),
                     "--save_depth_map", string(DEPTH_MAP_CONFIG.save_dp)]

        if DEPTH_MAP_CONFIG.crop_with_bb == 1
            tmp_args = ["--bb_x", string(bb_map_cur_time[1]),
                        "--bb_y", string(bb_map_cur_time[2]),
                        "--flow_mask_n", string(total_masks)]
            arguments = [arguments; tmp_args]
        end

        new_cloth_depth_map = py_get_depth_map(arguments)
        new_depth_map_simulated = [new_depth_map_simulated;new_cloth_depth_map]

        prev_cloth_pos = new_cloth_pos
        prev_cloth_vel = new_cloth_vel
        prev_object_pos = new_object_pos
        prev_object_vel = new_object_vel
        t_for_flex = t_for_flex + 1
    end

    println("Simulated..." * ": t = " * string(t) *
            ", flex_t = [" * string(t_for_flex-1-total_masks) *
            ", " * string(t_for_flex-1) * "]" *
            ", mass = " * string(new_mass) *
            ", stiffness = " * string(new_stiffness) *
            ", ext_force = " * string(ext_force))

    return new_cloth_pos, new_cloth_vel, new_object_pos, new_object_vel, new_depth_map_simulated, t_for_flex-1

end


end
