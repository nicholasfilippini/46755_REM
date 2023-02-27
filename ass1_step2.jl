#Import libraries
using JuMP
using Gurobi
using Printf
using CSV, DataFrames


#**************************************************
#Get Data
include("Data_ass1.2.jl")
#**************************************************
# Time set 
T = 24

# Conventional Generator Set [24:12]
G = 12

# Wind farm set [24 : 6]
W = 6

# Demand set [24 : 17]
D = 17

# Hydrogen set
H = 2  

# electrolizer required production
electrolizer_minmass_prod = 30000                       # Minimum hydrogen daily mass production (kg)
electrolizer_minpow_cons = electrolizer_minmass_prod/18 # Minimum hydrogen daily energy consumption (MW)

#**************************************************

# MODEL
Step2=Model(Gurobi.Optimizer)

#**************************************************

#Variables - power in MW
@variable(Step2,pg[t=1:T,g=1:G] >=0)      #Hourly power generation - Conventional generator g (MW)
@variable(Step2,pw[t=1:T,w=1:W] >=0)      #Hourly power generation - Wind farm w (MW) 
@variable(Step2,h[t=1:T,w=1:H] >=0)       #Hourly power demand for electrolizer (MW)
@variable(Step2,pd[t=1:T,d=1:D] >=0)      #Hourly power demand (MW)

#**************************************************

#Objective function
@objective(Step2, Max, 
sum(demand_bid_hour[t,d] * pd[t,d] for t=1:T,d=1:D)                 #Total offer value 
-sum(conv_gen_cost_hour[t,g] * pg[t,g] for t=1:T,g=1:G)             #Total value of conventional generator production
-sum(wind_cost_hour[t,w] * (pw[t,w]) for t=1:T,w=3:W)               #Total value of wind energy production
-sum(wind_cost_hour[t,w] * (pw[t,w] - (h[t,w])) for t=1:T,w=1:H))

#**************************************************

# Capacity constraints
@constraint(Step2,[t=1:T,d=1:D], 0 <= pd[t,d] <= demand_cons_hour[t,d] )               # Capacity for demand (MW)
@constraint(Step2,[t=1:T,g=1:G], 0 <= pg[t,g] <= conv_gen_cap_hour[t,g] )              # Capacity for conventional generator (MW)
@constraint(Step2,[t=1:T,w=3:W], 0 <= pw[t,w] <= wind_forecast_hour[t,w] )             # Capacity for Wind farms without electrolizer (MW)
@constraint(Step2,[t=1:T,w=1:H], 0 <= pw[t,w] + h[t,w]<= (wind_forecast_hour[t,w] ))   # Capacity for wind farms with electrolizer (MW)
@constraint(Step2,[t=1:T,w=1:H], electrolizer_minpow_cons <= sum(h[t,w]))              # Minimum energy used by electrolizer (MW)
@constraint(Step2,[t=1:T,w=1:H], h[t,w] <= (wind_cap_hour[t,w]/2))                     # Electrolizer capacity is max hald of wf capacity

# Elasticity constraint, balancing supply and demand
@constraint(Step2, powerbalance,
            0 == 
            sum(pd[t,d] for t=1:T,d=1:D) +    # Demand
            sum(h[t,w] for t=1:T,w=1:H) -     # Power needed by electrolizer seen as demand
            sum(pg[t,g] for t=1:T,g=1:G) -    # Conventional generator production
            sum(pw[t,w] for t=1:T,w=3:W) -   # Wind production for wf without electrolizer
            sum(pw[t,w] for t=1:T,w=1:H)     # Wind production for wf with electrolizer
            )

#************************************************************************
# Solve
solution = optimize!(Step2)
#**************************************************

#Check if optimal solution was found
if termination_status(Step2) == MOI.OPTIMAL
    println("Optimal solution found")

    # Social welfare 
    social_welfare = objective_value(Step2)
    @printf "\nThe value of the social welfare is: %0.3f\n" social_welfare
    
    # Market clearing price
    for t=1:T
        marketprice = JuMP.dual(powerbalance)
        println("The market clearing price for hour $(t): %0.3f$(marketprice)\n" )
    end
    
    # Profit of conventional generators
    for g=1:G
        profit_conv_gen = []
        for t=1:T
            generation_g = value.(pg[t,g])                      #value of generated power - conventional generator
            cost_g = conv_gen_cost_hour([t,g])                  #Cost of generated power - conventional generator
            profit_g = generation_g * (marketprice - cost_g)    #Profit - conventional generator
            append!(profit_conv_gen, profit_g)
        end
        total_convgen_profit = sum(profit_conv_gen)             #Total 24H profit for conv gen
        println("The total profit for conventional generator g$(g) = $(total_convgen_profit)")
    end

    # Profit of wind farms without electrolizer
    for w=3:W
        profit_wind = []
        for t=1:T
            generation_w = value.(pw[t,w])                      #value of generated power - wind farm without electrolizer
            cost_w = wind_cost_hour([t,w])                      #Cost of generated power - wind farm without electrolizer
            profit_w = generation_w * (marketprice - cost_w)    #Profit - wind farm without electrolizer
            append!(profit_conv_gen, profit_w)
        end
        total_w_profit = sum(profit_w)                        #Total 24H profit for wind farm without electrolizer
        println("The profit of windfarm without electrolizer w$(w) = $(total_w_profit)")
    end

    # Profit of wind farms with electrolizer
    for w=1:2
        profit_wind = []
        for t=1:T
            generation_w = value.(pw[t,w])
            cost_w = wind_cost[t,w]
            profit_w = generation_w * (marketprice - cost_w)
            append!(profit_wind, profit_w)
        end
    end


    # Utility of demand: power consumption * (bid price - market price)
    for d=1:D    
        demand_utility = []
        for t=1:T
            utility_d = value.(pd[t,d]) * (demand_bid_hour[t,d] - marketprice)
            append!(demand_utility, utility_d)
        end
        total_d_utility = sum(demand_utility)
        println("Utility demand of d$(d) = $(total_d_utility)")
    end

else
    error("No solution.")
end