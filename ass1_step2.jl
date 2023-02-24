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

#**************************************************

# MODEL
Step2=Model(Gurobi.Optimizer)

#**************************************************
market_clearing_hour = []
total_sw = []

for t in 1:T

    #Variables - power in MW
    @variable(Step2,pg[t,g=1:G] >=0)      #Hourly power generation - Conventional generator g (MW)
    @variable(Step2,pwm[t,w=3:W] >=0)     #Hourly power generation - Wind farm w (MW)
    @variable(Step2, pwh[t,w=1:H] >=0)    #Hourly power generation - Wind farm w with electrolyzer (MW)
    @variable(Step2,pd[t,d=1:D] >=0)      #Hourly power demand (MW)

    @variable(Step2, h[t,w=1:H] >=0)      #Hourly hydrogen production from wind farm w (kg)

    #**************************************************

    #Objective function
    @objective(Step2, Max, 
    sum(demand_bid_hour[t,d] * pd[t,d] for d=1:D)                               #Total offer value 
    -sum(conv_gen_cost_hour[t,g] * pg[t,g] for g=1:G)                           #Total value of conventional generator production
    -sum(wind_cost_hour[t,w] * (pwm[t,w] + pwh[t,w] - (h[t,w])/18) for w=1:W)   #Total value of wind energy production
    )

    #**************************************************

    # Capacity constraints
    @constraint(Step2,[d=1:D], 0 <= pd[t,d] <= demand_cons_hour[t,d] )               # Capacity for demand (MW)
    @constraint(Step2, [g=1:G], 0 <= pg[t,g] <= conv_gen_cap_hour[t,g] )             # Capacity for conventional generator (MW)
    @constraint(Step2,[w=3:W], 0 <= pwm[t,w] <= wind_forecast_hour[t,w] )            # Capacity for Wind farms (MW)
    @constraint(Step2,[w=1:H], 0 <= pwh[t,w] <= (wind_forecast_hour[t,w] - h[t,w]) ) # Capacity for wind farms with electrolizer (MW)
    @constraint(Step2,[w=1:H], electrolizer_minpow_cons <= sum(h[t,w]))              # Minimum energy used by electrolizer (MW)
    @constraint(Step2,[w=1:H], h[t,w] <= (wind_cap_hpur[t,w]/2))                     # Electrolizer capacity is max hald of wf capacity

    # Elasticity constraint, balancing supply and demand
    @constraint(Step2, powerbalance,
                0 == 
                sum(pd[t,d] for d=1:D) +    # Demand
                sum(h[t,w] for h=1:H) -     # Power needed by electrolizer seen as demand
                sum(pg[t,g] for g=1:G) -    # Conventional generator production
                sum(pwm[t,w] for w=3:W) -   # Wind production for wf without electrolizer
                sum(pwh[t,w] for w=1:H)     # Wind production for wf with electrolizer
                )

    #************************************************************************
    # Solve
    solution = optimize!(Step2)
    #**************************************************

    push!(market_clearing_hour,powerbalance)
    push!(total_sw,Max)

    #**************************************************
end

#Check if optimal solution was found
if termination_status(Step2) == MOI.OPTIMAL
    println("Optimal solution found")
    # Market clearing price: Price and quantity
    @printf "\nThe market clearing price: %0.3f\n" market_clearing_hour

    #**************************************************
    # Social welfare 
    @printf "\nThe value of the social welfare is: %0.3f\n" sum(total_sw)

end