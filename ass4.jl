#Import libraries
using JuMP
using Gurobi
using Printf
using CSV, DataFrames
using Random, Distributions
using Plots
using PGFPlotsX

#***********************************************
"""
Step 4 of the assignment

1) Wind forecast is affected by a forecasting error which is dependent on 
a normal distribution and it's standard deviation. Decide the std 
arbitrarily but we don't know how...yet 

2) 

3)

"""
#***********************************************
#Expected wind production for each hour in MW
#Add to this the error calculated with the normal distribution
#Get Data
include("Data_ass1.2.jl")

#***********************************************

mu = 0                                                              #The mean of the truncated Normal
sigma = 1                                                           #The standard deviation of the truncated Normal - HOW TO CHOOSE??? 
d = Normal(mu, sigma)                                               #Construct the distribution type
x = rand(d, (24,6))                                                 #Simulate 10000 obs from the truncated Normal
new_wind_forecast_hour = wind_forecast_hour .+ x                    #obtain new values for forecast for wind [24x6] matrix - it changes every
                                                                    # time we run the simulation... no comparing possibility
total_new_wind_forecast_hour = sum(new_wind_forecast_hour;dims=2)   #Total wind production (MW) - for all 6 WF per hour
#***********************************************
#***********************************************

#Time set
T=24

#Number of demand_cons_hour
D=17

# electrolizer required production
electrolizer_minmass_prod = 30000                       # Minimum hydrogen daily mass production (kg)
electrolizer_minpow_cons = electrolizer_minmass_prod/18 # Minimum hydrogen daily energy consumption (MW)

#***********************************************
# MODEL
Step4 = Model(Gurobi.Optimizer) 

#***********************************************

#Constants
total_demand_hour = sum(demand_cons_hour;dims=2)                    #total demand per hour (MW)
const_energy_gen = sum(conv_gen_cap_hour;dims=2)                    #total conv gen production per hour (MW)
#The last constant is the new wind forecast (MW)

total_gen_hour = const_energy_gen + total_new_wind_forecast_hour    #total constant power generation (MW)

energy_imbalance = total_demand_hour - total_gen_hour               #energy imbalance to be compensated by electrolyzer

#***********************************************

#Variables
@variable(Step4,ed[0,energy_imbalance]) #Imbalance that has to be compensated by the electrolyzers
@variable(Step4,curt[0,500])            #Load curtailnment price

#***********************************************

#Objective function

#***********************************************

#Constraints

@constraint(Step4,[t=1:T,w=1:H], electrolizer_minpow_cons <= sum(h[t,w]))   # Minimum energy used by electrolizer (MW)
@constraint(Step4,[t=1:T,w=1:H], h[t,w] <= (wind_cap_hour[t,w]/2))          # Electrolizer capacity is max half of wf capacity

#***********************************************

#Solve


#***********************************************

#Check if optimal solution was found