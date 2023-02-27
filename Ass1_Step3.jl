#Import libraries
using JuMP
using Gurobi
using Printf


#**************************************************

# Define node and transmission data in the 24-bus system

conv_gen_node = [1, 2, 7, 13, 15, 15, 16, 18, 21, 22, 23, 23]   # Node location of conventional generators in the 24-bus system
wind_node = [3, 5, 7, 16, 21, 23]   # Node location of wind farms in the 24-bus system
demand_node = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 13, 14, 15, 16, 18, 19, 20]   # Node location of demand in the 24-bus system

transm_reactance = [[0 0.0146 0.2253 0 0.0907 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0];
                    [0 0 0 0.1356 0 0.205 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0];
                    [0 0 0 0 0 0 0 0 0.1271 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0.084];
                    [0 0 0 0 0 0 0 0 0.111 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0];
                    [0 0 0 0 0 0 0 0 0 0.094 0 0 0 0 0 0 0 0 0 0 0 0 0 0];
                    [0 0 0 0 0 0 0 0 0 0.0642 0 0 0 0 0 0 0 0 0 0 0 0 0 0];
                    [0 0 0 0 0 0 0 0.0652 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0];
                    [0 0 0 0 0 0 0 0 0.1762 0.1762 0 0 0 0 0 0 0 0 0 0 0 0 0 0];
                    [0 0 0 0 0 0 0 0 0 0 0.084 0.084 0 0 0 0 0 0 0 0 0 0 0 0];
                    [0 0 0 0 0 0 0 0 0 0 0.084 0.084 0 0 0 0 0 0 0 0 0 0 0 0];
                    [0 0 0 0 0 0 0 0 0 0 0 0 0.0488 0.0426 0 0 0 0 0 0 0 0 0 0];
                    [0 0 0 0 0 0 0 0 0 0 0 0 0.0488 0 0 0 0 0 0 0 0 0 0.0985 0];
                    [0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0.0844 0];
                    [0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0.0594 0 0 0 0 0 0 0 0];
                    [0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0.0172 0 0 0 0 0.0249 0 0 0.0529];
                    [0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0.0263 0 0.0234 0 0 0 0 0];
                    [0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0.0143 0 0 0 0.1069 0 0];
                    [0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0.0132 0 0 0];
                    [0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0.0203 0 0 0 0];
                    [0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0.0112 0];
                    [0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0.0692 0 0];
                    [0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0];
                    [0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0];
                    [0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0]] # Reactance of transmission lines between each node in p.

transm_capacity =  [[0 175 175 0 350 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0];
                    [0 0 0 175 0 175 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0];
                    [0 0 0 0 0 0 0 0 175 0 0 0 0 0 0 0 0 0 0 0 0 0 0 400];
                    [0 0 0 0 0 0 0 0 175 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0];
                    [0 0 0 0 0 0 0 0 0 350 0 0 0 0 0 0 0 0 0 0 0 0 0 0];
                    [0 0 0 0 0 0 0 0 0 175 0 0 0 0 0 0 0 0 0 0 0 0 0 0];
                    [0 0 0 0 0 0 0 350 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0];
                    [0 0 0 0 0 0 0 0 175 175 0 0 0 0 0 0 0 0 0 0 0 0 0 0];
                    [0 0 0 0 0 0 0 0 0 0 400 400 0 0 0 0 0 0 0 0 0 0 0 0];
                    [0 0 0 0 0 0 0 0 0 0 400 400 0 0 0 0 0 0 0 0 0 0 0 0];
                    [0 0 0 0 0 0 0 0 0 0 0 0 500 500 0 0 0 0 0 0 0 0 0 0];
                    [0 0 0 0 0 0 0 0 0 0 0 0 500 0 0 0 0 0 0 0 0 0 500 0];
                    [0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 500 0];
                    [0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 500 0 0 0 0 0 0 0 0];
                    [0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 500 0 0 0 0 1000 0 0 500];
                    [0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 500 0 500 0 0 0 0 0];
                    [0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 500 0 0 0 500 0 0];
                    [0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 1000 0 0 0];
                    [0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 1000 0 0 0 0];
                    [0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 1000 0];
                    [0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 500 0 0];
                    [0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0];
                    [0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0];
                    [0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0]] # Capacity of transmission lines between each node in MW

#**************************************************

# Conventional Generator Set [1:12]
#G = length(conv_gen_cap)

# Wind farm set
#W = length(wind_cap)

# Demand set
#D = length(demand_cons)

# Number of hours in a day
T = 24

# Number of nodes
N = 24

#**************************************************
# MODEL
Step3=Model(Gurobi.Optimizer)

#Variables - power in MW
@variable(Step3,pg[g=1:G, t=1:T]>=0) #Hourly power generation - Conventional generator g at hour t
@variable(Step3,pw[w=1:W, t=1:T] >=0) #Hourly power generation - Wind farm w at hour t
@variable(Step3,pd[d=1:D, t=1:T] >=0) #Hourly power demand from load d at hour t
@variable(Step3,theta[n=1:N, t=1:T] >=0) #Hourly power angle at node n at hour t

#Objective function
@objective(Step1, Max, sum(demand_bid[d] * pd[d] for d=1:D)  #Total offer value 
                    -sum(conv_gen_cost[g] * pg[g] for g=1:G) #Total value of conventional generator production
                    -sum(wind_cost[w] * pw[w] for w=1:W)    #Total value of wind energy production
                    )

# Capacity constraints
@constraint(Step1,[d=1:D], 0 <= pd[d] <= demand_cons[d] ) # Capacity for demand
@constraint(Step1, [g=1:G], 0 <= pg[g] <= conv_gen_cap[g] ) # (Capacity for conventional generator
@constraint(Step1,[w=1:W], 0 <= pw[w] <= wind_forecast[w] ) # Capacity for Wind farms

# Elasticity constraint, balancing supply and demand
@constraint(Step3, powerbalance,
                0 == sum(pd[d] for t=1:T, d=1:D) - # Demand
                sum(pg[g] for t=1:T, g=1:G) - # Conventional generator production
                sum(pw[w] for t=1:T, w=1:W) # Wind production
                )
