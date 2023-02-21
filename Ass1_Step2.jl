#Import libraries
using JuMP
using Gurobi
using Printf


#**************************************************

# Define Parameters for cost and capacity of conventional generators and wind farms
conv_gen_cap = [106.4, 106.4, 245, 413.7, 42, 108.5, 108.5, 280, 280, 210, 217, 245] # Production capacity for conventional generators in MW
conv_gen_cost = [13.32, 13.32, 20.7, 20.93, 26.11, 10.52, 10.52, 6.02, 5.47, 7,	10.52, 10.89] # Production cost for conventional generators in $/MWh
wind_cap = [500, 500, 300, 300,	300, 200] # Production capacity for windfarms in MW
wind_forecast = [120.54, 115.52, 53.34, 38.16, 100, 75] # Day ahead forecast for windfarms in MW
wind_cost =[0, 0, 0, 0, 0, 0] # Production cost for windfarms in $/MWh

# Define demand variables
demand_cons = [84, 75, 139,	58,	55,	106, 97, 132, 135, 150,	205, 150, 245, 77, 258,	141, 100] # Consumption demand in MW
demand_bid = [13, 37, 19, 28, 23, 16, 16, 37, 31, 20, 21, 32, 17, 39, 35, 39, 13] # Cost of demand bids in $/MWh

#**************************************************

# Conventional Generator Set [1:12]
G = length(conv_gen_cap)

# Wind farm set
W = length(wind_cap)

# Demand set
D = length(demand_cons)

# Time set 
T = 24

# Hydrogen set
H = 2

#**************************************************

# MODEL
Step2=Model(Gurobi.Optimizer)

#Variables - power in MW
@variable(Step2,pg[g=1:G] >=0) #Hourly power generation - Conventional generator g
@variable(Step2,pwm[w=3:W] >=0) #Hourly power generation - Wind farm w
@variable(Step2, pwh[w=1:H] >=0) #Hourly power generation - Wind farm w with electrolyzer
@variable(Step2,pd[d=1:D] >=0) #Hourly power demand from load d 
@variable(Step2, h[w=1:H] >=0) #Hourly hydrogen production from wind farm w

#Objective function
@objective(Step2, Max, sum(demand_bid[d] * pd[d] for d=1:D)  #Total offer value 
                    -sum(conv_gen_cost[g] * pg[g] for g=1:G) #Total value of conventional generator production
                    -sum(wind_cost[w] * (pwm[w] + pwh[w] - h[w]) for w=1:W)    #Total value of wind energy production
                    )