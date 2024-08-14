
/******************/
/* Connect to CAS */
/******************/
libname mycas cas;

/*************************/
/* Load Data into Memory */
/*************************/
data mycas.hmeq;
	set public.hmeq;
run;

/*************************/
/* Impute Missing Values */
/*************************/
proc cas;
	dataPreprocess.impute /                          
		table={name="hmeq"}
		inputs={"clage", "clno", "debtinc", "delinq", "derog", "job", "loan", "mortdue", "ninq", "reason", "value", "yoj"}
		methodContinuous="median"
		methodNominal="mode"
		copyVars = "bad"
		casout={name = "hmeq" replace=True};
	run;
quit;

/*********************/
/* Gradient Boosting */
/*********************/
proc gradboost data=mycas.hmeq;
	input imp_clage imp_clno imp_debtinc imp_delinq imp_derog imp_loan imp_mortdue imp_ninq imp_value imp_yoj / level=interval;
	input imp_job imp_reason / level=nominal;
	target bad / level=nominal;
	output out=mycas.gradboost_score;
run;

/************************/
/* View the Scored Data */
/************************/
proc print data=mycas.gradboost_score (obs=5);
run;

/*************************************/
/* Subset Data Based on Target Value */
/*************************************/
data work.ones work.zeros;
	set mycas.gradboost_score;
	if I_BAD=1 then output ones;
	else output zeros;
run;

/*************************/
/* Create Python Graphic */
/*************************/
proc python;
submit;

# Load Python Packages
import matplotlib.pyplot as plt
plt.style.use('fivethirtyeight')

# Bring SAS Table to Python
df1 = SAS.sd2df("work.ones")
df0 = SAS.sd2df("work.zeros")

# Create a Figure Instance
fig, ax = plt.subplots(figsize = (8,8))

# Create the plot
ax.violinplot([df1["P_BAD1"],df0["P_BAD0"]], showmedians=True)

# Plot appearance
plt.title("Violin Plot")
plt.xlabel("P_BAD1")
plt.ylabel("Probability")

# Return to SAS
SAS.pyplot(plt)

endsubmit;
quit;




