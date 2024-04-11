module DatasetCollector
export collect_observations, load_observations

using Gen
using ..OBJObservations
using ..OBJUtils
using ..Constants
using ..PyTalker


function load_observations(specific_dir_list::Array{String,1}=String[],
                           total_masks::Int64=0,       # img_n = total_masks_n + 1
                           init_frame_num::Int64=1)
    dp_f_suffix=""
    end_idx=0
    bb_f=""

    if DEPTH_MAP_CONFIG.crop_with_bb==1
        dp_f_suffix = "_" * string(DEPTH_MAP_CONFIG.img_w) * "_" * string(total_masks)* "_" * DEPTH_MAP_CONFIG.mesh_or_points * "_crop.json"
        end_idx = 4
    else
        dp_f_suffix = "_" * string(DEPTH_MAP_CONFIG.img_w) * "_" * DEPTH_MAP_CONFIG.mesh_or_points * ".json"
        end_idx = 2
    end


    # find and organize observation depth_img json files for each MASS-STIFFNESS combination available
    obs_obj_filenames = Dict()
    if isempty(specific_dir_list)
        for s in instances(ScenarioType)
            scenario_dir = joinpath(BASE_LIB_PATH, string(Int64(s)))
            if isdir(scenario_dir)
                for dir in readdir(scenario_dir; join=true)
                    files = filter(x->occursin(dp_f_suffix, x), readdir(dir))
                    obs_obj_filenames[dir] = sort!(files, by=t->parse(Int64, split(split(t, ".")[1], "_")[end-end_idx]))
                end
            end
        end
    else
        for s_dir in specific_dir_list
            if isdir(s_dir)
                files = filter(x->occursin(dp_f_suffix, x), readdir(s_dir))
                obs_obj_filenames[s_dir] = sort!(files, by=t->parse(Int64, split(split(t, ".")[1], "_")[end-end_idx]))
            end
        end
    end

    # record observations in Gen using the captured OBJ files
    init_state_dict = Dict()
    observations_gen = Dict()
    bb_map = Dict()

    for dir_name in collect(keys(obs_obj_filenames))
        ### ====== [wb]: Get init state =====
        sim_num = parse(Int64, split(dir_name, "/")[end - 1])
        bb_map_cur_dir = Dict()
        if DEPTH_MAP_CONFIG.crop_with_bb==1
            cur_dir_name = split(dir_name, "/")[end]
            sim_scene_name = split(cur_dir_name,'_')[1]
            bb_f = "bb_" * sim_scene_name * "_" *string(DEPTH_MAP_CONFIG.img_w) * "_fm=" * string(total_masks) * "_julia.json"
            bb_f = joinpath(BASE_LIB_PATH, bb_f)
            bb_map_cur_dir = load_json(bb_f)[cur_dir_name]
        end

        init_masked_depth_map_size = 0
        init_masked_depth_map = Float64[]
        # TODO: initialize with a struct
        obs_pos_vel=""

        # set the init state as the first [n=total_masks+1] frameS of the video
        for i in init_frame_num:init_frame_num+total_masks
            # Get obs_pos_vel
            f_mesh_suffix = join(split(split(obs_obj_filenames[dir_name][i],".")[1],"_")[1:(end-end_idx)], "_")

            f_obs_mesh_path = joinpath(dir_name, f_mesh_suffix * ".obj")
            f_obs_depth_path = joinpath(dir_name, obs_obj_filenames[dir_name][i])
            obs_pos_vel = get_init_obs(f_obs_mesh_path)
            if sim_num == 3
                # obs_obj_filenames[dir_name][BALL_SCENARIO_START_INDEX]=ball_cloth_25.obj
                f_obj_suffix = join(split(split(obs_obj_filenames[dir_name][BALL_SCENARIO_START_INDEX],".")[1],"_")[1:(end-end_idx)], "_")
                f_obj_mesh_path = joinpath(dir_name, f_obj_suffix * ".obj")
                obj_obs_pos_vel = get_init_obs(f_obj_mesh_path)
                obs_pos_vel.object_positions = obj_obs_pos_vel.object_positions
                obs_pos_vel.object_velocities = obj_obs_pos_vel.object_velocities
            end

            init_depth_map = load_obs_depth(f_obs_depth_path)
            init_masked_depth_map = [init_masked_depth_map;init_depth_map]
        end
        # cloth_positions are from the last frame; depth_map is summup-up.
        init_masked_depth_map_size = Int(length(init_masked_depth_map)/(total_masks+1))
        init_summed_masked_depth_map = get_weighted_depth_map_mask(init_masked_depth_map, init_masked_depth_map_size)

        init_state_dict[dir_name] = obs_pos_vel.cloth_positions, obs_pos_vel.cloth_velocities,
                                    obs_pos_vel.object_positions, obs_pos_vel.object_velocities,
                                    init_summed_masked_depth_map


        ### ====== [wb]: Setup all the observations ===================================
        total_obs = length(obs_obj_filenames[dir_name]) - (init_frame_num + total_masks)  # the first frame is the init_state
        # TODO check this number
        total_obs = Int(floor(total_obs/(total_masks+1)))
        observations_gen[dir_name] = Vector{Gen.ChoiceMap}(undef, total_obs)
        #bb_map[dir_name] = Dict()
        #masked_depth_map = Float64[1.0]


        # init_frame_num=1, [init=[0,1,2], obs=[3,4,5]...]
        # init_frame_num=4, [init=[3,4,5], obs=[6,7,8]...]
        for i in init_frame_num:init_frame_num + total_obs - 1
            time_t = i - init_frame_num + 1
