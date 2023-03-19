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
pg_DA[8]=0                                  # Outage in conventional generator 8
system_demand_DA = system_demand[22,:] # Total system demand

#***********************************************
# Forecast error wind farm, mean of 1 and standard deviation of 15%
mu = 1 
sigma = 0.15
d = Normal(mu, sigma)
wind_error = rand(d, (24,6))
# The following matrix contains the stored values for the wind forecast 
# error used to obtain the results in the repot, to generate new values
# comment out or rename the data below.
wind_error = [
    0.90300182384629 0.9128304221131314 0.9497586824988563 0.9166597059396276 1.1006941669967236 0.8550080700652085;
    1.0314604390033524 1.0725047158547318 0.7445762679366232 0.9183155255478167 1.0631331281999934 1.0925483465805;
    0.9560904472618782 0.7041959412393742 1.0791525240487865 1.1034795264045452 0.8052239461914636 1.094353408857913;
    0.8759688900417734 1.0727830545402224 0.9696991135940861 1.2100642706108198 0.8721651238510824 0.80994577670023;
    1.065253434679146 0.8456619235979023 0.8828094097152404 0.8655567232389746 0.9706898970685279 0.9698401892503977;
    0.887823319238341 1.2230044121809487 0.8313122686906929 0.861500096917427 1.1015723040793892 0.780410515877308;
    0.9969243150764203 0.8838353529487571 0.7621990319453368 0.8279907356055995 0.7613085066292484 0.9745098839409653;       
    0.8882896162361938 1.3054783524208282 0.7353946161013315 1.0202091072617132 0.9410846307600649 0.8462392979614696;
    1.0535034068526625 0.9130875497062435 1.1723106942476156 1.1074752401559163 1.1035435898911112 0.9791025874987993;
    0.9961386422465079 0.935577267381993 0.9488658151724885 1.0881572869740161 1.030906253229439 1.125006583473563;
    0.9888640753085579 1.0355794508948764 1.0974266297903956 0.9628877069021438 1.4008933425790469 0.9245565393536792;
    1.3697564683517003 1.2363642301613185 0.7020962189618521 1.0502262823020287 1.0414175609363108 1.0591245523977333;
    0.6366798341842697 1.0908068947764586 0.7486993692501789 0.8582549382921602 1.2963047239920644 0.9532345357317129;
    0.8646705987772838 0.9587666130061638 1.0608581712747043 0.858640933267172 1.2534850778351578 0.719056018791509;
    1.1151412867840518 0.7661847763316975 0.8895730782589085 0.9086228219145096 1.1538018961541117 0.9789825206079595;
    1.0777606317874906 1.3612596442734062 1.0389734847797483 1.0084034473170196 1.1026837316789702 0.9734778892991073;
    0.8754326553281506 1.194180786352818 1.1336556605796593 1.1409633033122981 0.9862937577717036 1.3228477003762689;
    0.946021285065759 0.888409027754886 0.8747325914551639 1.0621781572564875 1.1253768598917362 0.9831283497797567;
    1.0490911579414786 1.0331284410669979 0.9198311289609624 0.996216678545644 1.0233068978494197 1.047975904993177;
    0.7307527809323523 1.206027331580587 0.8683717385817209 0.9806158758475391 0.7319290509939741 0.9820103086241532;
    1.1102030369805918 1.1335306575018094 1.1727693439872147 0.9023595341758918 0.986472587078517 1.0896430927395442;
    1.117066731893009 1.0566468599150525 0.9602365566190498 0.7675631348240306 1.0709852615609345 0.9226065491883789;
    1.2226345226326771 1.2488308316809915 1.1091376849450099 0.9908648122255072 0.8801705618384537 1.0135185729627443;
    1.0018054013894144 1.1023061668154217 0.7034281466565593 1.0593815421099433 0.8847482484926209 1.0828912604830814
    ]
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
            == -system_balance
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
@constraint(Step4_2,
            pgd[8] == 0)
@constraint(Step4_2,
            pgu[8] == 0)
            
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
    balancing_price = dual.(balance)
    # print objective value
    println("Objective value / cost of balancing market: ", objective_value(Step4_2))

    # Deficit / Excess
    if system_balance < 0
        println("The system is in deficit with : " , system_balance, " MW")
    else
        println("The system is in excess with : " , system_balance, " MW")
    end

    # Balancing pricecost
    println("Balancing price ", dual.(balance))

else 
    println("No optimal solution found")
end

total_profit = zeros(G)

# Total profit for each conventional generator considering both day ahead and the balancing market
for g = 1:G
    generation_g = pg_DA[g]
    upwards = value.(pgu[g])
    downwards = value.(pgd[g])
    cost_g = conv_gen_cost_hour[22,g]
    profit_g = (DA*generation_g) + (balancing_price*upwards) - (cost_g*(generation_g+upwards))
    total_profit[g] =profit_g
end
total_profit[8] = (DA*pg8_DA) - (balancing_price*pg8_DA)

println("Total Profits for each  conventional generator ", total_profit)
