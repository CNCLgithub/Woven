

struct ClothParticleFilter <: Gen_Compose.AbstractParticleFilter
    particles::Int64
    ess::Float64
    rejuvenation::Union{Function, Nothing}
end



function Gen_Compose.rejuvenate!(proc::ClothParticleFilter,
                                 state::Gen.ParticleFilterState)
    # for p=1:proc.particles
    #     (state.traces[p], _) = Gen.mh(state.traces[p], Gen.select(:cloth_mass, :cloth_stiffness))
    # end
    println("Must rejuvinate")
end



function Gen_Compose.smc_step!(state::Gen.ParticleFilterState,
                               proc::ClothParticleFilter,
                               query::StaticQuery)
    time = query.args[1]
    Gen_Compose.resample!(proc, state)

    Gen.particle_filter_step!(state, query.args,
                              (UnknownChange(),),
                              query.observations)
    Gen_Compose.rejuvenate!(proc, state)
    return nothing
end



export ClothParticleFilter, smc_step!
