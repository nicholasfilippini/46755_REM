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
Step5US=Model(Gurobi.Optimizer)

#**************************************************
#Variables 

#Step 2
@variable(Step5US,pg[t=1:T,g=1:G] >=0)      #Hourly power generation - Conventional generator g (MW)
@variable(Step5US,pw[t=1:T,w=1:W] >=0)      #Hourly power generation - Wind farm (MW) 
@variable(Step5US,h[t=1:T,w=1:H] >=0)       #Hourly power demand for electrolizer (MW)
@variable(Step5US,pd[t=1:T,d=1:D] >=0)      #Hourly power demand (MW)

#Step 5
@variable(Step5US,rgd[t=1:T,g=1:G] >=0)       #Hourly downward reserve from convetional units (MW)
@variable(Step5US,rgu[t=1:T,g=1:G] >=0)       #Hourly upward  reserve from convetional units (MW)
@variable(Step5US,rwu[t=1:T,w=1:H] >=0)       #Hourly upward  reserve from electolizers (MW)
@variable(Step5US,rwd[t=1:T,w=1:H] >=0)       #Hourly downward  reserve from electolizers (MW)


#Objective function
@objective(Step5US, Max, 
sum(demand_bid_hour[t,d] * pd[t,d] for t=1:T,d=1:D)           #Total offer value 
-sum(conv_gen_cost_hour[t,g] * pg[t,g] for t=1:T,g=1:G)       #Total value of conventional generator production
-sum(wind_cost_hour[t,w] * pw[t,w] for t=1:T,w=1:W)           #Total value of wind energy production         
-(sum(rgd[t,g] * pdownwardconv[t,g] for t=1:T,g=1:G)           #Total cost of downward reserve from conventional units 
+sum(rgu[t,g] * pupwardconv[t,g] for t=1:T,g=1:G)             #Total cost of upward reserve from conventional units 
+sum(rwd[t,w] * pdownwardele[t,w] for t=1:T,w=1:H)            #Total cost of downward reserve from electrolizer            
+sum(rwu[t,w] * pupwardele[t,w] for t=1:T,w=1:H))              #Total cost of upward reserve from electrolizer
)
# Capacity constraints for reserves

@constraint(Step5US,[t=1:T,g=1:G], 0 <= rgd[t,g] <= Conv_gen_upward_capability[t,g] )                                                  # upward capability for conventional units (MW)
@constraint(Step5US,[t=1:T,g=1:G], 0 <= rgu[t,g] <= Conv_gen_downward_capability[t,g] )                                                # downward capability for conventional units (MW)
@constraint(Step5US,[t=1:T,w=1:H], 0 <= rwu[t,w] <= Elect_upward_capability[t,w] )                                                     # upnward capability for electrolizer units (MW)
@constraint(Step5US,[t=1:T,w=1:H], 0 <= rwd[t,w] <= Elect_downward_capability[t,w] )                                                   # downward capability for electrolizer units (MW)
@constraint(Step5US, downward[t=1:T], sum(rgd[t,g] for g=1:G) + sum(rwd[t,w] for w=1:H) == 0.15*sum(demand_cons_hour[t, 1:D]))         # Total upnward reserve equal to  15% of total load
@constraint(Step5US, upward[t=1:T], sum(rgu[t,g] for g=1:G) + sum(rwu[t,w] for w=1:H) == 0.2*sum(demand_cons_hour[t, 1:D]))            # Total upnward reserve equal to  20% of total load
@constraint(Step5US, [t=1:T,g=1:G], rgu[t,g] + rgd[t,g] <= conv_gen_cap_hour[t,g] )                                              # Total reserve for cg is < than their capacity
@constraint(Step5US, [w=1:H], sum(rwu[t,w] + rwd[t,w] for t=1:T) <= sum(wind_forecast_hour_electrolyzer[t,w]/2 for t=1:T) - electrolizer_minpow_cons) # Total reserve by electrolyzers < than their capacity - 30 tn 





# Capacity constraints for power generation

@constraint(Step5US,[t=1:T,d=1:D], 0 <= pd[t,d] <= demand_cons_hour[t,d] )                                 # Capacity for demand (MW)
@constraint(Step5US,[t=1:T,g=1:G], rgd[t,g] <= pg[t,g]  )
@constraint(Step5US,[t=1:T,g=1:G], pg[t,g] <= (conv_gen_cap_hour[t,g] - rgu[t,g]) )                        # Capacity for conventional generator (MW)
@constraint(Step5US,[t=1:T,w=1:W], 0 <= pw[t,w] <= wind_forecast_hour[t,w] )                               # Capacity for Wind farms without electrolizer (MW)

