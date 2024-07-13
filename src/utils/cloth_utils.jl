module ClothUtils
export filter_flatten_cloth


function filter_flatten_cloth(cloth_pos::Array{Array{Float64, 1}, 1},
                              cloth_vel::Array{Array{Float64, 1}, 1})

    total_points = 105
    total_edge_layers = 1
    temp_cloth_pos = deepcopy(cloth_pos)
    temp_cloth_vel = deepcopy(cloth_vel)

    delete_indices = []

    for i in total_edge_layers:total_points - (total_edge_layers + 1)
        if i % 4 != 0
            for j in total_edge_layers + 1:total_points - total_edge_layers
                append!(delete_indices, total_points * i + j)
            end
            continue
        end
        for j in total_edge_layers + 1:total_points - total_edge_layers
            if j % 4 == 0
                continue
            end
            append!(delete_indices, total_points * i + j)
        end
    end

    deleteat!(temp_cloth_pos, delete_indices)
    deleteat!(temp_cloth_vel, delete_indices)

    flatten_cloth_pos = collect(Iterators.flatten(temp_cloth_pos))
    flatten_cloth_vel = collect(Iterators.flatten(temp_cloth_vel))

    return flatten_cloth_pos, flatten_cloth_vel
end

end
