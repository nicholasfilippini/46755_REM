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

# Hydrogen set [24 : 2]
H = 2


# electrolizer required production
electrolizer_minmass_prod = 30000                       # Minimum hydrogen daily mass production (kg)
electrolizer_minpow_cons = electrolizer_minmass_prod/18 # Minimum hydrogen daily energy consumption (MW)
hyd_rev_kg = 0                                         # Revenue per kg of hydrogen (USD)
hyd_rev_mw = hyd_rev_kg * 18                            # Revenue per MW of hydrogen (USD)

#**************************************************
# MODEL
Step5Reserves=Model(Gurobi.Optimizer)

#**************************************************
#Variables 

#Step 2
@variable(Step5Reserves,pg[t=1:T,g=1:G] >=0)      #Hourly power generation - Conventional generator g (MW)
@variable(Step5Reserves,pw[t=1:T,w=1:W] >=0)      #Hourly power generation - Wind farm w (MW) 
@variable(Step5Reserves,h[t=1:T,w=1:H] >=0)       #Hourly power demand for electrolizer (MW)
@variable(Step5Reserves,pd[t=1:T,d=1:D] >=0)      #Hourly power demand (MW)

#Step 5
@variable(Step5Reserves,rgd[t=1:T,g=1:G] >=0)       #Hourly downward reserve from convetional units (MW)
@variable(Step5Reserves,rgu[t=1:T,g=1:G] >=0)       #Hourly upward  reserve from convetional units (MW)
@variable(Step5Reserves,rwu[t=1:T,w=1:H] >=0)       #Hourly upward  reserve from electolizers (MW)
@variable(Step5Reserves,rwd[t=1:T,w=1:H] >=0)       #Hourly downward  reserve from electolizers (MW)


#Objective function
@objective(Step5Reserves, Max, 
sum(demand_bid_hour[t,d] * pd[t,d] for t=1:T,d=1:D)           #Total offer value 
-sum(conv_gen_cost_hour[t,g] * pg[t,g] for t=1:T,g=1:G)       #Total value of conventional generator production
-sum(wind_cost_hour[t,w] * pw[t,w] for t=1:T,w=1:W)           #Total value of wind energy production         
+sum(hyd_rev_mw * h[t,w] for t=1:T,w=1:H)                     #Co optimize for power and hydrogen with fixed revenue of 3$/kg
-sum(rgd[t,g] * pdownwardconv[t,g] for t=1:T,g=1:G)           #Total cost of downward reserve from conventional units 
-sum(rgu[t,g] * pupwardconv[t,g] for t=1:T,g=1:G)             #Total cost of upward reserve from conventional units 
-sum(rwd[t,w] * pdownwardele[t,w] for t=1:T,w=1:H)            #Total cost of downward reserve from electrolizer            
-sum(rwu[t,w] * pupwardele[t,w] for t=1:T,w=1:H)              #Total cost of upward reserve from electrolizer
)

# Capacity constraints for reserves

@constraint(Step5Reserves,[t=1:T,g=1:G], 0 <= rgd[t,g] <= Conv_gen_upward_capability[t,g] )                                                  # upward capability for conventional units (MW)
@constraint(Step5Reserves,[t=1:T,g=1:G], 0 <= rgu[t,g] <= Conv_gen_downward_capability[t,g] )                                                # downward capability for conventional units (MW)
@constraint(Step5Reserves,[t=1:T,w=1:H], 0 <= rwu[t,w] <= Elect_upward_capability[t,w] )                                                     # upnward capability for electrolizer units (MW)
@constraint(Step5Reserves,[t=1:T,w=1:H], 0 <= rwd[t,w] <= Elect_downward_capability[t,w] )                                                   # downward capability for electrolizer units (MW)
@constraint(Step5Reserves, downward[t=1:T], sum(rgd[t,g] for g=1:G) + sum(rwd[t,w] for w=1:H) == 0.15*sum(demand_cons_hour[t, 1:D]))         # Total upnward reserve equal to  15% of total load
@constraint(Step5Reserves, upward[t=1:T], sum(rgu[t,g] for g=1:G) + sum(rwu[t,w] for w=1:H) == 0.2*sum(demand_cons_hour[t, 1:D]))            # Total upnward reserve equal to  20% of total load


# Capacity constraints for power generation

@constraint(Step5Reserves,[t=1:T,d=1:D], 0 <= pd[t,d] <= demand_cons_hour[t,d] )               # Capacity for demand (MW)
@constraint(Step5Reserves,[t=1:T,g=1:G], 0 <= pg[t,g] <= conv_gen_cap_hour[t,g] )              # Capacity for conventional generator (MW)
@constraint(Step5Reserves,[t=1:T,w=1:W], 0 <= pw[t,w] <= wind_forecast_hour[t,w] )             # Capacity for Wind farms without electrolizer (MW)
@constraint(Step5Reserves,[w=1:H], electrolizer_minpow_cons <= sum(h[t,w] for t=1:T))          # Minimum energy used by electrolizer (MW)
@constraint(Step5Reserves,[t=1:T,w=1:H], h[t,w] <= (wind_forecast_hour[t,w]/2))                # Electrolizer capacity is max hald of wf capacity

# Elasticity constraint, balancing supply and demand
@constraint(Step5Reserves, powerbalance[t=1:T],
            0 == 
            sum(pd[t,d] for d=1:D) +    # Demand
            sum(h[t,w] for w=1:H) -     # Power needed by electrolizer seen as demand
            sum(pg[t,g] for g=1:G) -    # Conventional generator production
            sum(pw[t,w] for w=1:W)  # Wind production for wind farm
            )


#************************************************************************
# Solve
solution = optimize!(Step5Reserves)
#**************************************************

rgU_star = zeros((T,G))
rgD_star = zeros((T,G))
rwU_star = zeros((T,H))
rwD_star = zeros((T,H))
price_up = zeros(T)
price_down = zeros(T)

#Check if optimal solution was found
if termination_status(Step5Reserves) == MOI.OPTIMAL
    println("Optimal solution found")

    # Social welfare 
    social_welfare = objective_value(Step5Reserves)
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









    # Save optimal reserve variables and prices.
    rgU_star = value.(rgu[:,:])
    rgD_star = value.(rgd[:,:])
    rwU_star = value.(rwu[:,:])
    rwD_star = value.(rwd[:,:])
    price_up = dual.(upward[:])
    price_down = dual.(downward[:])

    # Print hourly reserves ( upnward and downward) for each one of the conventional units 
    for t = 1: T
         for g = 1 : G
             println("t$t, conventional unit $g, downward reserve : ", value.(rgd[t,g]))
             println("t$t, conventional unit $g, upward reserve : ",   value.(rgu[t,g]))
        end
    end  

    # Print hourly reserves ( upnward and downward) for the two electolizers 
    for t = 1: T
         for w = 1 : H
            println("t$t, electrolizer $w, upward reserve: ", value.(rwu[t,w]))
            println("t$t, electrolizer $w, upward reserve: ", value.(rwd[t,w]))
        end
    end  


else 
    println("No optimal solution found")
end

