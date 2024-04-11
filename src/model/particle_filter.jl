

struct ClothParticleFilter <: Gen_Compose.AbstractParticleFilter
    particles::Int64
    ess::Float64
    rejuvenation::Union{Function, Nothing}
end


# @gen function mh_proposal(prev_trace, a::Int, b::Int)
#     choices = get_choices(prev_trace)
#     (T,) = get_args(prev_trace)
#     for t=a:b
#         vx = @trace(normal(choices[(:vx, t)], 1e-3), (:vx, t))
#         vy = @trace(normal(choices[(:vy, t)], 1e-3), (:vy, t))
#     end
# end


# function perturbation_move(trace, a::Int, b::Int)
#     Gen.metropolis_hastings(trace, perturbation_proposal, (a, b))
# end;


function Gen_Compose.rejuvenate!(proc::ClothParticleFilter,
                                 state::Gen.ParticleFilterState)
   # The use of MCMC in particle filters has primarily focused on increasing
   # the diversity of particles

    # for p=1:proc.particles
    #     (state.traces[p], _) = Gen.mh(state.traces[p], Gen.select(:cloth_mass, :cloth_stiffness))
    # end
    println("Must rejuvinate")
end



function Gen_Compose.smc_step!(state::Gen.ParticleFilterState,
                               proc::ClothParticleFilter,
                               query::StaticQuery)
    # Resample before moving on...
    time = query.args[1]
    Gen_Compose.resample!(proc, state)

    # update the state of the particles
    Gen.particle_filter_step!(state, query.args,
                              (UnknownChange(),),
                              query.observations)
    Gen_Compose.rejuvenate!(proc, state)
    return nothing
end



export ClothParticleFilter, smc_step!
