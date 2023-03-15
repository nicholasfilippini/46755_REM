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


# electrolizer required production
electrolizer_minmass_prod = 30000                       # Minimum hydrogen daily mass production (kg)
electrolizer_minpow_cons = electrolizer_minmass_prod/18 # Minimum hydrogen daily energy consumption (MW)
hyd_rev_kg = 0                                         # Revenue per kg of hydrogen (USD)
hyd_rev_mw = hyd_rev_kg * 18                            # Revenue per MW of hydrogen (USD)

#**************************************************
# MODEL
Step5Reserves=Model(Gurobi.Optimizer)

#**************************************************
#Variables - Step 5 
@variable(Step5Reserves,rgd[t=1:T,g=1:G] >=0)       #Hourly downward reserve from convetional units (MW)
@variable(Step5Reserves,rgu[t=1:T,g=1:G] >=0)       #Hourly upward  reserve from convetional units (MW)
@variable(Step5Reserves,rwu[t=1:T,w=1:H] >=0)       #Hourly upward  reserve from electolizers (MW)
@variable(Step5Reserves,rwd[t=1:T,w=1:H] >=0)       #Hourly downward  reserve from electolizers (MW)


#Objective function
@objective(Step5Reserves, Min, 
sum(rgd[t,g] * pdownwardconv[t,g] for t=1:T,g=1:G)            #Total cost of downward reserve from conventional units 
+sum(rgu[t,g] * pupwardconv[t,g] for t=1:T,g=1:G)             #Total cost of upward reserve from conventional units 
+sum(rwd[t,w] * pdownwardele[t,w] for t=1:T,w=1:H)            #Total cost of downward reserve from electrolizer            
+sum(rwu[t,w] * pupwardele[t,w] for t=1:T,w=1:H)              #Total cost of upward reserve from electrolizer
)

# Capacity constraints for reserves

@constraint(Step5Reserves,[t=1:T,g=1:G], 0 <= rgd[t,g] <= Conv_gen_upward_capability[t,g] )                                                                 # upward capability for conventional units (MW)
@constraint(Step5Reserves,[t=1:T,g=1:G], 0 <= rgu[t,g] <= Conv_gen_downward_capability[t,g] )                                                               # downward capability for conventional units (MW)
@constraint(Step5Reserves,[t=1:T,w=1:H], 0 <= rwu[t,w] <= Elect_upward_capability[t,w] )                                                                    # upnward capability for electrolizer units (MW)
@constraint(Step5Reserves,[t=1:T,w=1:H], 0 <= rwd[t,w] <= Elect_downward_capability[t,w] )                                                                  # downward capability for electrolizer units (MW)
@constraint(Step5Reserves, downward[t=1:T], sum(rgd[t,g] for g=1:G) + sum(rwd[t,w] for w=1:H) == 0.15*sum(demand_cons_hour[t, 1:D]))                        # Total upnward reserve equal to  15% of total load
@constraint(Step5Reserves, upward[t=1:T], sum(rgu[t,g] for g=1:G) + sum(rwu[t,w] for w=1:H) == 0.2*sum(demand_cons_hour[t, 1:D]))                           # Total upnward reserve equal to  20% of total load

@constraint(Step5Reserves, [t=1:T,g=1:G], rgu[t,g] + rgd[t,g] <= conv_gen_cap_hour[t,g] )                                                                   # Total reserve for cg is < than their capacity
@constraint(Step5Reserves, [w=1:H], sum(rwu[t,w] + rwd[t,w] for t=1:T) <= sum(wind_forecast_hour_electrolyzer[t,w]/2 for t=1:T) - electrolizer_minpow_cons) # Upward balancing by electrolyzers < forecasted WF (with electrolyzer) production - 30T 

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

    # Print objective value
    println("Objective value: ", objective_value(Step5Reserves))

    # Save optimal reserve variables and prices.
    rgU_star = value.(rgu[:,:])
    rgD_star = value.(rgd[:,:])
    rwU_star = value.(rwu[:,:])
    rwD_star = value.(rwd[:,:])
    price_up = dual.(upward[:])
    price_down = dual.(downward[:])

    #=
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
    =#

else 
    println("No optimal solution found")
end