#             println(time_t)
            obs_pos_vel=""
            cur_idx=-1
            cur_masked_depth_map=Float64[]

            bb_map[time_t]=[]
            if DEPTH_MAP_CONFIG.crop_with_bb==1
                #bb_map[dir_name][time_t] = bb_map_cur_dir[string((time_t)*(total_masks+1)+1+init_frame_num-2)]
                bb_map[time_t] = bb_map_cur_dir[string((time_t)*(total_masks+1)+1+init_frame_num-2)]
            end

            for j in 1:total_masks+1
                cur_idx = (time_t)*(total_masks+1)+j+init_frame_num-2
                cur_f_obs_path = joinpath(dir_name, obs_obj_filenames[dir_name][cur_idx+1])
                curr_depth_map = load_obs_depth(cur_f_obs_path);
                cur_masked_depth_map = [cur_masked_depth_map;curr_depth_map]
            end

            # cloth_positions are from the last frame; depth_map is summup-up.
            cur_masked_depth_map_size = Int(length(cur_masked_depth_map)/(total_masks+1))
            cur_summed_masked_depth_map = get_weighted_depth_map_mask(cur_masked_depth_map, cur_masked_depth_map_size)

            c_map = Gen.choicemap()
            c_map[:kernel => time_t => :cloth_depth_map] = cur_summed_masked_depth_map;
            observations_gen[dir_name][time_t] = c_map

            if DEPTH_MAP_CONFIG.debug_dp
                arguments= ["--pixel_ls", string(cur_summed_masked_depth_map),
                            "--save_path", joinpath(DEPTH_MAP_CONFIG.debug_dp_root_folder, "observations", string(dir_name), "mask_" * string(total_masks)),
                            "--save_file_name", "julia_" * string(time_t) * "_" * string(obs_obj_filenames[dir_name][cur_idx+1])
                            ]
                py_save_img(arguments)
                println("julia_" * string(time_t) * "_" * string(obs_obj_filenames[dir_name][cur_idx+1]))
            end

        end
    end

    return init_state_dict, observations_gen, bb_map
end




