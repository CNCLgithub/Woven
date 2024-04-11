using Gen
using Random
prior = [0.2, 0.3, 0.5]

emission_dists = [
    0.1 0.2 0.7;
    0.2 0.7 0.1;
    0.7 0.2 0.1
]'

transition_dists = [
    0.4 0.4 0.2;
    0.2 0.3 0.5;
    0.9 0.05 0.05
]'

num_steps = 4
obs_x = [1, 1, 2, 3]


"""
generative model defines how the hidden variables are linked to observations
z is hidden variable, x is observation
"""
@gen function model(num_steps::Int)
    z_init = @trace(categorical(prior), :z_init)
    @trace(categorical(emission_dists[:, z_init]), :x_init)
    @trace(chain(num_steps-1, z_init, nothing), :chain)
end

"""
kernel, how the new observation will be generated
"""
@gen function kernel(t::Int, prev_z::Int, params::Nothing)
    z = @trace(categorical(transition_dists[:,prev_z]), :z)
    @trace(categorical(emission_dists[:,z]), :x)
    return z
end
chain = Unfold(kernel)


@gen function init_proposal(x::Int)
   dist = prior .* emission_dists[x,:]
   @trace(categorical(dist ./ sum(dist)), :z_init)
end





Random.seed!(1)
num_particles = 10000
ess_threshold = 10000 # make sure we exercise resampling


init_proposal_args = (obs_x[1],)
init_observations = choicemap((:x_init, obs_x[1]))

state = initialize_particle_filter(model, (1,), init_observations,
    init_proposal, init_proposal_args, num_particles)
