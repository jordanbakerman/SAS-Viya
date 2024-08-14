
/********************************************/
/* Read a tax document pdf into a CAS Table */
/********************************************/

/* Create CASLIB Connecting to Folder of PDFs */
proc cas;
	table.addCaslib /
		path = '/export/home/jobake/pdfs/',
		name = 'mypdfs',
		subdirs=true;
quit;

/* Load all PDF Documents in Directory */
proc cas;
	table.loadTable /
		path = '', /* Leave blank to read all files in caslib */
		caslib = 'mypdfs',
		importOptions = {
			fileType = 'DOCUMENT',
			fileExtList = 'PDF',
			tikaConv=TRUE},
		casOut = {name='mypdfs', caslib = 'casuser', replace=TRUE};
quit;

proc print data=casuser.mypdfs;
run;

/* Clean the Data */
data casuser.mypdfs_solution;
	set casuser.myPDFs;
	length FormFields $10000;

	/* Find where the form entries start: f1_1 */
	findFormEntry = find(content,'f1_1');

	/* Create a column with just the form entries */
	/* Remove random special characters */
	FormFields = strip(substr(content,findFormEntry));
	FormFields = tranwrd(FormFields,'09'x,''); /* Remove tabs */
	FormFields = tranwrd(FormFields,'0A'x,''); /* Remove carriage return line feed */

	drop findFormEntry content fileSize path fileType fileDate;
run;

proc print data=casuser.mypdfs_solution;
run;

/* Create UDF to Find Form Fields Between Two Strings */
proc cas;
	source myUDF;
		function find_value(FormFields $, field_to_find $, next_field $) $;

			/* Remove any leading or trailing blanks)*/
			FormFields = strip(FormFields);

			/* Find the position in the text string of the end of the first field */
			find_first_form_position = find(FormFields,field_to_find) + length(field_to_find);

			/* Find the position of the next input text object */
			find_second_form_position = find(FormFields,next_field);

			/* Find length of input text field to pull out */
	        find_length_of_value = find_second_form_position - find_first_form_position;

			/* Pull out the input text field or check box indicator */
			length find_value $500;
			find_value = strip(substr(FormFields,find_first_form_position, find_length_of_value));

			return(find_value);

		endsub;

	endsource;

	/* Add UDF as a function */
	fcmpact.addroutines /
		routineCode = myUDF,
		package = "my_functions",
		saveTable = True,
		appendTable = True,
		funcTable = {name="my_functions", caslib='casuser', replace=True};
quit;

/* Load UDF */
proc cas;
	/* Import the UDF */
	fcmpact.loadfcmptable / 
		table = 'MY_FUNCTIONS.sashdat', 
		caslib = 'casuser', 
		replace = True;

	/* 	Tell CAS where the UDF to use is */
	setSessOpt / cmplib='casuser.my_functions';
quit;

options cmplib=(casuser.my_functions);

/* Create Variables of the Form Fields using the UDF */
data casuser.mypdfs_solution;
	set casuser.mypdfs_solution;

	Employer_ID_Number = find_value(FormFields, 'f1_6:', 'f1_7:');
	Name = find_value(FormFields, 'f1_7:', 'f1_8:');
	SSN = find_value(FormFields, 'f1_9:', 'f1_10:');

run;

proc print data=casuser.mypdfs_solution;
run;

proc contents data=casuser.mypdfs_solution;
run;

/* Alternative Method Without UDF */
/*
data casuser.mypdfs_solution;
	set casuser.mypdfs_solution;

	*Name;
	find_first_form_position = find(FormFields,'f1_7:') + length('f1_7:');
	find_second_form_position = find(FormFields,'f1_8:');
	find_length_of_value = find_second_form_position - find_first_form_position;
	Name = substr(FormFields,find_first_form_position, find_length_of_value);

	*Employer_ID_Number;
	find_first_form_position = find(FormFields,'f1_6:') + length('f1_6:');
	find_second_form_position = find(FormFields,'f1_7:');
	find_length_of_value = find_second_form_position - find_first_form_position;
	Employer_ID_Number = substr(FormFields,find_first_form_position, find_length_of_value);

	*SSN;
	find_first_form_position = find(FormFields,'f1_9:') + length('f1_9:');
	find_second_form_position = find(FormFields,'f1_10:');
	find_length_of_value = find_second_form_position - find_first_form_position;
	SSN = substr(FormFields,find_first_form_position, find_length_of_value);

	drop find_first_form_position find_second_form_position find_length_of_value;
run;

proc print data=casuser.mypdfs_solution;
run;
*/










