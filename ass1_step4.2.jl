#Import libraries
using JuMP
using Gurobi
using Printf
using Random, Distributions

#***********************************************

#Get Data
include("ass1_data.jl")
include("ass1_step2.jl")

# Input data for hour 22, from step 2. 
DA = market_price[22]                       # Market clearing price
pg8_DA = value.(pg[22,8])                   # Power generation from conventional generator 8
pg_DA = value.(pg[22,:])                    # Power generation from all conventional generators
system_demand_DA = system_demand[22,:] # Total system demand

#***********************************************
# Forecast error wind farm, mean of 1 and standard deviation of 15%
mu = 1 
sigma = 0.15
d = Normal(mu, sigma)
wind_error = rand(d, (24,6))

# System balance (actual wind - forecasted wind - pg8_DA)
system_balance = 
(sum(wind_forecast_hour[22,w] * wind_error[22,w] for w=1:W) 
- sum(wind_forecast_hour[22,w] for w=1:W)
- pg8_DA
)


#***********************************************
# Set parameters

T=24 #Time set

D=17 #Number of demands

W=6 #Number of wind farms

H=2 #Number of electrolizers

Curt = 500 #Curtailment cost

# MODEL
Step4_2 = Model(Gurobi.Optimizer) 

#***********************************************

# Variables
@variable(Step4_2, pgu[g=1:G] >=0)
@variable(Step4_2, pgd[g=1:G] >=0)
@variable(Step4_2, p_dem_curt >=0)

#***********************************************
# Objective function
@objective(Step4_2, Min, 
            sum((DA+conv_gen_cost_hour[22,g] * 0.12) * pgu[g] for g=1:G)
            + Curt * p_dem_curt
            - sum((DA - conv_gen_cost_hour[22,g] * 0.15) * pgd[g] for g=1:G)
            )

#***********************************************
# Constraints

# Balance constraint
@constraint(Step4_2, balance,
            (sum(pgu[g] - pgd[g] for g=1:G) + p_dem_curt)
            == system_balance
            )

# Capacity constraints
@constraint(Step4_2, [g=1:G],
            pgu[g] <= (conv_gen_cap_hour[22,g] - pg_DA[g])
            )

@constraint(Step4_2, [g=1:G],
            pgd[g] <= (pg_DA[g])
            )

@constraint(Step4_2,
            p_dem_curt <= sum(system_demand_DA[d] for d=1:D)
            )

#***********************************************
# Solve model
optimize!(Step4_2)

#***********************************************
# Print results
if termination_status(Step4_2) == MOI.OPTIMAL
    println("Optimal solution found")

    # Save results
    upward_balancing = value.(pgu)
    downward_balancing = value.(pgd)
    curtailment = value.(p_dem_curt)

    # print objective value
    println("Objective value / cost of balancing market: ", objective_value(Step4_2))

    # Deficit / Excess
    if system_balance < 0
        println("The system is in deficit with : " , system_balance, " MW")
    else
        println("The system is in excess with : " , system_balance, " MW")
    end

    # Balancing price
    println("Balancing price ", dual.(balance))

else 
    println("No optimal solution found")
end

