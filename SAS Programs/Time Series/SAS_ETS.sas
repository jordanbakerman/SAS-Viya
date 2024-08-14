
/* SAS/ETS Documentation */
/* https://go.documentation.sas.com/doc/en/pgmsascdc/9.4_3.5/allprodsproc/p1vzipzy6l8so0n1gbbh3ae63czb.htm#n00futiq8kb4nxn1c8fj4dyqsk7e */

/*********************************************************************************/
/*********************************************************************************/
/*********************************************************************************/
/*********************************************************************************/
/*********************************************************************************/

/****************/
/* Data Library */
/****************/

*libname tsdata "C:\Users\jobake\Desktop\Courses\stsm51\Data";
libname tsdata "C:\Users\jobake\OneDrive - SAS\Desktop\Courses\stsm51\Data";

/*********************************************************************************/
/*********************************************************************************/
/*********************************************************************************/
/*********************************************************************************/
/*********************************************************************************/

/**************/
/* HELOC Data */
/**************/

data heloc_data;
	set tsdata.heloc_data;
run;

proc contents data=heloc_data;
run;

proc print data=heloc_data;
run;

proc sgplot data=heloc_data;
	series x=date_var y=heloc_dr;
	title 'HELOC Default Rates';
	xaxis label="Month";
	yaxis label="Default Rate";
run;

proc sgplot data=heloc_data;
	series x=date_var y=gdp_gr;
	title 'Gross Domestic Product Growth Rates';
	xaxis label="Month";
	yaxis label="Growth Rate";
run;

proc sgplot data=heloc_data;
	series x=date_var y=inflation;
	title 'Inflation';
	xaxis label="Month";
	yaxis label="Inflation Rate";
run;

proc sgplot data=heloc_data;
	series x=date_var y=heloc_dr / legendlabel='heloc_dr' lineattrs=(color=blue);
	series x=date_var y=gdp_gr / legendlabel='gdp_gr' lineattrs=(color=green);
	series x=date_var y=inflation / legendlabel='inflation' lineattrs=(color=red);
	title 'HELOC - GDP - Inflation';
	xaxis label="Month";
	yaxis label="Rates";
run;
title;

proc timeseries data=heloc_data crossplots=(series);
	id date_var interval=month;
	var heloc_dr;
	crossvar gdp_gr inflation;
run;

proc arima data=heloc_data;
	identify var=heloc_dr crosscorr=(gdp_gr inflation);
	estimate p=0 q=0 input=(gdp_gr inflation) method=ml;
run;
quit;

proc arima data=heloc_data;
	identify var=heloc_dr crosscorr=(gdp_gr inflation);
	estimate p=1 q=0 input=(gdp_gr inflation) method=ml;
run;
quit;

proc arima data=heloc_data;
	identify var=heloc_dr crosscorr=(gdp_gr inflation);
	estimate p=1 q=1 input=(gdp_gr inflation) method=ml;
run;
quit;

proc arima data=heloc_data;
	identify var=heloc_dr crosscorr=(gdp_gr inflation);
	estimate p=1 q=0 input=(gdp_gr inflation) method=ml;
	forecast lead=6 back=6 alpha=0.05 id=date_var interval=month out=out_forecast nooutall;
run;
quit;

/* Find GOF Values */
%macro GOFstats(ModelName=,DSName=,OutDS=,NumParms=0,
                ActualVar=Actual,ForecastVar=Forecast);
data &OutDS;
   attrib Model length=$20
          MAPE  length=8
          NMAPE length=8
          MSE   length=8
          RMSE  length=8
          NMSE  length=8
          NumParm length=8;
   set &DSName end=lastobs;
   retain MAPE MSE NMAPE NMSE 0 NumParm &NumParms;
   Residual=&ActualVar-&ForecastVar;
   /*----  SUM and N functions necessary to handle missing  ----*/
   MAPE=sum(MAPE,100*abs(Residual)/&ActualVar);
   NMAPE=NMAPE+N(100*abs(Residual)/&ActualVar);
   MSE=sum(MSE,Residual**2);
   NMSE=NMSE+N(Residual);
   if (lastobs) then do;
      Model="&ModelName";
      MAPE=abs(MAPE)/NMAPE;
      RMSE=sqrt(MSE/NMSE);
      if (NumParm>0) and (NMSE>NumParm) then 
         RMSE=sqrt(MSE/(NMSE-NumParm));
      else RMSE=sqrt(MSE/NMSE);
      output;
   end;
   keep Model MAPE RMSE NumParm;
run;
%mend GOFstats;

%GOFstats(ModelName=ARIMAX(1,0,0), DSName=work.out_forecast, OutDS=work.gof_vals, 
			NumParms=2, ActualVar=heloc_dr, ForecastVar=forecast);

/* RMSE */
proc print data=gof_vals;
	var model rmse;
run;

/* Expected Loss */
data loss (keep= forecast total_heloc monthly_loss);
	set out_forecast;
	total_heloc = 2500000;
	monthly_loss = (forecast/100)*total_heloc;
run;

proc print data=loss;
	sum monthly_loss;
run;

