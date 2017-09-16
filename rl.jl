
export PassiveADPAgentMDP, PassiveADPAgentProgram;

#=

	PassiveADPAgentMDP is a MDP implementation of AbstractMarkovDecisionProcess

    that consists of a MarkovDecisionProcess 'mdp'.

=#
type PassiveADPAgentMDP{T} <: AbstractMarkovDecisionProcess
	mdp::MarkovDecisionProcess{T}


	function PassiveADPAgentMDP{T}(initial::T, actions_list::Set{T}, terminal_states::Set{T}, gamma::Float64, states::Set{T})
		return new(MarkovDecisionProcess(initial, actions_list, terminal_states, Dict(), states=states, gamma=gamma));
	end
end

PassiveADPAgentMDP(initial, actions_list::Set, terminal_states::Set, gamma::Float64, states::Set) = PassiveADPAgentMDP{typeof(initial)}(initial, actions_list, terminal_states, gamma, states);

"""
    reward(mdp::PassiveADPAgentMDP, state)

Return a reward based on the given 'state'.
"""
function reward(mdp::PassiveADPAgentMDP, state)
    return mdp.mdp.reward[state];
end

"""
    transition_model(mdp::PassiveADPAgentMDP, state, action)

Return a list of (P(s'|s, a), s') pairs given the state 's' and action 'a'.
"""
function transition_model(mdp::PassiveADPAgentMDP, state, action)
    return collect((v, k) for (k, v) in mdp.mdp.transitions);
end

"""
    actions(mdp::PassiveADPAgentMDP, state)

Return a set of actions that are possible in the given state.
"""
function actions(mdp::PassiveADPAgentMDP, state)
    if (state in mdp.mdp.terminal_states)
        return Set{Void}([nothing]);
    else
        return mdp.mdp.actions;
    end
end

"""
    policy_evaluation(pi::Dict, U::Dict, mdp::PassiveADPAgentMDP; k::Int64=20)

Return the updated utilities of the MDP's states by applying the modified policy iteration
algorithm on the given Markov decision process 'mdp', utility function 'U', policy 'pi',
and number of Bellman updates to use 'k'.
"""
function policy_evaluation(pi::Dict, U::Dict, mdp::PassiveADPAgentMDP; k::Int64=20)
    for i in 1:k
        for state in mdp.mdp.states
            U[state] = (reward(mdp, state)
                        + (mdp.mdp.gamma
                        * sum((p * U[state_prime] for (p, state_prime) in transition_model(mdp, state, pi[state])))));
        end
    end
    return U;
end

#=

    PassiveADPAgentProgram is a passive reinforcement learning agent based on

    adaptive dynamic programming (Fig. 21.2).

=#
type PassiveADPAgentProgram <: AgentProgram
    state::Nullable
    action::Nullable
    U::Dict
    pi::Dict
    mdp::PassiveADPAgentMDP
    N_sa::Dict
    N_s_prime_sa::Dict

    function PassiveADPAgentProgram{T <: AbstractMarkovDecisionProcess}(pi::Dict, mdp::T)
        return new(Nullable(),
                    Nullable(),
                    Dict(),
                    pi,
                    PassiveADPAgentMDP(mdp.initial, mdp.actions, mdp.terminal_states, mdp.gamma, mdp.states),
                    Dict(),
                    Dict());
    end
end