function collect_observations(specific_dir_list::Array{String,1}=String[],
                              total_masks::Int64=0,       # img_n = total_masks_n + 1
                              init_frame_num::Int64=1)
    # Load all observations (all cloth_pos and cloth_vel)

    # find and organize observation OBJ files for each MASS-STIFFNESS combination available
    obs_obj_filenames = Dict()
    if isempty(specific_dir_list)
        for s in instances(ScenarioType)
            scenario_dir = joinpath(BASE_LIB_PATH, string(Int64(s)))
            if isdir(scenario_dir)
                for dir in readdir(scenario_dir; join=true)
                    files = filter(x->occursin(".obj", x), readdir(dir))
                    obs_obj_filenames[dir] = sort!(files, by=t->parse(Int64, split(split(t, ".")[1], "_")[end]))
                end
            end
        end
    else
        for s_dir in specific_dir_list
            if isdir(s_dir)
                files = filter(x->occursin(".obj", x), readdir(s_dir))
                obs_obj_filenames[s_dir] = sort!(files, by=t->parse(Int64, split(split(t, ".")[1], "_")[end]))
            end
        end
    end

    # record observations in Gen using the captured OBJ files
    init_state_dict = Dict()
    observations_gen = Dict()

    for dir_name in collect(keys(obs_obj_filenames))
        ### ====== [wb]: Get init state =====
        sim_num = parse(Int64, split(dir_name, "/")[end - 1])
        init_masked_depth_map_size = 0
        init_masked_depth_map = Float64[]
        println(dir_name)
        # TODO: initialize with a struct
        obs_pos_vel=""

        # set the init state as the first [n=total_masks+1] frameS of the video
        for i in init_frame_num:init_frame_num+total_masks
            # Get obs_pos_vel
            f_obs_path = joinpath(dir_name, obs_obj_filenames[dir_name][i])
            obs_pos_vel = get_init_obs(f_obs_path)
            if sim_num == 3
                # obs_obj_filenames[dir_name][BALL_SCENARIO_START_INDEX]=ball_cloth_25.obj
                f_obj_path = joinpath(dir_name, obs_obj_filenames[dir_name][BALL_SCENARIO_START_INDEX])
                obj_obs_pos_vel = get_init_obs(f_obj_path)
                obs_pos_vel.object_positions = obj_obs_pos_vel.object_positions
                obs_pos_vel.object_velocities = obj_obs_pos_vel.object_velocities
            end

            arguments= ["--cloth_position", string(obs_pos_vel.cloth_positions),
                        "--cur_scene_idx", string(sim_num),
                        "--file_path", string(f_obs_path),
                        "--save_depth_map", string(DEPTH_MAP_CONFIG.save_dp),
                        "--mesh_or_points", string(DEPTH_MAP_CONFIG.mesh_or_points),
                        "--img_w", string(DEPTH_MAP_CONFIG.img_w),
                        "--img_h", string(DEPTH_MAP_CONFIG.img_h),
                        "--crop_with_bounding_box", string(0)]
            init_depth_map = py_get_depth_map(arguments)
            init_masked_depth_map = [init_masked_depth_map;init_depth_map]
        end

        # cloth_positions are from the last frame; depth_map is summup-up.
        init_masked_depth_map_size = Int(length(init_masked_depth_map)/(total_masks+1))
        init_summed_masked_depth_map = get_weighted_depth_map_mask(init_masked_depth_map, init_masked_depth_map_size)

        init_state_dict[dir_name] = obs_pos_vel.cloth_positions, obs_pos_vel.cloth_velocities,
                                    obs_pos_vel.object_positions, obs_pos_vel.object_velocities,
                                    init_summed_masked_depth_map


        ### ====== [wb]: Setup all the observations =====
        total_obs = length(obs_obj_filenames[dir_name]) - (init_frame_num + total_masks)  # the first frame is the init_state
        # TODO check this number
        total_obs = Int(floor(total_obs/(total_masks+1)))

        observations_gen[dir_name] = Vector{Gen.ChoiceMap}(undef, total_obs)
        masked_depth_map = Float64[1.0]

        # init_frame_num=1, [init=[0,1,2], obs=[3,4,5]...]
        # init_frame_num=4, [init=[3,4,5], obs=[6,7,8]...]
        for i in init_frame_num:init_frame_num + total_obs - 1
            time_t = i - init_frame_num + 1
            obs_pos_vel=""
            cur_idx=-1
            cur_masked_depth_map=Float64[]
            for j in 1:total_masks+1
                cur_idx = (time_t)*(total_masks+1)+j+init_frame_num-2
                cur_f_obs_path = joinpath(dir_name, obs_obj_filenames[dir_name][cur_idx+1])
                #println(i) ==> [1,2,3]
                #println(j) ==> [1,2,1]
                #println(obs_obj_filenames[dir_name][cur_idx+1]) ==> [_1.obj, _2.obj, _3.obj]
                #println(time_t) ==> [1,2,3]

                # -------------------- If total_masks=0 -------------------------------
                # println(i)                                      ==> 186
                # println(cur_idx)                                ==> 186
                # println(obs_obj_filenames[dir_name][cur_idx+1]) ==> ball_cloth_186.obj
                 # --------------------------------------------------------------------
                obs_pos_vel = get_curr_obs(cur_f_obs_path)

                arguments= ["--cloth_position", string(obs_pos_vel.cloth_positions),
                            "--cur_scene_idx", string(sim_num),
                            "--file_path", string(cur_f_obs_path),
                            "--save_depth_map", string(DEPTH_MAP_CONFIG.save_dp),
                            "--mesh_or_points", string(DEPTH_MAP_CONFIG.mesh_or_points),
                            "--img_w", string(DEPTH_MAP_CONFIG.img_w),
                            "--img_h", string(DEPTH_MAP_CONFIG.img_h),
                            "--crop_with_bounding_box", string(0)]
                curr_depth_map = py_get_depth_map(arguments)
                cur_masked_depth_map = [cur_masked_depth_map;curr_depth_map]
            end

            # cloth_positions are from the last frame; depth_map is summup-up.
            cur_masked_depth_map_size = Int(length(cur_masked_depth_map)/(total_masks+1))
            cur_summed_masked_depth_map = get_weighted_depth_map_mask(cur_masked_depth_map, cur_masked_depth_map_size)

            c_map = Gen.choicemap()
            c_map[:kernel => time_t => :cloth_depth_map] = cur_summed_masked_depth_map
            observations_gen[dir_name][time_t] = c_map

            if DEPTH_MAP_CONFIG.debug_dp
                arguments= ["--pixel_ls", string(cur_summed_masked_depth_map),
                            "--img_w", string(DEPTH_MAP_CONFIG.img_w),
                            "--img_h", string(DEPTH_MAP_CONFIG.img_h),
                            "--save_path", joinpath(DEPTH_MAP_CONFIG.debug_dp_root_folder, "observations", string(dir_name), "mask_" * string(total_masks)),
                            "--save_file_name", "julia_" * string(time_t) * "_" * string(obs_obj_filenames[dir_name][cur_idx+1])
                            ]
                py_save_img(arguments)
                println("julia_" * string(time_t) * "_" * string(obs_obj_filenames[dir_name][cur_idx+1]))
            end

        end
    end

    return init_state_dict, observations_gen
end


end
