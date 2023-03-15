using JuMP
using Gurobi
using Printf
using CSV, DataFrames
using Plots


#**************************************************
#Get Data
include("Step 5 reserves.jl")
#**************************************************

#CODE TAKEN FROM STEP 2 AND ADDED CONSTRAINTS
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
Step5DA=Model(Gurobi.Optimizer)

#**************************************************

#Variables - power in MW
@variable(Step5DA,pg[t=1:T,g=1:G] >=0)      #Hourly power generation - Conventional generator g (MW)
@variable(Step5DA,pw[t=1:T,w=1:W] >=0)      #Hourly power generation - Wind farm w (MW) 
@variable(Step5DA,h[t=1:T,w=1:H] >=0)       #Hourly power demand for electrolizer (MW)
@variable(Step5DA,pd[t=1:T,d=1:D] >=0)      #Hourly power demand (MW)

#**************************************************

#Objective function
@objective(Step5DA, Max, 
sum(demand_bid_hour[t,d] * pd[t,d] for t=1:T,d=1:D)         #Total offer value 
-sum(conv_gen_cost_hour[t,g] * pg[t,g] for t=1:T,g=1:G)     #Total value of conventional generator production
-sum(wind_cost_hour[t,w] * pw[t,w] for t=1:T,w=1:W)         #Total value of wind energy production         
)

#**************************************************

# Capacity constraints
@constraint(Step5DA,[t=1:T,d=1:D], 0 <= pd[t,d] <= demand_cons_hour[t,d] )                                      # Capacity for demand (MW)
@constraint(Step5DA,[t=1:T,g=1:G], rgD_star[t,g] <= pg[t,g] <= (conv_gen_cap_hour[t,g] - rgU_star[t,g]))        # Capacity for cg (MW) with the reserve optimal value for cg
@constraint(Step5DA,[t=1:T,w=1:W], 0 <= pw[t,w] <= wind_forecast_hour[t,w] )                                    # Capacity for Wind farms without electrolizer (MW)
@constraint(Step5DA,[w=1:H], electrolizer_minpow_cons + sum(rwU_star[t,w] for t=1:T) <= sum(h[t,w] for t=1:T))  # Minimum energy used by electrolizer (MW) with the reserve optimal value for WF
@constraint(Step5DA,[t=1:T,w=1:H], h[t,w] <= ((wind_forecast_hour_electrolyzer[t,w]/2) - rwD_star[t,w]))        # Electrolizer capacity is max half of wf capacity minus the reserve optimal value for WF

# Elasticity constraint, balancing supply and demand
@constraint(Step5DA, powerbalance[t=1:T],
            0 == 
            sum(pd[t,d] for d=1:D) +    # Demand
            sum(h[t,w] for w=1:H) -     # Power needed by electrolizer seen as demand
            sum(pg[t,g] for g=1:G) -    # Conventional generator production
            sum(pw[t,w] for w=1:W)      # Wind production for wind farm
            )

#************************************************************************
# Solve
solution = optimize!(Step5DA)
#**************************************************

# Constructing outputs:
market_price = zeros(T)

#Check if optimal solution was found
if termination_status(Step5DA) == MOI.OPTIMAL
    println("Optimal solution found")

    # Social welfare 
    social_welfare = objective_value(Step5DA)
    @printf "\nThe value of the social welfare is: %0.3f\n" social_welfare

    market_price = dual.(powerbalance[:,:])
             
else
    error("No solution.")
end