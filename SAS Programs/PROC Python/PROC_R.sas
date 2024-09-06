
/******************/
/* Connect to CAS */
/******************/
libname mycas cas;

/*************************/
/* Load Data into Memory */
/*************************/
data mycas.hmeq;
	set casuser.hmeq;
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

/********************/
/* Create R Graphic */
/********************/
proc iml;

call exportdatasettor("mycas.gradboost_score", "df");
submit / r;

library(ggplot2)
p = ggplot(df, aes(x=I_BAD, y=P_BAD1, color=I_BAD)) + geom_violin(trim=FALSE)
p = p + geom_boxplot(width=0.1) + labs(title="HMEQ Predicted Probabilties Violin Plot",x="P_BAD1", y="Probability") 
p = p + scale_x_discrete(breaks=c("1","2"), labels=c("Events", "Nonevents"))
pdf("/export/home/jobake/vio_r_plot.pdf")
print(p)

endsubmit;
quit;


