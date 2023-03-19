#Import libraries
using JuMP
using Gurobi
using Printf
using Random, Distributions

#***********************************************

#Get Data
include("ass1_data.jl")
include("Ass1_Step3_Nodal.jl")

#***********************************************
# Day ahead market price for step 3.1
DA = market_price[1:24,1]

#***********************************************
# Forecast error wind farm, mean of 1 and standard deviation of 15%
mu = 1 
sigma = 0.15
d = Normal(mu, sigma)
wind_error = rand(d, (24,6))

# System balance (actual wind - forecasted wind)
system_balance = zeros(T)
for t=1:T
    system_balance[t] = sum(wind_forecast_hour[t,w] * wind_error[t,w] for w=1:W) - sum(wind_forecast_hour[t,w] for w=1:W)
end

#***********************************************
# Set parameters

T=24 #Time set

D=17 #Number of demands

W=6 #Number of wind farms

H=2 #Number of electrolizers

Curt = 500 #Curtailment cost

# electrolizer required production
electrolizer_minmass_prod = 30000                       # Minimum hydrogen daily mass production (kg)
electrolizer_minpow_cons = electrolizer_minmass_prod/18 # Minimum hydrogen daily energy consumption (MW)

#***********************************************

# MODEL
Step4_1 = Model(Gurobi.Optimizer) 

#***********************************************

# Decision variables
@variable(Step4_1, hu[t=1:T,w=1:H] >=0)         # Upward balancing from electrolyzers
@variable(Step4_1, hd[t=1:T,w=1:H] >=0)         # Downward balancing from electrolyzers
@variable(Step4_1, p_dem_curt[t=1:T] >=0)       # Curtailment of demand

#***********************************************

# Objective function
@objective(Step4_1, Min,
sum((DA[t] * 1.1) * hu[t,w] for t=1:T, w=1:H)
+ sum(Curt * p_dem_curt[t] for t=1:T)
- sum((DA[t] * 0.85) * hd[t,w] for t=1:T, w=1:H)
)

# Constraints

# Balancing service constraint
@constraint(Step4_1, balance[t=1:T],
sum(hu[t,w] - hd[t,w] for w=1:H) + p_dem_curt[t]
==
system_balance[t]
)

# Electrolizer upward capacity constraints
@constraint(Step4_1, [t=1:T, w=1:H],
hu[t,w] <= ((wind_forecast_hour[t,w]/2) - electrolyzer_power[t,w])
)

# Electrolizer downward capacity constraints
@constraint(Step4_1,
sum(hd[t,w] for t=1:T,w=1:H) <= (sum(electrolyzer_power[t,w] for t=1:T,w=1:H) - electrolizer_minpow_cons)
)

# Demand curtailment constraint
@constraint(Step4_1, [t=1:T],
p_dem_curt[t] <= sum(system_demand[t,d] for d=1:D)
)

#***********************************************
# Solve model
optimize!(Step4_1)

#***********************************************
up_balancing = zeros((T,H))
down_balancing = zeros((T,H))
curt_balancing = zeros(T)

# Print results
if termination_status(Step4_1) == MOI.OPTIMAL
    println("Optimal solution found")

    # print objective value
    println("Objective value: ", objective_value(Step4_1))

    # Save results
    up_balancing = value.(hu[:,:])
    down_balancing = value.(hd[:,:])
    curt_balancing = value.(p_dem_curt[:])

    # print value of needed upward or downward balancing
    for t=1:T
        if system_balance[t] > 0
            println("Hour $t - Upward balancing needed: ", sum(value.(hu[t,w]) for w=1:H))
            println("Hour $t - Curtailment needed: ", value.(p_dem_curt[t]))
        elseif system_balance[t] < 0
            println("Hour $t - Downward balancing needed ", sum(value.(hd[t]) for w=1:H))
        else
            println("Hour $t - No balancing needed")
        end
    end

    # print balancing price
    println("Balancing price ", dual.(balance))

else 
    println("No optimal solution found")
end
