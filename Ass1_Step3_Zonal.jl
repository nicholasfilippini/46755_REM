#Import libraries
using JuMP
using Gurobi
using Printf
using CSV, DataFrames
using Plots


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


# Zone from
Z = 3


# electrolizer required production
electrolizer_minmass_prod = 30000                       # Minimum hydrogen daily mass production (kg)
electrolizer_minpow_cons = electrolizer_minmass_prod/18 # Minimum hydrogen daily energy consumption (MW)
hyd_rev_kg = 0                                         # Revenue per kg of hydrogen (USD)
hyd_rev_mw = hyd_rev_kg * 18                            # Revenue per MW of hydrogen (USD)

#**************************************************
# MODEL
Step3Zonal=Model(Gurobi.Optimizer)

#**************************************************

#Variables - power in MW
@variable(Step3Zonal,pg[t=1:T,g=1:G] >=0)      #Hourly power generation - Conventional generator g (MW)
@variable(Step3Zonal,pw[t=1:T,w=1:W] >=0)      #Hourly power generation - Wind farm w (MW) 
@variable(Step3Zonal,h[t=1:T,w=1:H] >=0)       #Hourly power demand for electrolizer (MW)
@variable(Step3Zonal,pd[t=1:T,d=1:D] >=0)      #Hourly power demand (MW)
@variable(Step3Zonal,fz[t=1:T,a=1:Z,b=1:Z])    #Power trading from zone a to zone b
#**************************************************

#Objective function
@objective(Step3Zonal, Max, 
sum(demand_bid_hour[t,d] * pd[t,d] for t=1:T,d=1:D)                 #Total offer value 
-sum(conv_gen_cost_hour[t,g] * pg[t,g] for t=1:T,g=1:G)             #Total value of conventional generator production
-sum(wind_cost_hour[t,w] * pw[t,w] for t=1:T,w=1:W)                 #Total value of wind energy production         
)

# Capacity constraints
@constraint(Step3Zonal,[t=1:T,d=1:D], 0 <= pd[t,d] <= demand_cons_hour[t,d] )               # Capacity for demand (MW)
@constraint(Step3Zonal,[t=1:T,g=1:G], 0 <= pg[t,g] <= conv_gen_cap_hour[t,g] )              # Capacity for conventional generator (MW)
@constraint(Step3Zonal,[t=1:T,w=1:W], 0 <= pw[t,w] <= wind_forecast_hour[t,w] )             # Capacity for Wind farms without electrolizer (MW)
@constraint(Step3Zonal,[w=1:H], electrolizer_minpow_cons <= sum(h[t,w] for t=1:T))          # Minimum energy used by electrolizer (MW)
@constraint(Step3Zonal,[t=1:T,w=1:H], h[t,w] <= (wind_forecast_hour[t,w]/2))                # Electrolizer capacity is max hald of wf capacity

connections = length(zone_connections)

function  connected_zones(zone)
    outgoing = []
    ingoing = []
    for i= 1: connections
        if zone == zone_connections[i][1]
            push!(outgoing, zone_connections[i][2] )
        elseif zone == zone_connections[i][2]
            push!(ingoing, zone_connections[i][1] )
        end
    end
    return(outgoing,ingoing)
end



# Elasticity constraint, balancing supply and demand
@constraint(Step3Zonal, powerbalance[t=1:T, a=1:Z],
                0 == sum(pd[t, d] for d in zone_dem[a]) + # Demand
                sum(h[t, w] for w in zone_hyd[a]) - # Hydrogen demand
                sum(pg[t, g] for g in zone_conv[a]) - # Conventional generator production
                sum(pw[t, w] for w in zone_wind[a]) + # Wind production
                sum(fz[t,a,b] for b in connected_zones(a)[2]) 
                #- sum(fz[t,b,a] for b in connected_zones(a)[1])          # power generated in each zone 
                )

@constraint(Step3Zonal,[t=1:T,a=1:Z, b in connected_zones(a)[2]], -ATCs[b,a] <= fz[t,a,b] <= ATCs[a,b])             # Available transfer capacity from zone a to zone b


@constraint(Step3Zonal,[t=1:T,a=1:Z,b in connected_zones(a)[2]], fz[t,a,b] == -fz[t,b,a])                           # Power flows in both direction
                

#************************************************************************
# Solve
solution = optimize!(Step3Zonal)
#**************************************************

# Constructing outputs:
market_price = zeros(T)

#Check if optimal solution was found
if termination_status(Step3Zonal) == MOI.OPTIMAL
    println("Optimal solution found")

    # Print objective value
    println("Objective value: ", objective_value(Step3Zonal))

    # Print hourly market price in each node
    println("Hourly Market clearing price")
    market_price = dual.(powerbalance[:])
    for t = 1:T
        for a=1:Z
            println("t$t, zone$a: ", dual(powerbalance[t,a]))
        end
    end

 #   println("Power flow")
 #   for t = 1: T
 #       for a = 1: Z
 #          for b in connected_zones(a)[2]
 #                println("t$t, zone$a, to $b: ", value(fz[t,a,b]))
 #            end
 #      end
 #   end
else 
    println("No optimal solution found")
end

