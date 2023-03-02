#Import libraries
using JuMP
using Gurobi
using Printf
using CSV, DataFrames
using Plots


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
hyd_rev_kg = 3                                          # Revenue per kg of hydrogen (USD)
hyd_rev_mw = hyd_rev_kg * 18                            # Revenue per MW of hydrogen (USD)

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
-sum(wind_cost_hour[t,w] * pw[t,w] for t=1:T,w=1:W)              #Total value of wind energy production         
+sum(hyd_rev_mw * h[t,w] for t=1:T,w=1:H)     # Co optimize for power and hydrogen with fixed revenue of 3$/kg
)

#**************************************************

# Capacity constraints
@constraint(Step2,[t=1:T,d=1:D], 0 <= pd[t,d] <= demand_cons_hour[t,d] )               # Capacity for demand (MW)
@constraint(Step2,[t=1:T,g=1:G], 0 <= pg[t,g] <= conv_gen_cap_hour[t,g] )              # Capacity for conventional generator (MW)
@constraint(Step2,[t=1:T,w=1:W], 0 <= pw[t,w] <= wind_forecast_hour[t,w] )             # Capacity for Wind farms without electrolizer (MW)
@constraint(Step2,[w=1:H], electrolizer_minpow_cons <= sum(h[t,w] for t=1:T))              # Minimum energy used by electrolizer (MW)
@constraint(Step2,[t=1:T,w=1:H], h[t,w] <= (wind_forecast_hour[t,w]/2))                     # Electrolizer capacity is max hald of wf capacity

# Elasticity constraint, balancing supply and demand
@constraint(Step2, powerbalance[t=1:T],
            0 == 
            sum(pd[t,d] for d=1:D) +    # Demand
            sum(h[t,w] for w=1:H) -     # Power needed by electrolizer seen as demand
            sum(pg[t,g] for g=1:G) -    # Conventional generator production
            sum(pw[t,w] for w=1:W)  # Wind production for wind farm
            )

#************************************************************************
# Solve
solution = optimize!(Step2)
#**************************************************

# Constructing outputs:
market_price = zeros(T)

#Check if optimal solution was found
if termination_status(Step2) == MOI.OPTIMAL
    println("Optimal solution found")

    # Social welfare 
    social_welfare = objective_value(Step2)
    @printf "\nThe value of the social welfare is: %0.3f\n" social_welfare
    
    # Market clearing price
    println("Hourly Market clearing price")
    market_price = dual.(powerbalance[:])
    for t = 1:T
        println("t$t: ", dual(powerbalance[t]))
    end

    # Calculate hourly hydrogen production of each electrolizer
    println("Hourly hydrogen production of each electrolizer")
    for t = 1:T
        for w = 1:H
            println("t$t, w$w: ", value.(h[t,w]))
        end
    end

    # Calculate total hydrogen production of each electrolizer
    println("Total hydrogen production of each electrolizer")
    for w = 1:H
        println("Electrolizer w$w: ", sum(value.(h[t,w]) for t=1:T))
    end
    
    # Profit of conventional generators
    for g=1:G
        profit_conv_gen = []
        for t=1:T
            generation_g = value.(pg[t,g])                      #value of generated power - conventional generator
            cost_g = conv_gen_cost_hour[t,g]                  #Cost of generated power - conventional generator
            profit_g = generation_g * (market_price[t] - cost_g)    #Profit - conventional generator
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
            cost_w = wind_cost_hour[t,w]                      #Cost of generated power - wind farm without electrolizer
            profit_w = generation_w * (market_price[t] - cost_w)    #Profit - wind farm without electrolizer
            append!(profit_wind, profit_w)
        end
        total_w_profit = sum(profit_wind)                        #Total 24H profit for wind farm without electrolizer
        println("The profit of windfarm without electrolizer w$(w) = $(total_w_profit)")
    end

    # Profit of wind farms with electrolizer
    for w=1:2
        profit_wind_market = []
        profit_wind_hydrogen = []
        for t=1:T
            generation_w_hydrogen = value.(h[t,w])
            generation_w_market = value.(pw[t,w]) - generation_w_hydrogen
            cost_w = wind_cost_hour[t,w]
            profit_w_market = generation_w_market * (market_price[t] - cost_w)
            profit_w_hydrogen = generation_w_hydrogen * (hyd_rev_mw - cost_w)
            append!(profit_wind_market, profit_w_market)
            append!(profit_wind_hydrogen, profit_w_hydrogen)
        end
        total_w_market_profit = sum(profit_wind_market)  
        total_w_hydrogen_profit = sum(profit_wind_hydrogen)
        total_w_h_profit = total_w_market_profit + total_w_hydrogen_profit                      #Total 24H profit for wind farm with electrolizer
        println("The market profit of windfarm with electrolizer w$(w) = $(total_w_market_profit)")
        println("The hydrogen profit of windfarm with electrolizer w$(w) = $(total_w_hydrogen_profit)")
        println("The total profit of windfarm with electrolizer w$(w) = $(total_w_h_profit)")
    end


    # Utility of demand: power consumption * (bid price - market price)
    for d=1:D    
        demand_utility = []
        for t=1:T
            utility_d = value.(pd[t,d]) * (demand_bid_hour[t,d] - market_price[t])
            append!(demand_utility, utility_d)
        end
        total_d_utility = sum(demand_utility)
        println("Utility demand of d$(d) = $(total_d_utility)")
    end

else
    error("No solution.")
end