@constraint(Step5US,[w=1:H], electrolizer_minpow_cons + sum(rwu[t,w] for t=1:T) <= sum(h[t,w] for t=1:T))                            # Minimum energy used by electrolizer (MW)
@constraint(Step5US,[t=1:T,w=1:H], h[t,w] <= ((wind_forecast_hour_electrolyzer[t,w]/2) - rwd[t,w]))                                  # Electrolizer capacity is max hald of wf capacity

# Elasticity constraint, balancing supply and demand
@constraint(Step5US, powerbalance[t=1:T],
            0 == 
            sum(pd[t,d] for d=1:D) +    # Demand
            sum(h[t,w] for w=1:H) -     # Power needed by electrolizer seen as demand
            sum(pg[t,g] for g=1:G) -    # Conventional generator production
            sum(pw[t,w] for w=1:W)  # Wind production for wind farm
            )


#************************************************************************
# Solve
solution = optimize!(Step5US)
#**************************************************

rgU_star = zeros((T,G))
rgD_star = zeros((T,G))
rwU_star = zeros((T,H))
rwD_star = zeros((T,H))
price_up = zeros(T)
price_down = zeros(T)

social_welfare_hourly = zeros(T)
reserves_cost_hourly = zeros(T)
market_price = zeros(T)

#Check if optimal solution was found
if termination_status(Step5US) == MOI.OPTIMAL
    println("Optimal solution found")

    # Social welfare 
    social_welfare = objective_value(Step5US)
    @printf "\nThe value of the social welfare is: %0.3f\n" social_welfare

    market_price = dual.(powerbalance[:,:])
    
    # Save optimal reserve variables and prices.
    rgU_star = value.(rgu[:,:])
    rgD_star = value.(rgd[:,:])
    rwU_star = value.(rwu[:,:])
    rwD_star = value.(rwd[:,:])
    price_up = dual.(upward[:])
    price_down = dual.(downward[:])
    
    # Save optimal generation of units 
    pd_opt = value.(pd[:,:])
    pg_opt = value.(pg[:,:])
    pw_opt = value.(pw[:,:])

    
    
    for t = 1 : T 
            
        social_welfare_hourly[t] = 
        sum(demand_bid_hour[t,d] * pd_opt[t,d] for d=1:D)                #Total offer value 
        -sum(conv_gen_cost_hour[t,g] * pg_opt[t,g] for g=1:G)            #Total value of conventional generator production
        -sum(wind_cost_hour[t,w] * pw_opt[t,w] for w=1:W) 
        - (sum(rgD_star[t,g] * pdownwardconv[t,g] for g=1:G)               #Total cost of downward reserve from conventional units 
        +sum(rgU_star[t,g] * pupwardconv[t,g] for g=1:G)                 #Total cost of upward reserve from conventional units 
        +sum(rwD_star[t,w] * pdownwardele[t,w] for w=1:H)                #Total cost of downward reserve from electrolizer            
        +sum(rwU_star[t,w] * pupwardele[t,w] for w=1:H) )               #Total value of wind energy production         
    end
    

    for t = 1 : T
        
        reserves_cost_hourly[t]=
        sum(rgD_star[t,g] * pdownwardconv[t,g] for g=1:G)               #Total cost of downward reserve from conventional units 
        +sum(rgU_star[t,g] * pupwardconv[t,g] for g=1:G)                 #Total cost of upward reserve from conventional units 
        +sum(rwD_star[t,w] * pdownwardele[t,w] for w=1:H)                #Total cost of downward reserve from electrolizer            
        +sum(rwU_star[t,w] * pupwardele[t,w] for w=1:H)                  #Total cost of upward reserve from electrolizer
    end 




else 
    println("No optimal solution found")
end


sum(social_welfare_hourly) - sum(reserves_cost_hourly)

test = zeros(T)
for t=1:T
    test[t] = 
    sum(value.(rgd[t,g]) * pdownwardconv[t,g] for g=1:G)           #Total cost of downward reserve from conventional units 
    +sum(value.(rgu[t,g]) * pupwardconv[t,g] for g=1:G)             #Total cost of upward reserve from conventional units 
    +sum(value.(rwd[t,w]) * pdownwardele[t,w] for w=1:H)            #Total cost of downward reserve from electrolizer            
    +sum(value.(rwu[t,w]) * pupwardele[t,w] for w=1:H)
end