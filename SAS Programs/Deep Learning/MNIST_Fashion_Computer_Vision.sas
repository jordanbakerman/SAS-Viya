/*******************************************/
/* Computer Vision with SAS Viya */
/* Image Classification with MNIST_Fashion */
/*******************************************/

/* Load Images */
proc cas;
	loadactionset "image";

	image.loadimages / 
		caslib = "LABDATA"
		path = "mnist_fashion"
		recurse = True, 
		decode = True,
		distribution = "random", 
		labelLevels = 1,
		casout = {name='fashion', blocksize='128', replace=True};
quit;

/* View Images on the CAS Server */
proc cas;
	image.summarizeImages / 
		imageTable = "fashion";

	table.columnInfo / 
		table = "fashion";
quit;

proc freq data=casuser.fashion;
	table _label_;
run;

/* Partition Data into Train, Valid, Test */
proc partition data=casuser.fashion
	samppct=40 samppct2=30 seed=802 partind;
	by _label_;
	output out=casuser.fashion;
run;

proc freq data=casuser.fashion;
	table _partind_;
run;

/* Shuffle Data Before Deep Learning */
proc cas;
	table.shuffle / 
		table = "fashion"
		casout = {name="fashion", replace=1};
quit;

/* Build the CNN Architecture */
proc cas;
	loadactionset "deepLearn";

	/* Model Shell */
	deepLearn.buildModel / 
		modeltable = {name="fashion_cnn", replace = 1}
		type = "CNN";

	/* Data Layer */
	deepLearn.addLayer / 
		model = "fashion_cnn"
		name = "data"
		replace = True
		layer = {type="input", nchannels=1, width=28, height=28, scale=0.004, std="std"};

	/* Convolutional Layer */
	deepLearn.addLayer / 
		model = "fashion_cnn"
		name = "conv1"
		replace = True
		srcLayers = "data"
		layer = {type="convolution", act="relu", nFilters=10, width=5, height=5, stride=1, init="xavier"};

	/* Pooling Layer */
	deepLearn.addLayer / 
		model = "fashion_cnn"
		name = "pool1"
		replace = True
		srcLayers = "conv1"
		layer = {type="pooling", width=2, height=2, stride=2, pool="max"};

	/* Fully Connected Layer */
	deepLearn.addLayer / 
		model = "fashion_cnn"
		name = "fc1"
		replace = True
		srcLayers = "pool1"
		layer = {type="fullconnect", n=100, act="relu", init="xavier", dropout=0.4};

	/* Output Layer */
	deepLearn.addLayer / 
		model = "fashion_cnn"
		name = "out1"
		replace = True
		srcLayers = "fc1"
		layer = {type="output", n=10, act="softmax", init="xavier"};

	/* View the NN Structure */
	deepLearn.modelInfo / 
		model = "fashion_cnn";
quit;

/* Train the Model */
proc cas;
	deepLearn.dlTrain / 
		table = {name="fashion", where="_partind_=1"}
		validTable = {name="fashion", where="_partind_=2"}
		target = "_label_"
		inputs = "_image_"
		seed = "919"
		modelTable = "fashion_cnn"
		modelWeights = {name="fashion_cnn_trained_weights", replace=True}
		optimizer = {miniBatchsize=64, maxEpochs=100, loglevel=1,
			algorithm = {method="momentum", learningRate=0.01}};
quit;

/* Score the Test Partition */
proc cas;
	deepLearn.dlScore / 
		table = {name="fashion", where="_partind_=0"}
		model = "fashion_cnn"
		initWeights = "fashion_cnn_trained_weights"
		copyVars = "_label_"
		layerImageType = "jpg"
		casout = {name="fashion_cnn_scored", replace=True};
quit;

proc print data=casuser.fashion_cnn_scored (obs=5);
run;

/* Find the Confusion Matrix */
ods output CrossTabFreqs = confusion_matrix;
proc freq data=casuser.fashion_cnn_scored;
	table _label_ * _DL_PredName_;
run;

proc print data=work.confusion_matrix;
run;

/* Get the Misclassification Percentage for each Label */
data work.accuracy;
	set work.confusion_matrix;
	where _label_ = _DL_Predname_;
run;

data work.accuracy (keep=_label_ misclassified);
	set work.accuracy NOBS=COUNT;
	if _n_ < count;
	misclassified = 100 - RowPercent;
run;

data work.accuracy;
	set work.accuracy;
	if _label_ = "class0" then label="T-shirt/Top";
	if _label_ = "class1" then label="Trouser";
	if _label_ = "class2" then label="Pullover";
	if _label_ = "class3" then label="Dress";
	if _label_ = "class4" then label="Coat";
	if _label_ = "class5" then label="Sandal";
	if _label_ = "class6" then label="Shirt";
	if _label_ = "class7" then label="Sneaker";
	if _label_ = "class8" then label="Bag";
	if _label_ = "class9" then label="Ankle Boot";
run;

proc print data=accuracy;
run;

/* Create Bar Plot of Results */
proc sgplot data=work.accuracy;
	vbar label / response=misclassified;
	xaxis label="Label";
	yaxis label="Percent";
	title "MNIST Fashion CNN Misclassified";
run;
title;


