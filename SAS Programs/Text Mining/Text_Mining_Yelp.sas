/********************************/
/* Use Case with DATA Step Code */
/********************************/

/* View Yelp Data */
proc print data=casuser.yelp (obs=5);
run;

/* Read in a list of Mexican terms to a SAS table */
data mexican_terms;
	length term $ 100;
	input term $ &;
	datalines;
mexican
taco
tacos
burrito
burritos
margarita
margaritas
;run;

/* Read in a list of Japanese terms to a SAS table */
data japanese_terms;
	length term $ 100;
	input term $ &;
	datalines;
sushi
sake
;run;

/* Create macro variable for the list of Mexican terms */
proc sql;
  select distinct term into : m_terms separated by "," from mexican_terms;
quit;

/* Create macro variable for the list of Japanese terms */
proc sql;
  select distinct term into : j_terms separated by "," from japanese_terms;
quit;

/* View Macro Variables */
%put &m_terms;
%put &j_terms;

data _null_;
	length m_terms_regex $2000 j_terms_regex $2000;

	/* Create Regular Expression for Mexican Terms */
    m_terms_regex = cats('/\b(',tranwrd("&m_terms",',','|'),')\b/i');  

	/* Create macro variable for the RegEx */
	call symputx('m_terms_regex', m_terms_regex);

	/* Create Regular Expression for Japanese Terms */
    j_terms_regex = cats('/\b(',tranwrd("&j_terms",',','|'),')\b/i');  

	/* Create macro variable for the RegEx */
	call symputx('j_terms_regex', j_terms_regex);

run;

/* View the Regular Expressions */
%put &m_terms_regex;
%put &j_terms_regex;

/* Subset Data for testing */
data test;
   set casuser.yelp;
run;

/* Search the data using the regular expressions */
data test (drop= mrx mrx_position jrx jrx_position);
	set test;

   /* Search for Mexican Terms */
   mrx = prxparse("&m_terms_regex");
   mrx_position = prxmatch(mrx, review);

   /* Binary Flag for Mexican Words */
   if mrx_position > 0 then mexican_term=1;
   else mexican_term=0;

	/* Search for Japanese Terms */
   jrx = prxparse("&j_terms_regex");
   jrx_position = prxmatch(jrx, review);

   /* Binary Flag for Japanese Words */
   if jrx_position > 0 then japanese_term=1;
   else japanese_term=0;
run;

/* View Mexican Docuemnts */
proc print data=test;
	where mexican_term=1;
	var review mexican_term;
run;

/* View Japanese Docuemnts */
proc print data=test;
	where japanese_term=1;
	var review japanese_term;
run;

/* View Fusion Docuemnts */
proc print data=test;
	where mexican_term=1 and japanese_term=1;
	var review mexican_term japanese_term;
run;



/**********************************************************************/
/**********************************************************************/
/**********************************************************************/
/**********************************************************************/
/**********************************************************************/
/**********************************************************************/
/**********************************************************************/
/**********************************************************************/
/**********************************************************************/
/**********************************************************************/

/*****************************/
/* Use Case with CAS Actions */
/*****************************/

/*
Writing Concept Rules: Basic LITI Syntax
https://go.documentation.sas.com/doc/en/ctxtcdc/v_015/ctxtug/p1kf71w7npr9ecn1gysvovfs42x2.htm

Example Doc Code
https://go.documentation.sas.com/doc/en/pgmsascdc/v_041/casvtapg/n10niqbompdjrdn1x9dan5dlvtms.htm
*/

/******************/
/* Connect to CAS */
/******************/

libname mycas cas;

data mycas.yelp;
   set casuser.yelp;
run;

/********************/
/* Create Cooncepts */
/********************/

data mycas.concept_rules;
	length config varchar(*);
	infile datalines delimiter='|' missover;
	input config $;
	ruleid+1;
	datalines;
ENABLE:MEXICAN
CASE_INSENSITIVE_MATCH:MEXICAN
CLASSIFIER:MEXICAN: mexican
CONCEPT:MEXICAN: taco@
CONCEPT:MEXICAN: burrito@
CONCEPT:MEXICAN: margarita@

ENABLE:JAPANESE
CASE_INSENSITIVE_MATCH:JAPANESE
CLASSIFIER:JAPANESE: sushi
CLASSIFIER:JAPANESE: sake

ENABLE:FUSION
CASE_INSENSITIVE_MATCH:FUSION
PREDICATE_RULE:FUSION(m_food, j_food):(AND, "_m_food{MEXICAN}", "_j_food{JAPANESE}")
;run;

/*********************/
/* Validate Concepts */
/*********************/

proc cas;                                          
   
	builtins.loadActionSet /                        
		actionSet="textRuleDevelop";
                           
	textRuleDevelop.validateConcept /                
		casOut={name="error", replace=TRUE}
		config="config"
		ruleId="ruleid"
		table={name="concept_rules"};

run;quit;   

proc print data=mycas.error;
run;

/********************/
/* Compile Concepts */
/********************/

proc cas;                                             
   
	builtins.loadActionSet /                           
		actionSet="textRuleDevelop";
                        
	textRuleDevelop.compileConcept /                   
		casOut={name="outli", replace=TRUE}
		ruleid="ruleid"
		config="config"                
		table={name="concept_rules"};

