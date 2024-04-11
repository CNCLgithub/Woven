using Gen
using Random

##########################
#== Mutable choice map ==#
##########################
choices = choicemap()
choices[:x] = true
choices["foo"] = 1.25
choices[:y => 1 => :z] = -6.3
choices[:y => 0 => :z] = -2.3

# The full branch has to be in the trace, otherwise false
has_value(choices, :x) == true
has_value(choices, :y=>1=>:z) == true
has_value(choices, "foo") == true
has_value(choices, :y) == false


##########################
#== Merge ==#
#
# [func]:   Move the branches in two trees to the same tree
#           The two leaf MUST be different!
# [return]: DynamicChoiceMap
##########################
leaf1 = choicemap()
leaf1[:l2=>:l3] = 0.222
leaf2 = choicemap()
leaf2[:l2=>:l1] = 0.233
res1 = merge(leaf1, leaf2)

# The following Will be wrong
# merge(leaf1, leaf1)


###########################################################################################
@gen (grad) function bang0((grad)(x::Float64), (grad)(y::Float64))
    std::Float64 = 3.0
    z = @trace(normal(x + y, std), :z)
    return z
end

@gen (grad) function fuzz0((grad)(x::Float64), (grad)(y::Float64))
    std::Float64 = 3.0
    z = @trace(normal(x + 2 * y, std), :z)
    return z
end

sc = Switch(bang0, fuzz0)

##########################
#
#== Simulate ==#
#
# [func]: Run the generative function, return the trace (Can't set constrain)
# [return]: Gen.SwitchTrace{Any} | Gen.DynamicDSLTrace{DynamicDSLFunction{Any}}
##########################
Random.seed!(1234)
rand(1)
# ==> Return a trace
tr = simulate(sc, (2, 5.0, 3.0))
val0 = get_choices(tr) # ---> val0 is a choicemap
w0 = get_score(tr)


##########################
#== Propose ==#
#
#[func]: Similar to "simulate" but don't return a trace,
#        but a proposed value (DynamicChoiceMap) + its density
##########################
Random.seed!(1234)
rand(1)
# ==> Return [get_choices(), get_score()]
val1, w1 = propose(sc, (2, 5.0, 3.0))


##########################
#== Generate ==#
#
#[func]: Generate the given value from the assigned distribution
#        Similar to "simulate", but can add constrains
#[return]: trace + p
##########################
Random.seed!(1234)
rand(1)
val2_true = choicemap()
val2_true[:z] = 8.294768552429549
# ==> Return [trace, weight] with get_traces()==constrains
tr2, w2 = generate(sc, (2, 5.0, 3.0), val2_true)
val2 = get_choices(tr2)
w2_wrong = get_score(tr2)   # ==> This will return 0

val2[:z] == val2_true[:z]
isapprox(w2, logpdf(normal, 8.294768552429549, 5.0 + 2 * 3.0, 3.0))

##########################
#== Update ==#
#
# [func]: 1) Get the same current value in a new distribution;
#         2) Get a new value from the current distribution
# [return]: trace + p_difference
##########################
Random.seed!(1234)
rand(1)
tr3 = simulate(sc, (1, 5.0, 3.0))
old_val3 = get_choices(tr3)
old_w3 = get_score(tr3)

# ----------------------------------------
#### If you want to KEEP the current the :z value, to update its weight in the new distribution
chm = choicemap((:x => :z, 0.294768552429549))

new_tr3, w3, rd3, discard3 = update(tr3, (2, 5.0, 3.0),
                                    (UnknownChange(),
                                    NoChange(),
                                    NoChange()),
                                    chm)

isapprox(old_val3, get_choices(new_tr3))
isapprox(old_w3, get_score(new_tr3) - w3)

# ----------------------------------------
#### If you want to CHANGE the  :z value, making it to be the one you assigned;
chm = choicemap((:z, 18.294768552429549))
# Here "discard3" stores the old value "old_vale3"
new_tr3, w3, rd3, discard3 = update(tr3, (2, 5.0, 3.0),
                                    (UnknownChange(),
                                    NoChange(),
                                    NoChange()),
                                    chm)

isapprox(old_val3, get_choices(new_tr3))
isapprox(old_w3, get_score(new_tr3) - w3)


##########################
#== Regenerate ==#
#
# [func]:   Regenerate a new random var
# [return]: the new trace,
#           p difference = p(new_val)-p(old_val)
##########################
tr4 = tr
w4 = w0
val4 = val0
sel = select(:z)
new_tr4, new_w4, rd4 = regenerate(tr4, (2, 5.0, 3.0),
                                    (UnknownChange(), NoChange(), NoChange()),
                                    sel)

# Will getnerate a new random value, and calculate the difference of p = new_val-old_val
isapprox(w4, get_score(new_tr4)-new_w4)
