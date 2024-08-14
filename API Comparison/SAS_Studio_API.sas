
/******************/
/* Connect to CAS */
/******************/

libname mycas cas;

/*************/
/* View Data */
/*************/

proc print data=public.hmeq_part (obs=5);
run;

proc means data=public.hmeq_part;
	var bad loan mortdue;
run;

proc freq data=public.hmeq_part;
	table bad job reason;
run;

ods select histogram;
proc univariate data=public.hmeq_part;
	var clage clno debtinc delinq derog loan mortdue ninq value yoj;
	histogram;
run;

proc freq data=public.hmeq_part;
	table partind;
run;

/*************************/
/* Impute Missing Values */
/*************************/

%let myInputs = "loan", "mortdue", "value", "reason", "job", "yoj", "derog", "delinq", "clage", "ninq", "clno", "debtinc";

proc cas;
	dataPreprocess.impute /                          
		table={name="hmeq_part", caslib="Public", where = 'partind = 1'}
		inputs={&myInputs}
		methodContinuous="median"
		methodNominal="mode"
		copyAllVars = True
		casOutImputeInformation = {name="impute_info", replace=True}
		casout={name="train", replace=True}
		code = {casOut = {name = "score_code_impute", replace = True}};
	run;
quit;

proc print data=mycas.impute_info;
run;

proc sql;
	select _ContImpute_ into: int_vals separated by ','
		from mycas.impute_info where _ContImpute_ ~=.;
	select quote(trim(_NomImpute_)) into: nom_vals separated by ','
		from mycas.impute_info where _NomImpute_ is not missing;
quit;

%put &int_vals;
%put &nom_vals;

proc cas;
	dataPreprocess.impute /                          
		table={name="hmeq_part", caslib="Public", where = 'partind = 0'}
		inputs={&myInputs}
		methodContinuous="value"
		methodNominal="value"
		valuesInterval={&int_vals}
		valuesNominal={&nom_vals}
		copyAllVars = True
		casOutImputeInformation = {name="impute_info", replace=True}
		casout={name="valid", replace=True};
	run;
quit;

proc print data=mycas.impute_info;
run;

/***********************/
/* Dimension Reduction */
/***********************/

proc varreduce data=mycas.train;
	class imp_job imp_reason;
	reduce unsupervised imp_clage imp_clno imp_debtinc 
						imp_delinq imp_derog imp_loan imp_mortdue 
						imp_ninq imp_value imp_yoj imp_job imp_reason / varexp=0.95;
run;

/***********************/
/* Logistic Regression */
/***********************/

proc genselect data=mycas.train;
 	class imp_job imp_reason;
 	model bad(event='1') = imp_clage imp_clno imp_debtinc 
						   imp_delinq imp_derog imp_loan  
						   imp_ninq imp_value imp_yoj imp_job imp_reason / link=logit dist=binary;
 	selection method=NONE;
	store out=mycas.lr_model;
	code out=mycas.score_code_model;
run;

proc astore;
	score data=mycas.valid 
	rstore=mycas.lr_model
	copyvars=(bad partind)
	out=mycas.lr_scored;
run;

proc assess data=mycas.lr_scored ncuts=100 nbins=100;
	target bad / event="1" level=nominal;
	var p_bad1;
	ods output ROCInfo=work.lr_assess;
run;

data lr_assess_comp (keep = model miscevent c);
	retain model miscevent c;
	set lr_assess;
	where round(cutoff,0.01)=0.50;
	Model = "Logistic Regression CAS";
	label model="Model" miscevent="Misclassification" c="Area Under Curve";
run;

proc print data=lr_assess_comp label;
run;

/*************************************/
/* Get Pipeline DATA Step Score Code */
/*************************************/

data score_code_impute (keep = impute_code);
	rename DataStepSrc = impute_code;
	set mycas.score_code_impute;
run;

data score_code_model (keep = model_code);
	rename DataStepSrc = model_code;
	set mycas.score_code_model;
run;

data score_code (keep = score_code);
	length score_code $ 10000;
	merge score_code_impute score_code_model;
	score_code = CAT(impute_code, model_code);
run;


