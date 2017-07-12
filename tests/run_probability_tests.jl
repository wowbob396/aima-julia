include("../aimajulia.jl");

using Base.Test;

using aimajulia;

#The following probability tests are from the aima-python doctests

cpt = variable_node(aimajulia.burglary_network, "Alarm");
event = Dict([Pair("Burglary", true), Pair("Earthquake", true)]);

@test probability(cpt, true, event) == 0.95;

event["Burglary"] = false;

@test probability(cpt, false, event) == 0.71;

s = Dict([Pair("A", true),
        Pair("B", false),
        Pair("C", true),
        Pair("D", false)]);

@test consistent_with(s, Dict());

@test consistent_with(s, s);

@test !consistent_with(s, Dict(Pair("A", false)));

@test !consistent_with(s, Dict(Pair("D", true)));

p = ProbabilityDistribution(variable_name="Flip");
p["H"], p["T"] = 0.25, 0.75;

@test p["H"] == 0.25;

p = ProbabilityDistribution(variable_name="X", frequencies=Dict([Pair("lo", 125),
                                                                Pair("med", 375),
                                                                Pair("hi", 500)]));

@test ((p["lo"], p["med"], p["hi"]) == (0.125, 0.375, 0.5));

p = JointProbabilityDistribution(["X", "Y"]);
p[(1,1)] = 0.25;

@test p[(1,1)] == 0.25;

p[Dict([Pair("X", 0), Pair("Y", 1)])] = 0.5;

@test p[Dict([Pair("X", 0), Pair("Y", 1)])] == 0.5;

@test (event_values(Dict([Pair("A", 10), Pair("B", 9), Pair("C", 8)]), ["C", "A"]) == (8, 10));

@test (event_values((1, 2), ["C", "A"]) == (1, 2));

p = JointProbabilityDistribution(["X", "Y"]);
p[(0, 0)], p[(0, 1)], p[(1, 1)], p[(2, 1)] = 0.25, 0.5, 0.125, 0.125;

@test enumerate_joint(["Y"], Dict([Pair("X", 0)]), p) == 0.75;

@test enumerate_joint(["X"], Dict([Pair("Y", 2)]), p) == 0;

@test enumerate_joint(["X"], Dict([Pair("Y", 1)]), p) == 0.75;

@test show_approximation(enumerate_joint_ask("X", Dict([Pair("Y", 1)]), p)) == "0: 0.6667, 1: 0.1667, 2: 0.1667";

bn = BayesianNetworkNode("X", "Burglary", Dict([Pair(true, 0.2), Pair(false, 0.625)]));

@test probability(bn, false, Dict([Pair("Burglary", false), Pair("Earthquake", true)])) == 0.375;

@test probability(BayesianNetworkNode("W", "", 0.75), false, Dict([Pair("Random", true)])) == 0.25;

X = BayesianNetworkNode("X", "Burglary", Dict([Pair(true, 0.2), Pair(false, 0.625)]));

@test (sample(X, Dict([Pair("Burglary", false), Pair("Earthquake", true)])) in (true, false));

Z = BayesianNetworkNode("Z", "P Q", Dict([Pair((true, true), 0.2),
                                            Pair((true, false), 0.3),
                                            Pair((false, true), 0.5),
                                            Pair((false, false), 0.7)]));

@test (sample(Z, Dict([Pair("P", true), Pair("Q", false)])) in (true, false));

@test show_approximation(enumeration_ask("Burglary",
                                        Dict([Pair("JohnCalls", true), Pair("MaryCalls", true)]),
                                        aimajulia.burglary_network)) == "false: 0.7158, true: 0.2842";

@test show_approximation(elimination_ask("Burglary",
                                        Dict([Pair("JohnCalls", true), Pair("MaryCalls", true)]),
                                        aimajulia.burglary_network)) == "false: 0.7158, true: 0.2842";

# RandomDevice() does not allow seeding.

mt_rng = MersenneTwister(21);

p = rejection_sampling("Earthquake", Dict(), aimajulia.burglary_network, 1000, mt_rng);

@test ((p[true], p[false]) == (0.002, 0.998));

mt_rng = srand(mt_rng, 71);

p = likelihood_weighting("Earthquake", Dict(), aimajulia.burglary_network, 1000, mt_rng);

@test ((p[true], p[false]) == (0.0, 1.0));

mt_rng = srand(mt_rng, 1017);

@test (show_approximation(likelihood_weighting("Burglary",
                            Dict([Pair("JohnCalls", true), Pair("MaryCalls", true)]),
                            aimajulia.burglary_network,
                            10000,
                            mt_rng)) == "false: 0.718, true: 0.282");

umbrella_prior = [0.5, 0.5];
umbrella_transition = [[0.7, 0.3], [0.3, 0.7]];
umbrella_sensor =  [[0.9, 0.2], [0.1, 0.8]];
umbrella_hmm = HiddenMarkovModel(umbrella_transition, umbrella_sensor);
umbrella_evidence = [true, true, false, true, true];    # Umbrella observation sequence (Fig. 15.5b)

@test (repr(forward_backward(umbrella_hmm, umbrella_evidence, umbrella_prior)) ==
        "Array{Float64,1}[[0.646936,0.353064],[0.867339,0.132661],[0.820419,0.179581],[0.307484,0.692516],[0.820419,0.179581],[0.867339,0.132661]]");

umbrella_evidence = [true, false, true, false, true];

@test (repr(forward_backward(umbrella_hmm, umbrella_evidence, umbrella_prior)) ==
        "Array{Float64,1}[[0.587074,0.412926],[0.717684,0.282316],[0.2324,0.7676],[0.607195,0.392805],[0.2324,0.7676],[0.717684,0.282316]]");