function execute(padpap::PassiveADPAgentProgram, percept::Tuple{Any, Any})
    local r_prime::Float64;
    s_prime, r_prime = percept;

    union!(padpap.mdp.mdp.states, s_prime);
    if (!haskey(mdp.mdp.reward, s_prime))
        padpap.U[s_prime] = r_prime;
        padpap.mdp.mdp.reward = r_prime;
    end
    if (!isnull(padpap.state))
        padpap.N_sa[(get(padpap.state), get(padpap.action))] = get!(padpap.N_sa, (get(padpap.state), get(padpap.action)), 0) + 1;
        padpap.N_s_prime_sa[(s_prime, get(padpap.state), get(padpap.action))] = get!(padpap.N_s_prime_sa, (s_prime, get(padpap.state), get(padpap.action)), 0) + 1;
        for t in collect(result_state
                        for ((result_state, state, action), occurrences) in padpap.N_s_prime_sa
                        if (((state, action) == (get(padpap.state), get(padpap.action))) && (occurrences != 0)))
            get!(padpap.mdp.mdp.transitions, (get(padpap.state), get(padpap.action)), Dict())[t] = padpap.N_s_prime_sa[(t, get(padpap.state), get(padpap.action))] / padpap.N_sa[(get(padpap.state), get(padpap.action))];
        end
    end
    local U::Dict = policy_evaluation(padpap.pi, padpap.U, padpap.mdp);
    if (s_prime in padpap.mdp.mdp.terminal_states)
        padpap.state = Nullable();
        padpap.action = Nullable();
    else
        padpap.state = Nullable(s_prime);
        padpap.action = Nullable(padpap.pi[s_prime]);
    end
    if (isnull(padpap.action))
        return nothing;
    else
        return get(padpap.action);
    end
end

function update_state(padpap::PassiveADPAgentProgram, percept::Tuple{Any, Any})
    return percept;
end

#=

    PassiveTDAgentProgram is a passive reinforcement learning agent that learns

    utility estimates by using temporal differences (Fig. 21.4).

=#
type PassiveTDAgentProgram <: AgentProgram
    state::Nullable
    action::Nullable
    reward::Nullable
    gamma::Float64
    U::Dict
    pi::Dict
    N_s::Dict
    terminal_states::Set
    alpha::Function

    function PassiveTDAgentProgram{T <: AbstractMarkovDecisionProcess}(pi::Dict, mdp::T; alpha::Union{Void, Function}=nothing)
        local gamma::Float64;
        local states::Set;
        local terminal_states::Set;
        local new_alpha::Function;
        if (typeof(mdp) <: PassiveADPAgentMDP)
            gamma = mdp.mdp.gamma;
            states = mdp.mdp.states;
            terminal_states = mdp.mdp.terminal_states;
        else
            gamma = mdp.gamma;
            states = mdp.states;
            terminal_states = mdp.terminal_states;
        end
        if (typeof(alpha) <: Void)
            new_alpha = (function(n::Number)
                            return (1/(n + 1));
                        end);
        else
            new_alpha = alpha;
        end
        return new(Nullable(),
                    Nullable(),
                    Nullable(),
                    gamma,
                    Dict(),
                    pi,
                    Dict(),
                    terminal_states,
                    new_alpha);
    end
end

function execute(ptdap::PassiveTDAgentProgram, percept::Tuple{Any, Any})
    local r_prime::Float64;
    s_prime, r_prime = update_state(ptdap, percept);
    if (!haskey(ptdap.N_s, s_prime))
        ptdap.U[s_prime] = r_prime;
    end
    if (!isnull(ptdap.state))
        ptdap.N_s[get(ptdap.state)] = get!(ptdap.N_s, get(ptdap.state), 0) + 1;
        ptdap.U[get(ptdap.state)] = (get!(ptdap.U, get(ptdap.state), 0.0)
                                    + ptdap.alpha(get!(ptdap.N_s, get(ptdap.state), 0))
                                    * (get(ptdap.reward)
                                    + (ptdap.gamma * get!(ptdap.U, s_prime, 0.0))
                                    - get!(ptdap.U, get(ptdap.state), 0.0)));
    end
    if (s_prime in ptdap.terminal_states)
        ptdap.state = Nullable();
        ptdap.action = Nullable();
        ptdap.reward = Nullable();
    else
        ptdap.state = Nullable(s_prime);
        ptdap.action = Nullable(ptdap.pi[s_prime]);
        ptdap.reward = Nullable(r_prime);
    end
    if (isnull(ptdap.action))
        return nothing;
    else
        return get(ptdap.action);
    end
end

function update_state(ptdap::PassiveTDAgentProgram, percept::Tuple{Any, Any})
    return percept;
end

