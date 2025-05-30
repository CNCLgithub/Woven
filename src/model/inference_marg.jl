using Gen
using Gen_Compose
using .OBJObservations
using .OBJUtils
using Dates

# ---------------------- Latent Extraction Functions ----------------------

# Extract cloth mass from the trace at time t
function extract_mass(trace::Gen.Trace)
    t, _, _, _ = Gen.get_args(trace)
    states = Gen.get_retval(trace)
    reshape([states[t].cloth_mass], (1,1,1))
end

# Extract cloth stiffness from the trace at time t
function extract_stiffness(trace::Gen.Trace)
    t, _, _, _ = Gen.get_args(trace)
    states = Gen.get_retval(trace)
    reshape([states[t].cloth_stiffness], (1,1,1))
end

# Extract external force from the trace at time t
function extract_force(trace::Gen.Trace)
    t, _, _, _ = Gen.get_args(trace)
    states = Gen.get_retval(trace)
    reshape([states[t].ext_force], (1,1,1))
end


# ---------------------- Main Inference Function ----------------------

"""
Run SMC inference across all input sequences.

Arguments:
- `num_particles`: Number of particles used in the particle filter
- `init_state_dict`: Dictionary mapping scene paths to initial states (from t=0)
- `observations_dict`: Dictionary mapping scene paths to depth observations
- `total_masks`: Number of flow masks (i.e., frames per depth observation)
- `init_frame_num`: Starting frame index for each sequence
- `bb_map`: Bounding box dictionary for cropping depth maps
- `mass_prior`, `stiff_prior`, `prior_w`: Prior configuration for conditioning

For each scene path:
- Initializes the generative model config
- Wraps model + observations in a sequential query
- Runs SMC inference and writes output to .h5 file
"""

function run(num_particles, init_state_dict, observations_dict, total_masks, init_frame_num, bb_map, mass_prior, stiff_prior, prior_w)
    for dir_path in collect(keys(observations_dict))
        for iter in 1:TOTAL_INFER_ITERATIONS
            # Load initial state and depth observations
            init_state = init_state_dict[dir_path]
            constraints = Gen.choicemap()
            observations = observations_dict[dir_path]
            # Define latent variables to track (stiffness + external force)
            latents = LatentMap(Dict(:cloth_stiffness => extract_stiffness,
                                     :ext_force => extract_force))
            
            # Extract metadata for scenario
            sim_num = parse(Int64, split(dir_path, "/")[end - 1])
            dir_name = split(dir_path, "/")[end]

            # Configure simulation parameters
            c_params = ConfigParams(sim_num=sim_num,
                                    time_interval=TIME_INTERVAL,
                                    extention="t_" * dir_name,
                                    cloth_width=default_config_params.cloth_width,
                                    cloth_height=default_config_params.cloth_height,
                                    mass_min=default_config_params.mass_min,
                                    mass_max=default_config_params.mass_max,
                                    stiffness_min=default_config_params.stiffness_min,
                                    stiffness_max=default_config_params.stiffness_max,
                                    ext_force_min=default_config_params.ext_force_min,
                                    ext_force_max=default_config_params.ext_force_max,
                                    total_masks=total_masks,
                                    init_frame_num=init_frame_num)
            println(c_params)
            println("probing dir: " * string(dir_path))
            println("\n")
            
            # Wrap model and observation sequence in a sequential query
            query = Gen_Compose.SequentialQuery(latents,
                                                gm_cloth,
                                                (0, init_state[1], init_state[2], init_state[3], init_state[4], init_state[5], bb_map, mass_prior, stiff_prior, prior_w, c_params),
                                                constraints,
                                                [(i, init_state[1], init_state[2], init_state[3], init_state[4], init_state[5], bb_map, mass_prior, stiff_prior, prior_w, c_params) for i in 1:length(observations)],
                                                observations)
            
            # Create particle filter for inference
            particle_filter = ClothParticleFilter(num_particles, num_particles / 2, nothing)
            
            # Set output filename for results
            results_filename = "result_" * dir_name * "_" * string(iter) * PRIOR_CLOTH * ".h5" * "-" * JOB_ID * "-" * Dates.format(now(), "mm-dd-HH")
            # Run SMC inference
            results = sequential_monte_carlo(particle_filter, query,
                                             buffer_size=length(observations),
                                             path=joinpath(RESULTS_PATH, results_filename))
        end
    end
end
