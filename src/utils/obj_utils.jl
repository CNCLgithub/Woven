module OBJUtils
export get_obj_data, OBJData

using FileIO
using GeometryBasics

mutable struct OBJData
    cloth_positions::Array{Array{Float64, 1}, 1}
    cloth_velocities::Array{Array{Float64, 1}, 1}
    object_positions::Array{Array{Float64, 1}, 1}
    object_velocities::Array{Array{Float64, 1}, 1}
end

function load_obj(path)
    """
    Groups vertices as per the objects ('o') in the file
    """
    obj_data = Dict()

    current_object = ""
    open(path) do f
        for (i, line) in enumerate(eachline(f))
            if !isempty(line)
                if line[1] == 'o' || line[1] == 'O'
                    current_object = line[3:end]
                    obj_data[current_object] = Dict()
                    obj_data[current_object]["positions"] = Array{Float64, 1}[]
                    obj_data[current_object]["velocities"] = Array{Float64, 1}[]
                elseif line[1] == 'v' || line[1] == 'V'
                    push!(obj_data[current_object]["positions"], [parse(Float64, v) for v in split(line[3:end])])
                elseif line[1] == 's' || line[1] == 'S'
                    push!(obj_data[current_object]["velocities"], [parse(Float64, v) for v in split(line[3:end])])
                end
            end
        end
    end
    return obj_data
end

extract_positions(obj_data::Dict, object_name::String="cloth") = (haskey(obj_data, object_name) && !isempty(obj_data[object_name]["positions"])) ? obj_data[object_name]["positions"] : [[0.0]]
extract_velocities(obj_data::Dict, object_name::String="cloth") = (haskey(obj_data, object_name) && !isempty(obj_data[object_name]["velocities"])) ? obj_data[object_name]["velocities"] : [[0.0]]

function get_obj_data(path_curr)
    """
    path_curr: path to the obj file for time t = t
    path_prev: path to the obj file for time t = t-1 (not used)
    """

    obj_data_curr = load_obj(path_curr)
    cloth_positions = extract_positions(obj_data_curr)
    cloth_velocities = extract_velocities(obj_data_curr)
    object_positions = extract_positions(obj_data_curr, "object")
    object_velocities = extract_velocities(obj_data_curr, "object")

    return OBJData(cloth_positions, cloth_velocities, object_positions, object_velocities)
end




end