type QLearningAgentProgram <: AgentProgram
    state::Nullable
    action::Nullable
    reward::Nullable
    gamma::Float64
    Q::Dict
    N_sa::Dict
    actions::Set
    terminal_states::Set
    R_plus::Float64 # optimistic estimate of the best possible reward obtainable
    N_e::Int64  # try action-state pair at least N_e times
    f::Function
    alpha::Function

    function QLearningAgentProgram{T <: AbstractMarkovDecisionProcess}(mdp::T, N_e::Int64, R_plus::Float64; alpha::Union{Void, Function}=nothing)
        local new_alpha::Function;
        local gamma::Float64;
        local actions::Set;
        local terminal_states::Set;
        if (typeof(mdp) <: PassiveADPAgentMDP)
            gamma = mdp.mdp.gamma;
            actions = mdp.mdp.actions;
            terminal_states = mdp.mdp.terminal_states;
        else
            gamma = mdp.gamma;
            actions = mdp.actions;
            terminal_states = mdp.terminal_states;
        end
        if (typeof(alpha) <: Void)
            new_alpha = (function(n::Number)
                            return (1/(n + 1));
                        end);
        else
            new_alpha = alpha;
        end
        return new(Nullable(),
                    Nullable(),
                    Nullable(),
                    gamma,
                    Dict(),
                    Dict(),
                    actions,
                    termincal_states,
                    R_plus,
                    N_e,
                    exploration_function,
                    new_alpha);
    end
end

function exploration_function(qlap::QLearningAgentProgram, u::Number, n::Number)
    if (n < qlap.N_e)  
        return qlap.R_plus;
    else
        return u;
    end
end

function actions(qlap::QLearningAgentProgram, state)
    if (state in qlap.terminal_states)
        return Set([nothing]);
    else
        return qlap.actions;
    end
end

function execute(qlap::QLearningAgentProgram, percept::Tuple{Any, Any})
    local r_prime::Float64;
    s_prime, r_prime = update_state(qlap, percept);
    if (!isnull(qlap.state))
        if (get(qlap.state) in qlap.terminal_states)
            qlap.Q[(qlap.state, nothing)] = r_prime;
        end
        qlap.N_sa[(get(qlap.state), get(qlap.action))] = get!(qlap.N_sa, (get(qlap.state), get(qlap.action)), 0) + 1;
        qlap.Q[(get(qlap.state), get(qlap.action))] = get!(qlap.Q, (get(qlap.state), get(qlap.action)), 0.0)
                                                    + (qlap.alpha(qlap.N_sa[(get(qlap.state), get(qlap.action))]) *
                                                    (get(qlap.reward) +
                                                    (qlap.gamma * reduce(max, collect(qlap.Q[(s_prime, a_prime)]
                                                                                    for a_prime in actions(qlap, s_prime)))))
                                                    - qlap.Q[(get(qlap.state), get(qlap.action))]);
        if (get(qlap.state) in qlap.terminal_states)
            qlap.state = Nullable();
            qlap.action = Nullable();
            qlap.reward = Nullable();
        else
            qlap.state = Nullable(s_prime);
            qlap.action = Nullable(argmax(collect(actions(qlap, s_prime)),
                                        (function(a_prime)
                                            return qlap.f(qlap, qlap.Q[(s_prime, a_prime)], qlap.N_sa[(s_prime, a_prime)]);
                                        end)));
            qlap.reward = Nullable(r_prime);
        end
    else
        qlap.state = Nullable(s_prime);
        qlap.action = Nullable(argmax(collect(actions(qlap, s_prime)),
                                    (function(a_prime)
                                        return qlap.f(qlap, qlap.Q[(s_prime, a_prime)], qlap.N_sa[(s_prime, a_prime)]);
                                    end)));
        qlap.reward = Nullable(r_prime);
    end
    if (isnull(qlap.action))
        return nothing;
    else
        return get(qlap.action);
    end
end

function update_state(qlap::QLearningAgentProgram, percept::Tuple{Any, Any})
    return percept;
end

