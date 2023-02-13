#Import libraries
using JuMP
using Gurobi

#**************************************************
#IMPORT DATA
# Data of IEEE 24-bus reliability test system
#include("Data_Project.jl") #figure out on your own

# Define Parameters for cost and capacity of conventional generators and wind farms
conv_gen_cap = [106.4, 106.4, 245, 413.7, 42, 108.5, 108.5, 280, 280, 210, 217, 245] # Production capacity for conventional generators in MW
conv_gen_cost = [13.32, 13.32, 20.7, 20.93, 26.11, 10.52, 10.52, 6.02, 5.47, 7,	10.52, 10.89] # Production cost for conventional generators in $/MWh
wind_cap = [500, 500, 300, 300,	300, 200] # Production capacity for windfarms in MW
wind_forecast = [120.54, 115.52, 53.34, 38.16, 100, 75] # Day ahead forecast for windfarms in MW
wind_cost =[0, 0, 0, 0, 0, 0] # Production cost for windfarms in $/MWh

# Define demand variables
demand_cons = [84, 75, 139,	58,	55,	106, 97, 132, 135, 150,	205, 150, 245, 77, 258,	141, 100] # Consumption demand in MW
demand_bid = [13, 37, 19, 28, 23, 16, 16, 37, 31, 20, 21, 32, 17, 39, 35, 39, 13] # Cost of demand bids in $/MWh

#**************************************************
# SETS - 

# Conventional Generator Set [1:12]
G = length(conv_gen_cap)

# Wind farm set
W = length(wind_cap)

# Demand set
D = length(demand_cons)

#**************************************************
# MODEL
Step1=Model(Gurobi.Optimizer)

#Variables - power in MW
@variable(Step1,pg[g=1:G]>=0) #Hourly power generation - Conventional generator g
@variable(Step1,pw[w=1:W] >=0) #Hourly power generation - Wind farm w
@variable(Step1,pd[d=1:D] >=0) #Hourly power demand from load d 

#Objective function
@objective(Step1, Max, sum(demand_bid[d] * pd[d] for d=1:D)  #Total offer value 
                    -sum(conv_gen_cost[g] * pg[g] for g=1:G) #Total value of conventional generator production
                    -sum(wind_cost[w] * pw[w] for w=1:W)    #Total value of wind energy production
                    )

# Capacity constraints
@constraint(Step1,[d=1:D], 0 <= pd[d] <= demand_cons[d] ) # Capacity for demand
@constraint(Step1, [g=1:G], 0 <= pg[g] <= conv_gen_cap[g] ) # (Capacity for conventional generator
@constraint(Step1,[w=1:W], 0 <= pw[w] <= wind_cap[w] ) # Capacity for Wind farms

# Elasticity constraint, balancing supply and demand
@constraint (Step1, 
                    0 ==
                    sum(pd[d] for d=1:D) - # Demand
                    #sum(pg[g] for g=1:G) - # Conventional generator production
                    # sum(pw[w] for w=1:W) # Wind production
                    )

#************************************************************************
# Solve
solution = optimize!(Step1)
#************************************************************************

#Check if optimal solution was found
if termination_status(Step1) == MOI.OPTIMAL
    println("Optimal solution found")
    #objective value
    @println "\nObjective value: %0.3f\n" objective_value(Step1)
    #Print out variable values
    for g=1:G
        println(value.(pg(g)))
    end

    for w=1:W
        println(value.(pw(w)))
    end

    for d=1:D
        println(value.(pd(d)))
    end
    # Market clearing price: Price and quantity.

    # Social welfare 

    # Profit of conventional generators

    # Profit of wind farms

    # Utility of demand: power consumption * (bid price - market price)

    # 

else
    error("No solution.")
end