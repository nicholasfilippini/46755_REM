#Import libraries
using JuMP
using Gurobi

#**************************************************
#IMPORT DATA
# Data of IEEE 24-bus reliability test system
#include("Data_Project.jl") #figure out on your own

#**************************************************
# SETS - 
# Time [1:24]
T = length(Time)

# Conventional Generator Set [1:12]
G = length(LGN)

# Wind farm set
W = length(LWFN)

# Demand set
D = length(LDN)

# Charging or Discharging set
CH = 2

#**************************************************
#PARAMETERS
Ud= #bid price of demand d
Cg= #offer price for conventional generator g
Cw=0 #price for wind energy production
PD= #MAX load for demand d
PG= #MAX capacity fro generator G
PW= #MAX capacity of wind farm w

#**************************************************
#**************************************************
# MODEL
Step1=Model(Gurobi.Optimizer)

#Variables - power in MW
@variable(Step1,pg[g=1:G,t=1:T]>=0) #Hourly power generation - Conventional generator g
@variable(Step1,pw[]) #Hourly power generation - Wind farm w
@variable(Step1,pd[]) #Hourly power demand from load d 

#Objective function
@objective(Step1, Max, sum(Ud * PD[d])  #Total offer value 
                    -sum(Cg[g] * PG[g]) #Total value of conventional generator production
                    -sum(Cw * Pw[w])    #Total value of wind energy production
                    )

#Constraints

#MAX demand constraint
@constraint(Step1, [t=1:T,g=1:G], 0 <= pg[g,t] <= CAPG[g] ) # (3b) Capacity for conventional generator
@constraint(Step1,[t=1:T,w=1:W], 0 <= pw[w,t] <= WP[t,w]*CAPW[w] ) # (3c) Capacity for Wind farms

@constraint(Step1,[t=1:T,d=1:D], 0 <= pd[d,t] <= ED[d,t] ) # (3d) Capacity for demand
