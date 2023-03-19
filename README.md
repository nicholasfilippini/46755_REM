# 46755_REM
The aim of these scripts is to solve the Assignmnent 1 of the course "46755 - Renewbles in Electricity Mmarkets".

----------------------------
----------------------------
"ass1_data.jl"

This file is just a database for all the matrixes used in sthe different steps. The other scripts recall this database and it is therefore possible to use variables such as: bid and productio prices, generator capacity, forecasted energy production.  

----------------------------
----------------------------
"ass1_step1.jl"

This script uses the generators capacity, their production price, the forecasts and the demand bidding prices to:
1) Plot the demand and supply curves; 
2) Define the algorithm for the market clearing price of a 1-hour period and therfore determine which suppier and consumer will enter the market based on the objective of maximising the social welfare.

	----------------------------
	----------------------------
	"ass1_supply demand curve plotting.jl"

	This script generates the demand an supply curves for step one, in the sense that it generates the curves for a 1-hour period.

----------------------------
----------------------------
"ass1_step2.jl"

This optimisation problem solves the market clearing problem prioritising the maximisation of social welfare in a 24-hour-period- It is like the step before but extended to a whole day. This implies the intropduction of time-dependent constraints.

1) One new constraint is given by the fact that the hydrogen producyion is set at 30 Tonnes and it is later changed to different values to see how this influences the outputs.

2) The second part of the exercise includes the selling of hydrogen at a set price of 3 euros/kg (electrolizer required production initialised variables) and inserts this data into the objective function to change the social welfare value.

----------------------------
----------------------------
"ass1_Step3_Nodal.jl"

This step determines the market clearing results when a nodal network is taken into account.
The system is seen as a together of single nodes made of each generating unit and the new constraint takes into account the phase (voltage) angle of the general node 'n' at the random time t connected to the node 'm'. This imposes that this mismatch has to be taken into account to consider the amount of energy that can be transferred between nodes and therefore modify the market clearing algorithm.

This constraint is added in the code by creating bounds between each of the 24 nodes and for all the 24 hours.

	----------------------------
	----------------------------
	"ass1_Step3_Zonal.jl"

	We now divide the system in 3 zones. Only these three zones connected between each other for energy transfer purposes.
	The additional constraint refer to the available transfer capacity (ACT) between zones (transmission lines) and not to the phase angle of the transmission lines anymore. 

	1) line 88 - Generate a constraint taking into account the power balancing while being able to exchange power
	
	2) line 97 - Generate a constraint limiting the available transfer capacity from zone a to b
	
	3) line 100 - constraint saying that power can flow in both ways

	----------------------------
	----------------------------
	"ass1_Step2&3_SensitivityAnalysis_plots.ipynb"
	
	This script gathers data for the sensitivity analyses that have to be conducted for the introduction of the hydrogen selling in step 2 and for the different generators income when the market run on a nodal or zonal division in step 3.
	The graphs are explained in the report.
	
----------------------------
----------------------------
"ass1_step4.1.jl"

The script calculates the market clearing results by considering balancing services offered first just by the hydrolizers. This steps also keeps into consideration the grid (nodal) constraints by importing the data from step 3.1.

1) line 17 to 30 - the forecast error is computed as explained in the report and added to the wind forecast;

2) line 70 - constraint that sets the total upward and downward balancing services sum to be equal to the difference between the forecasted and actual wind production

3) line 77, 82 - set that the maximum balancing services should stay within the required production and at the same time should not be lower than the hydrolizer requirements (30T)

4) line 87 - the last constraint ensures that the maximum demand load curtailment never exceeds the total system demand.

----------------------------
----------------------------
"ass1_step4.2.jl"

This step ignores the grid constraint (step 2 imported). 

1) line 68 - balancing the system from failures and deficit/eccess with balancing services

2) line  74 - constraining the balancing production to be within the capacity limit forthe set hour

3) line 115,117 - constraining generator 8 to not produce (failure expected)

	----------------------------
	----------------------------
	"ass1_step4_results_plots.ipynb"
	
	Plots the results obtained for step 4 in terms of system deficit/eccess over time

----------------------------
----------------------------
"ass1_step5.1_eu_reserve.jl"

The algorithm developed calculates the market clearing prices for a 24 hour period subsequentally for every hour. Constraints are set to limit the upward/downward capabiliity of generators and for the reserve energy (lines 56 to 61). 
Further constraints are then set (lines 63-64) to limit the reserve capability compatibly with the generator's production constraints.

	----------------------------
	----------------------------
	"ass1_step5.1_eu_day_ahead.jl"
	
	This script is the second part of the one before. It clears the day ahead market after the reserve market as they do in Europe. 
	Some extra constraints are set:
	
	1) line 64 - limiting the hydrogen production (energy used by electrolyzers) to the WF energy production plus the reserve 
	
	2) line 65 - electrolyzer capacity limited by WF capacity and the reserve for the WF

	----------------------------
	----------------------------
	"Ass1_Step5.1 EU Schedules .ipynb"
	
	Shows the scheduled production of the conventional generators and wind farms for the European-style market
	
	----------------------------
	----------------------------	
	"ass1_Step5.1 plots .ipynb"
	
	1) shows the market balancing by showing how the demand is fitted by adding conventional generator production and wind farm production. The algorithm follows the maximisation of social welfare throughout the process
	
	2) The second graph shows the profits of the generators in the reserve market
	
	3) The third graph shows the profit of the generators in the day ahead market

----------------------------
----------------------------
"ass1_Step5.2_us.jl"

This script solves the same problem as before but clears reserve and day ahead market at the same time as they do in the US.

	----------------------------
	----------------------------
	"Ass1_Step5.2 US Schedules .ipynb"
	
	This script shows the schedules of the US style balancing and day ahead markets for the expected power generation.
