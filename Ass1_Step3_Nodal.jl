#Import libraries
using JuMP
using Gurobi
using Printf
using CSV, DataFrames


#**************************************************
#Get Data
include("ass1_data.jl")
#**************************************************
# Time set 
T = 24

# Conventional Generator Set [24:12]
G = 12

# Wind farm set [24 : 6]
W = 6

# Demand set [24 : 17]
D = 17

# Hydrogen set [24 : 2]
H = 2

# Node set
N = 24

# Sucseptance
B = 500

# electrolizer required production
electrolizer_minmass_prod = 30000                       # Minimum hydrogen daily mass production (kg)
electrolizer_minpow_cons = electrolizer_minmass_prod/18 # Minimum hydrogen daily energy consumption (MW)
hyd_rev_kg = 0                                         # Revenue per kg of hydrogen (USD)
hyd_rev_mw = hyd_rev_kg * 18                            # Revenue per MW of hydrogen (USD)

#**************************************************
# MODEL
Step3Nodal=Model(Gurobi.Optimizer)

#**************************************************

#Variables - power in MW
@variable(Step3Nodal,pg[t=1:T,g=1:G] >=0)      #Hourly power generation - Conventional generator g (MW)
@variable(Step3Nodal,pw[t=1:T,w=1:W] >=0)      #Hourly power generation - Wind farm w (MW) 
@variable(Step3Nodal,h[t=1:T,w=1:H] >=0)       #Hourly power demand for electrolizer (MW)
@variable(Step3Nodal,pd[t=1:T,d=1:D] >=0)      #Hourly power demand (MW)
@variable(Step3Nodal,theta[t=1:T, n=1:N])   #Voltage angle of node n at time t

#**************************************************

#Objective function
@objective(Step3Nodal, Max, 
sum(demand_bid_hour[t,d] * pd[t,d] for t=1:T,d=1:D)                 #Total offer value 
-sum(conv_gen_cost_hour[t,g] * pg[t,g] for t=1:T,g=1:G)             #Total value of conventional generator production
-sum(wind_cost_hour[t,w] * pw[t,w] for t=1:T,w=1:W)              #Total value of wind energy production         
)

# Capacity constraints
@constraint(Step3Nodal,[t=1:T,d=1:D], 0 <= pd[t,d] <= demand_cons_hour[t,d] )               # Capacity for demand (MW)
@constraint(Step3Nodal,[t=1:T,g=1:G], 0 <= pg[t,g] <= conv_gen_cap_hour[t,g] )              # Capacity for conventional generator (MW)
@constraint(Step3Nodal,[t=1:T,w=1:W], 0 <= pw[t,w] <= wind_forecast_hour[t,w] )             # Capacity for Wind farms without electrolizer (MW)
@constraint(Step3Nodal,[w=1:H], electrolizer_minpow_cons <= sum(h[t,w] for t=1:T))              # Minimum energy used by electrolizer (MW)
@constraint(Step3Nodal,[t=1:T,w=1:H], h[t,w] <= (wind_forecast_hour[t,w]/2))                     # Electrolizer capacity is max hald of wf capacity

# Transmission capacity constraint
# For sensitivity analysis, change to transm_capacity_sensitivity
for t=1:T
    for n=1:N
        for m=1:N
            if transm_capacity[n,m] != 0
                @constraint(Step3Nodal,
                -transm_capacity[n,m] <= B * (theta[t, n] - theta[t, m]) <= transm_capacity[n,m])
            end
        end
    end
end
#@constraint(Step3Nodal, transcap[t=1:T,n=1:N,m=1:N], -transm_capacity[n,m] <= B * (theta[t, n] - theta[t, m]) <= transm_capacity[n,m])

# Voltage angle constraint
@constraint(Step3Nodal, [t=1:T,n=1:N], -pi <= theta[t, n] <= pi)

# Reference constraintnode
@constraint(Step3Nodal, [t=1:T], theta[t, 1] == 0)

# Create a function that returns the connected nodes in an ingoing and outgoing direction
connections = length(transm_connections)
function connected_nodes(node)
    outgoing = []
    ingoing = []
    for i=1:connections
        if node == transm_connections[i][1]
            push!(outgoing, transm_connections[i][2])
        elseif node == transm_connections[i][2]
            push!(ingoing, transm_connections[i][1])
        end
    end
    return(outgoing, ingoing)
end

# Elasticity constraint, balancing supply and demand
@constraint(Step3Nodal, powerbalance[t=1:T, n=1:N],
                0 == sum(pd[t, d] for d in node_dem[n]) + # Demand
                sum(h[t, w] for w in node_hyd[n]) + # Hydrogen demand
                sum(B * (theta[t, n] - theta[t, m]) for m in connected_nodes(n)[2]) - # Ingoing transmission lines
                sum(B * (theta[t, m] - theta[t, n]) for m in connected_nodes(n)[1]) - # Outgoing transmission lines
                sum(pg[t, g] for g in node_conv[n]) - # Conventional generator production
                sum(pw[t, w] for w in node_wind[n]) # Wind production
                )


#************************************************************************
# Solve
solution = optimize!(Step3Nodal)
#**************************************************

# Constructing outputs:
market_price = zeros((T,N))
electrolyzer_power = zeros((T,H))
system_demand = zeros((T,D))

#Check if optimal solution was found
if termination_status(Step3Nodal) == MOI.OPTIMAL
    println("Optimal solution found")

    electrolyzer_power = value.(h[:,:])
    market_price = dual.(powerbalance[:,:])
    system_demand = value.(pd[:,:])

    # Print objective value
    println("Objective value: ", objective_value(Step3Nodal))

    #= Remove comment to print market clearing price and power flow in transmission lines .
    
    # Print hourly market price in each node
    println("Hourly Market clearing price")
    market_price = dual.(powerbalance[:])
    for t = 1:T
        for n=1:N
            println("t$t, n$n: ", dual(powerbalance[t,n]))
        end
    end

    Print power flow in each transmission line
    println("Power flow in transmission lines")
    for t = 1:T
    for n=1:N
            for m=1:N
                if transm_capacity[n,m] != 0
                    println("t$t, n$n, m$m: ", B*value(theta[t, n] - theta[t, m]))
                end
            end
        end
    end
=# 

else 
    println("No optimal solution found")
end