run;quit; 

/******************/
/* Apply Concepts */
/******************/

proc cas;                                             
   
	builtins.loadActionSet /                            
		actionSet="textRuleScore";

	textRuleScore.applyConcept /                      
		casOut={name="out_concept", replace=TRUE}
		docId="seq"
		language = "english"
		factOut={name="out_fact", replace=TRUE}
		model={name="outli"}
		ruleMatchOut={name="out_rule_match", replace=TRUE}
		table={name="yelp"}
		text="review";

run;quit;  

/****************/
/* View Results */
/****************/

/*
proc print data=mycas.out_concept;
run;
*/

proc print data=mycas.out_rule_match;
run;

/*
proc print data=mycas.out_fact;
run;
*/

proc print data=mycas.out_fact;
	where _fact_argument_="";
run;

/*
proc freq data=mycas.out_rule_match order=freq;
	table seq;
run;
*/

proc sql;
    select
        seq,
        _sentence_,
        count(*) as TOTAL_OCCUR
    from mycas.out_rule_match
    group by seq, _sentence_
	order by TOTAL_OCCUR desc;
quit;



/**********************************************************************/
/**********************************************************************/
/**********************************************************************/
/**********************************************************************/
/**********************************************************************/
/**********************************************************************/
/**********************************************************************/
/**********************************************************************/
/**********************************************************************/
/**********************************************************************/

/********************************/
/* Connect to CAS and Load Data */
/********************************/

*libname mycas cas;

data mycas.yelp;
	set casuser.yelp;
run;

data mycas.stoplist;
	set casuser.stop_words;
run;

/*****************************/
/* View Corpus and Stop List */
/*****************************/

proc sql;
	select count(*) as N from mycas.yelp;
quit;

proc print data=mycas.yelp (obs=5);
run;

proc sql;
	select count(*) as N from mycas.stoplist;
quit;

proc print data=mycas.stoplist (obs=5);
run;

/*
data mycas.yelp;
	set mycas.yelp;
	review = lowcase(compress(review,'ABCDEFGHIJKLMNOPQRSTUVWXYZ.!?1234567890 ', 'ki'));
	review = tranwrd(review, ' xxxx', '');
run;
*/

/*****************************************/
/* Subset documents based on search term */
/*****************************************/

data mycas.fusion (drop=newvar1 newvar2);
   set mycas.yelp;
   newvar1 = find(review,"taco","i");
   newvar2 = find(review,"sushi","i");
   if newvar1>0 and newvar2>0;
run;

proc sql;
	select count(*) as N from mycas.fusion;
quit;

proc print data=mycas.fusion;
run;

/******************/
/* Parse the data */
/******************/

/* https://go.documentation.sas.com/doc/en/pgmsascdc/v_041/casvtapg/cas-textparse-tpparse.htm */

proc cas;
	loadactionset 'textParse';
	textParse.tpParse /
	table = "yelp"
	docid = "seq"
	text = "review"
	language = "english"
	stemming = True
	nounGroups = True
	entities = "std"
	tagging = True
	parseConfig = {name="config", replace=True}
	offset = {name="offset", replace=True};
quit;

proc print data=mycas.offset (obs=20);
run;

/********************/
/* Accumulate terms */
/********************/

proc cas;
	textParse.tpAccumulate /
	offset = "offset"
	stopList = "stoplist"
	language = "english"
	stemming = True
	tagging = False
	reduce = 1
	showDroppedTerms = False
	parent = {name="parent", replace=True}
	child = {name="child", replace=True}
	terms = {name="terms", replace=True};
quit;

proc print data=mycas.terms (obs=10);
run;

/*********************************/
/* Get Frequency of Unique Terms */
/*********************************/

data terms_unique;
	set mycas.terms;
	by _Term_;
	if last._Term_;
run;

proc sql;
	CREATE TABLE top_terms AS
	SELECT _Term_, _Frequency_ 
	FROM terms_unique 
	ORDER BY _Frequency_ DESC;
run;

proc sql;
	select count(*) as N from top_terms;
quit;

proc print data=top_terms (obs=100);
run;

data top_top_terms;
	set top_terms (obs=5);
run;

proc sgplot data=top_top_terms;
	vbar _term_ / response=_frequency_;
run;

/**************/
/* Get Topics */
/**************/

proc cas;

	loadactionset 'textmining';
	textmining.tmMine /

	documents = "yelp"
	docid = "seq"
	text = "review"
	language = "english"
	nounGroups = False
	tagging = False
	stemming = True
	stopList = "stoplist"
	reduce = 1
	k = 10
	numLabels = 10
	topicDecision = True

	/* Save same tables from the tpParse Action */
	parseConfig = {name="config", replace=True}
	parent = {name="parent", replace=True}
	child = {name="child", replace=True}
	offset = {name="offset", replace=True}
	terms = {name="terms", replace=True}

	/* Save tables from the tmMine action */
	termTopics = {name="term_topics", replace=True}
	wordPro = {name="wordpro", replace=True}
	docpro = {name="docpro", replace=True}
	topics = {name="topics", replace=True}
	u = {name="svdu", replace=True}
	s = {name="singular_vals", replace=True};

quit;

proc print data=mycas.topics;
run;


