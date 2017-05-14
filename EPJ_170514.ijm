/* version 170514 - MomentMacroJ is renamed as EPJmacro for the public release.
/* version 170208 - TA, CA and MA measurements adjusted to CA=TA - MA formula. Threshold works like J.Hopkins macro.
/* version 161026
/* versuib 161012
/* version 160623
  This macro calculates the anisometry and bulkiness of binary particles
  based on the dynamically equivalent ellipse as defined by Medalia (1970).
  look line 961 and more.
  
  Code was adjusted by Ondrej Sebesta (sebesta@natur.cuni.cz or ondrejsebesta@seznam.cz)
  to help handle manual selections of MRI and Confocal (Leica TCS SP2) images.
  For more credits please look at line 1040-1050.
  tested in FIJI 2.0.0-rc-59/1.51n99 on Linux Mint 64-bit
  java.version: 1.8.0_66
  java.vendor: Oracle Corporation
  os.name: Linux
  os.version: 4.4.0-71-generic
  os.arch: amd64

*/
//******************************* Global Variables *******************************************
var IJPath=getDirectory("imagej"); //get the path to ImageJ folder
var thresholds=getList("threshold.methods"); //get available thresholds
var MRIThreshold=thresholds[9]; //default threshold method for MRI images "Minimum"
var ConfocThr=thresholds[1]; //threshold method for confocal images "Huang"
var original, originalID, name, channel, altDown=false, shiftDown=false, AutoSelectionFail=false;//global variables about image
var option, selection=newArray(2);  //define global variable option and selection
var Sn,Sx,Sy,Sxx,Syy,Sxy,rot2,density,Centrex,Centrey,Theta, R1,R2;  //define MomentJ variables
//define writeResults variables
var Periost, Endoost, original, scalar, units, TA, CA, CA_jh, CA_gs, CA_err_est, MA, Cx, Cy, Ix, Iy, Imax, Imin, Zx, Zy, Xmaxrad, Ymaxrad, xmin, ymin, xmax, ymax, J, Zp, maxRad;
var ostDef=newArray("Null", "Auto", "Manual", "EllipseFromAuto", "EllipseFromManual", "SplineFromAuto", "SplineFromManual", "inner", "outer", "Points", "EllipseFromPoints", "SplineFromPoints", "Threshold");
/*define Default options for a dialog.
0-File Type, 1-Boundary Selection, 2-show selections, 3-show axis, 4-Get dest. dir, 5-Destination dir, 6-periost sel. type, 7-endoost sel. type
8-Force result table, 9-threshold algorithm, 10-Zoom in, 11-Manual thresholding, 12-man.thr.changed flag, 
*/
var defaultOps=newArray(".dcm", "Semi-Automatic", true, true, true, "None", ostDef[1], ostDef[1], false, MRIThreshold, true, false, false);
//******************************* MACROS *****************************************************
/*macro "reInstall EPJ [n9]" {
	run("Install...", "install="+IJPath+"/macros/bones/EPJ_170514.ijm");
	//uncomment and edit path above to be able easily install debbuged version of EPJmacro.
} */

/*macro "set F1/F2 as yoom +/-" {
	run("Add Shortcut... ", "shortcut=F1 command=[In [+]]");
	eval("bsh", "IJ.run(\"Add Shortcut... \", \"shortcut=F1 command=[In [+]]\")");
	eval("bsh", "IJ.run(\"Add Shortcut... \", \"shortcut=F2 command=[Out [-]]\")");
	run("Add Shortcut... ", "shortcut=F2 command=[Out [-]]");
//}*/

macro "Install new version" {
	macroDir=getDirectory("macros");
	sep=File.separator;
	macroFile=File.openDialog("Navigate to EPJ_YYMMDD.ijm source file");
	EPJFile=macroDir+"EPJ.ijm";
	if (macroFile!=EPJFile || File.exists(macroFile)) {
		File.copy(macroFile, EPJFile);
		AutoRunDir=macroDir+"AutoRun"+sep;
		AutoRunFile=AutoRunDir+"install_EPJ.ijm";
		if (!File.exists(AutoRunDir)) File.makeDirectory(AutoRunDir);
		script="macroDir=getDirectory(\"macros\"); run(\"Install...\", \"install=\"+macroDir+\"EPJ.ijm\");";
		File.saveString(script, AutoRunFile);
		if (File.exists(AutoRunFile)) {
			//print("Autoinstallation 'install_EPJ.ijm' file succesfully created in "+AutoRunFile);
			runMacro(AutoRunFile);
			exit ("New version of EPJmacro succesfully installed.");
		}
		else exit ("Installation failed in autorun file creation.");
	}
}

macro "Batch measure [n0]" {  //batch proceed all images in the folder
	altDown=isKeyDown("Alt"); //was Alt pressed? n1 and n0 with alt should force a new measure instead of trying to recover older one. not for .zip files.
	setKeyDown("none");
	run("ROI Manager...");  //runs ROI manager...
	if (!is("Batch Mode")) setBatchMode(true);
	option=getOptions();
	if (!File.isDirectory(option[5])) {
		option[5]=getDirectory("Choose a measurements output directory"); // set the output directory if not yet defined
		option[4]=false;
		setOptions(option);
		}

	inputPath=getDirectory("Choose a directory with "+option[0]+" data");

	if (altDown) {
		print("\\Clear"); //clear the log window before batch mode starts
		run("Clear Results"); //clear results if alt was pressed;
	}

	if (option[0]==".tif") dataType=".tif";
	if (option[0]==".zip") dataType=".zip";
	if (option[0]==".dcm") dataType=".dcm";
	outerSel=option[6]; //get selected Outer selection type
	innerSel=option[7]; //get selected inner selection type

	fileList=getFileList(inputPath);
	for (i=0; i<fileList.length; i++) {
		if (endsWith(fileList[i], dataType)) {
			roiManager("reset");
			if (dataType==".tif" || dataType==".dcm") {
				open(inputPath+fileList[i]);
				//recover selection types if necessary (Auto selection failed);
				if (AutoSelectionFail) {
					option[6]=outerSel;
					option[7]=innerSel;
					AutoSelectionFail=false;
					setOptions(option);
				}		
				MomentMacroJ();
			}
			if (dataType==".zip") {
				roiManager("Reset");
				roiManager("Open", inputPath+fileList[i]);
				name=inputPath+fileList[i];
				measureSelection();
			}
			close();
		}
	}
	if (is("Batch Mode")) setBatchMode(false);
}

macro "EPJ macro [n1]" {
	altDown=isKeyDown("Alt"); //was Alt pressed? n1 with alt should force a new measure instead of trying to recover older one. Only for actual selection Type.
	shiftDown=isKeyDown("Space"); //was Space pressed? Completely new selections. Old will be deleted!
	setKeyDown("none");
	MomentMacroJ();
}

macro "Measure Selection [n2]" {
	measureSelection();
}

macro "Options [n3]"{
  option=getOptions();
  initThd=option[9]; //change threshold initials
  initManThd=option[11];
  Dialog.create("MomentMacro options");
  Dialog.addMessage("This plugin is considered to analyze\nMRI or Confocal bone sections");
  Dialog.addChoice("File type:", newArray(".tif", ".dcm", ".zip"), option[0]);
  Dialog.addChoice("Boundaries creation:", newArray("Threshold","Semi-Automatic"),option[1]);
  Dialog.addCheckbox("Show selection", option[2]);
  Dialog.addCheckbox("Show principal axes", option[3]);
  Dialog.addCheckbox("Get destination directory", option[4]);
  Dialog.addMessage("Actual output directory:");
  Dialog.addMessage(option[5]);
  Dialog.addChoice("Outer selection type:", ostDef, option[6]);
  Dialog.addChoice("Inner selection type:", ostDef, option[7]);
  Dialog.addCheckbox("Force one Result table", option[8]);
  Dialog.addMessage("'Minimum' works well for MRI and 'Huang' for Confocal images:");
  Dialog.addChoice("Threshold method:", thresholds, option[9]);
  Dialog.addCheckbox("Auto ZOOM in", option[10]);
  Dialog.addCheckbox("Manual threshold", option[11]);
  Dialog.show();
  Woption=newArray(); //use Woption to dialog components can be easily added. Remember to add a value to defaultOps!!!
  Woption=Array.concat(Woption, Dialog.getChoice()); //0 imageType / fileType
  Woption=Array.concat(Woption, Dialog.getChoice()); //1 selection method
  Woption=Array.concat(Woption, Dialog.getCheckbox()); //2 show selection
  Woption=Array.concat(Woption, Dialog.getCheckbox()); //3 show axes
  Woption=Array.concat(Woption, Dialog.getCheckbox()); //4 read output directory
  Woption=Array.concat(Woption, option[5]); //5
  Woption=Array.concat(Woption, Dialog.getChoice()); //6 read Periost selection Type
  Woption=Array.concat(Woption, Dialog.getChoice()); //7 read Endoost selection Type
  Woption=Array.concat(Woption, Dialog.getCheckbox()); //8 Force one Result table
  Woption=Array.concat(Woption, Dialog.getChoice()); //9 get Threshold Method
  Woption=Array.concat(Woption, Dialog.getCheckbox()); //10 Auto ZOOM in
  Woption=Array.concat(Woption, Dialog.getCheckbox()); //11 Manual Thresholding
  endThd=Woption[9]; //end Threshold variable
  endManThd=Woption[11];
  if (initThd!=endThd || initManThd!=endManThd) Woption=Array.concat(Woption, true); //12 thresholdChangeFlag
  else Woption=Array.concat(Woption, false);  //12 thresholdChangeFlag
  option=Woption;

  if (option[4]==true) {
	option[5]=getDirectory("Choose an measurements output directory"); //
	option[4]=false;
	}
  if (!File.isDirectory(option[5])) option[5]="None";

  if (option[6]==ostDef[7]) option[6]=ostDef[8]; //exchange "inner" incorrect input to "outer" for Periost
  if (option[7]==ostDef[8]) option[7]=ostDef[7]; //exchange "outer" incorrect input to "inner" for Endoost
  nullErrorHandle(); //solve the two null selection types selected

  if (option[1]=="Threshold" || option[6]==ostDef[12] || option[7]==ostDef[12]) {
  	option[7]=ostDef[0]; //set Endoost to Null option
  	option[6]=ostDef[12]; //set Periost to Threshold option
  }
  //activate or deaktivate channels
  if (nImages>0) {
	getDimensions(width, height, channels, slices, frames);
	if (channels>=3) {
  		activeChannels=activateChannels(channels);
  		Stack.setActiveChannels(activeChannels);
 	 }
  }
  setOptions(option);
} //end of macro Options

//******************************************************************************* FUNCTIONS ***************************************************************************************************************************************
//************************** overiding functions *******************
function MomentMacroJ(){
//if (is("Batch Mode")) setBatchMode("show");
option=getOptions();
if (!File.isDirectory(option[5])) {
	option[5]=getDirectory("Choose an measurements output directory"); //
	option[4]=false;
	setOptions(option);
	}
if (!shiftDown) flagZIP=openZipTif();	//if not space pressed try to open corresponding tif, dcm or zip with selections from original or destination folder.
else flagZIP=false; //if space pressed then starts measurement from begin
//print("FlagZIP "+flagZIP); //debug
if (flagZIP && altDown) {
	//delete respective ROIs for measurement
	vyraz=newArray(ostDef[1], ostDef[2], ostDef[9]);
	peri=option[6]+"Periost"; pvyraz=option[6];
	endo=option[7]+"Endoost"; evyraz=option[7];
	for (v=0; v<vyraz.length; v++) {
		if (indexOf(peri, vyraz[v]+"Periost")!=-1) pvyraz=vyraz[v]+"Periost";
		if (indexOf(endo, vyraz[v]+"Endoost")!=-1) evyraz=vyraz[v]+"Endoost";
	}
	//print(pvyraz+" "+evyraz);
	delAllRoisContaining(pvyraz);
	delAllRoisContaining(evyraz);
}

if (!flagZIP) { // corresponding .zip and .tif file. not found than new Measurement
	run("Select None");
	roiManager("Reset");
	}
if (option[12]) delAllRoisContaining("Auto");

originalID=getImageID();
original=getTitle();
name=original;
AutoCalibrateImage();   //custom function, image callibration control in [mm]
setRelevantChannel();		//in case of multichannel images (confocal) it finds relevant channel
originalID=getImageID(); //refill this variable. it can differ from now.
dir=File.directory;
selectImage(originalID); //for sure you work on right image
prepareROIs();
openResultsTable(); //Try to open existing Results.txt file in dest. directory to add results.
selectImage(originalID);
measureMoments();
saveResults();
} //end of momentMacroJ function
//*********************** measureSelection ***************************
function measureSelection() {
	//if (is("Batch Mode")) setBatchMode(false);
	option=getOptions();
	  if (!File.isDirectory(option[5])) {
		option[5]=getDirectory("Choose an measurements output directory"); //
		option[4]=false;
		setOptions(option);
		}
	path=option[5];
	flagOpen=openZipTif();
	//print("flagOpen in measureSelection "+flagOpen); //debug
	if (roiManager("count")==0) exit("No Selections in ROI Manager!!!"); //if no sel. in RoiManager exit!
	if (flagOpen && nImages!=0) {
		//AutoCalibrateImage();
		setRelevantChannel();
		//setSlice(channel);
	}
	//only measure on current only image
	else if (nImages==0) { //no or one image open  || nImages==1
		//try to open according to last saved .zip
		//if (!flagOpen) {
				 //if last saved/open was not .zip examine selections
				newImage(name+".tif", "8-bit Black", 1024, 1024, 1);
				newID=getImageID();
				//print(name); //debug
				if (startsWith(getTitle(),"0")) {
					showMessage("Error", "Last opened selections was not recognized\nPlease, rename the image manualy.");
					run("Rename...");
					}
				selectROI("AutoPeriost");
				getSelectionBounds(x, y, width, height);
				newX=2*x+width;
				newY=2*y+height;
				run("Canvas Size...", "width="+newX+" height="+newY+" position=Center zero");
				if (selectROI("AutoPeriost")!=-1) {
					setForegroundColor(128, 128,128);
					//Stack.setDisplayMode("color");
					run("Fill", "slice");
					selectROI("AutoEndoost");
					run("Clear", "slice");
					roiManager("Deselect");
					run("Select None");
				}
				else {
					showMessage("Unsucces...", "Able to recreate only nothing from selections in roiManager....");
					selectImage(newID); close();
				}
		//}
	}
	//s
	AutoCalibrateImage();
	setRelevantChannel();
	originalID=getImageID();
	original=getTitle();
	name=original;
	//Stack.setChannel(channel);
	openResultsTable();
	prepareROIs();
	measureMoments();
	saveResults();
}
//************************** openZipTif **************************
function openZipTif() {
		path=option[5];
		origDir=File.directory;
		file=File.name;
		fileWE=File.nameWithoutExtension;
		//try to open according to last open/save file
		if (nImages==0) { //no image open, assume .zip was last openned
			//print("name "+name); //debug
			if (is("Batch Mode")) { //.zip was loaded via roiManager(open) in batch;
				origDir=File.getParent(name); //getInfo("image.directory");
				//print("origDir in batch on "+origDir); //debug
				file=File.getName(name);
				//print("batch on "+name); //debug
				fileWE=replace(file, ".zip", "");
				//fileWE=substring(file, 0, lastIndexOf(file, "."));
				name=fileWE;
			}
		}
		else { //image is open
			origDir=getInfo("image.directory");
			//origDir=File.directory;
			//print(origDir);
			file=getTitle();
			fileWE=substring(file, 0, lastIndexOf(file, "."));
		}
		ext=replace(file, fileWE, "");
		//print(ext);
		opened=false;
		if (ext==".zip") {
			//origDir=File.directory;
			if (option[0]=="Confocal" && File.exists(origDir+fileWE+".tif") && !isOpen(fileWE+".tif")) {
				open(origDir+fileWE+".tif"); //open corresponding .tif image from original dir
				opened=true;
			}
			else if (File.exists(origDir+fileWE+".dcm") && !isOpen(fileWE+".dcm")) {
				open(origDir+fileWE+".dcm"); //open corresponding .dcm image from orig dir
				opened=true;
			}
			else if (File.exists(path+fileWE+".tif") && !isOpen(fileWE+".tif")) {
				if (isOpen(fileWE+".dcm")) {
					selectImage(fileWE+".dcm"); close();
				}
				open(path+fileWE+".tif"); //open corresponding .tif image from dest. dir
				opened=true;
			} else name=fileWE;
		}
		if (ext==".tif" || ext==".dcm") {
			//first open according .tif from destination folder
			if (File.exists(path+fileWE+".tif") && !isOpen(fileWE+".tif") && !altDown) {
				if (isOpen(fileWE+".dcm")) {
					selectImage(fileWE+".dcm"); close(); //close original .dcm
				}
				open(path+fileWE+".tif"); //open corresponding .tif image from dest. dir
				name=fileWE;
			}
			// then try to open .zip from original image folder
			if (File.exists(origDir+fileWE+".zip") && !File.exists(path+fileWE+".zip")) {
				roiManager("Reset");
				roiManager("Open", origDir+fileWE+".zip"); //open corresponding .zip file from original dir.
				opened=true;
			}
			// or from destination image folder if not find yet in original image folder
			else if (File.exists(path+fileWE+".zip")) {
				roiManager("Reset");
				roiManager("Open", path+fileWE+".zip"); //open corresponding .zip file from dest. dir. this is superior!
				opened=true;
			}
		}
		if (opened) name=fileWE;
		//print(fileWE+ext); //debug
		//print("name "+name);
		return opened;
}//end of openZipTif
//************************** setRelevantChannel *****************
function setRelevantChannel(){
	if (!startsWith(getMetadata("info"), "prepared") && bitDepth()==24) prepareImage(); //image is old is prepared, but flattend to RGB
	if (!startsWith(getMetadata("info"), "prepared")) prepareImage(); //kontrola, ze obrazek je pripraveny // || !Stack.isHyperstack
	Stack.getDimensions(width, height, channels, slices, frames);
	if (channel==0) {
		//Stack.getDimensions(width, height, channels, slices, frames);
		if (channels==5 || channels==3) {
			channel=round((channels-2)/2);
			}
		else {
			//showMessageWithCancel("unexpected channel number","The number of channels should now be 5 or 3");
			Stack.setDisplayMode("composite");
			if (is("Batch Mode")) setBatchMode("show");
			Stack.setChannel(1);
			waitForUser("unexpected channel number", "The number of channels expected to be now 5 or 3\nPlease, select the channel for analysis (e.g. set slicer on appropriate channel)\n\nIn five channel we expect second to be analyzed.");
			Stack.getPosition(channel, s, f);
			}
	}
	Stack.setChannel(channel); //set relevant channel active. composite or color mode of channels has to be set separately
	activeChannels=activateChannels(channels);
	Stack.setActiveChannels(activeChannels);
	setMetadata("Label", getTitle()); //label relevant channel with image name
	return(channel);
}
//************************** PREPAREIMAGE **********************
// examine image, prepare for composite
function prepareImage() {
	//1 image is RGB
	image=getTitle();
	metaData=getMetadata("info"); //get original metadata
	if (bitDepth()==24) { //is RGB image?
		run("Make Composite");
		selectImage(image);
		}
	hyperstack=Stack.isHyperstack;	//1. is it hyperstack or not?
	//next 2 lines want to overide nextopen bug which should be fixed in ImageJ daily build (1.51b23)
	getDimensions(width, height, channels, slices, frames);
	if (channels+slices+frames==3 && hyperstack) run("Hyperstack to Stack"); //control of image is ready to be used

	if (!hyperstack){ 	// Kdyz neni hyperstack
		getDimensions(width, height, channels, slices, frames);
		if (is("composite")) { //a je komposit
			run("Stack to Hyperstack...", "order=xyczt(default) channels="+channels+" slices="+slices+" frames="+frames+" display=Composite");
			selectImage(image);
			getDimensions(width, height, channels, slices, frames);
			//stop(); //debug
			}
		else getDimensions(width, height, channels, slices, frames);
		}
	else getDimensions(width, height, channels, slices, frames); //it is hyperstack

	if (slices!=1) {
		//!!!!!! dotaz na projekci !!!!!!!!!!!!!1
		if (is("Batch Mode")) setBatchMode("show");
		waitForUser("Z-Projection","Now examine your stack and decide which slices to include into Z-projection.\nFirst and Last.");
		run("Z Project...");
		max=getTitle();
		selectImage(image); close();
		selectImage(max); rename(image);
		if (is("Batch Mode")) setBatchMode("show");
		}
	//else { //if slices == 1
	getDimensions(width, height, channels, slices, frames);
	if (is("composite")) {
		//print("Executing isComposite code in prepareImage()"); //debug
		run("Stack to Hyperstack...", "order=xyczt(default) channels="+channels+" slices="+slices+" frames="+frames+" display=Composite");
		if (!startsWith(metaData,"prepared")) {
			Stack.setChannel(channels);
			run("Add Slice", "add=channel");
			Stack.setChannel(channels+1);
			run("Yellow");
			setMetadata("Label", "selection");
			run("Add Slice", "add=channel");
			Stack.setChannel(channels+2);
			run("Cyan");
			setMetadata("Label", "principal axes");
			//setMetadata("info", "prepared");
			}
	}
	else { //image is not composite. only pure 8 or 16 bit image
		getLut(reds, greens, blues);
		setSlice(nSlices);
		run("Add Slice", "add=slice");
		run("Add Slice", "add=slice");
		run("Stack to Hyperstack...", "order=xyczt(default) channels="+channels+2+" slices="+slices+" frames="+frames+" display=Composite");
		setLut(reds, greens, blues);
		setSlice(nSlices-1);
		run("Yellow");
		setMetadata("Label", "selection");
		setSlice(nSlices);
		run("Cyan");
		setMetadata("Label", "principal axes");
		setSlice(1);
		}
	setMetadata("info", "prepared\n"+metaData); //set first line of metadata to prepared flag
}
//************************** RECALIBRATE ************************
function recalibrate(){
	getVoxelSize(width, height, depth, unit);
	fail=true;
	if (unit=="pixels") {
		lastName=File.name;
		if (endsWith(lastName,".zip")) {
			lastName=replace(lastName, ".zip", ".tif");
			lastName=replace(lastName, ".txt", ".tif");
			path=File.directory;
			fileName=path+lastName;
			if (File.exists(fileName)) {
				open(fileName);
				getVoxelSize(width, height, depth, unit);
				close();
				setVoxelSize(width, height, depth, unit);
				fail=false;
			}
		}
		else if  (endsWith(lastName, ".tif") || endsWith(lastName, ".dcm")) {
			path=File.directory;
			fileName=path+lastName;
			if (File.exists(fileName)) {
				open(fileName);
				getVoxelSize(width, height, depth, unit);
				close();
				if (unit!="pixels") {
					setVoxelSize(width, height, depth, unit);
					fail=false;
			}
		}
	}
	if (unit==getInfo("micrometer.abbreviation") || unit=="um" || unit=="microns") {
		setVoxelSize(width/1000, height/1000, depth/1000, "mm");
		fail=false;
		}
	if (unit=="m" && width!=1){
		run("Properties...", "unit=um");
		fail=false;
		}
	if (unit=="cm"&& width!=1) {
		setVoxelSize(width*10, height*10, depth*10, "mm");
		fail=false;
		}
	if (fail) {
		if (is("Batch Mode")) setBatchMode("show");
			showMessage("Automatic calibration failed", "Please, calibrate image manually in mm...\nThen press OK");
			run("Properties...");
		}
	}
}
//************************** AUTOCALIBRATEIMAGE ****************
function AutoCalibrateImage() {
	error=false;
	// try to automatic calibrate confocal image from Leica TCS SP2
	lastPath=File.directory;
	lastName=File.name;
	if (indexOf(lastName,"_")!=-1) {
	leiName=substring(lastName,0, indexOf(lastName,"_"));
	if (indexOf(lastName,"_z")==-1 && (indexOf(lastName,"_ch")==-1)) endString=lengthOf(lastName);
	else if (indexOf(lastName,"_z")!=-1) endString=indexOf(lastName, "_z");
	else if (indexOf(lastName,"_z")==-1 && indexOf(lastName,"_ch")!=-1) endString=indexOf(lastName, "_ch");
	imageName=substring(lastName,  indexOf(lastName,"_")+1, endString);
	isThereLei=File.exists(lastPath+leiName+".lei");
	isThereTxt=File.exists(lastPath+leiName+".txt");
	if (isThereLei && isThereTxt){
		TXTfile=File.openAsString(lastPath+leiName+".txt");
		namePos=indexOf(TXTfile, imageName);
		voxPos=indexOf(TXTfile, "Voxel-Width", namePos);
		voxel=substring(TXTfile, voxPos+16, indexOf(TXTfile, "\n", voxPos)-1);
		voxel=parseFloat(voxel);
		zvoxPos=indexOf(TXTfile, "Voxel-Depth", namePos);
		zvoxel=substring(TXTfile, zvoxPos+16, indexOf(TXTfile, "\n", zvoxPos)-1);
		zvoxel=parseFloat(zvoxel);
		if (isNaN(voxel) || isNaN(zvoxel)) error=true;
		else {
			if (isOpen(lastName)) {
				selectImage(lastName);
				setVoxelSize(voxel, voxel, zvoxel, getInfo("micrometer.abbreviation"));
				}
			}
		}
	}
	if (error || !calControl()) errorHandle();
}
//************************** ERRORHANDLE ***************************
function errorHandle(){
	cal=false;
while (cal==false) {
	recalibrate();
	cal=calControl();
	}
}
//************************** CALCONTROL ****************************
function calControl() {
	getPixelSize(unit, v, h);
	if (unit=="mm") return true;
	else return false;
}
//***************************GETOPTIONS******************************
function getOptions(){
	keys = getList('java.properties');
	// global variable defaultOps is defined in macro options !!!!!;
//	IJPath=getInfo(keys[1]);
	if (File.exists(IJPath+"EPJmacro.cfg")) {
		options=File.openAsString(IJPath+"EPJmacro.cfg");
		options=split(options, "\n");
		//print(options.length);  //debug
		//print(defaultOps.length);  //debug
		if (options.length<defaultOps.length) {
			//if geting options are smaller then expected default Option settings do
			lastI=options.length;
			for (i=lastI; i<defaultOps.length; i++) {
				options = Array.concat(options, defaultOps[i]); //add default option to the end of options array
			}
		}
	}
	else options=defaultOps; //set Default options
	//Array.print(options);  //debug
	return options;
}
//***************************SETOPTIONS******************************
function setOptions(options){
	ent="\n";
	string="";
	for (i=0; i<options.length; i++) string=string+options[i]+ent;
	//keys = getList('java.properties');
	File.saveString(string, IJPath+"EPJmacro.cfg");
}
 //*************************************AutoSelectMRI*********************************************
function AutoSelectMRI () {
	//delete Autos first;
	if (selectROI("AutoPeriost")!=-1) roiManager("Delete");
	if (selectROI("AutoEndoost")!=-1) roiManager("Delete");
	if (selectROI(ostDef[12])!=-1) roiManager("Delete"); //delete "Threshold"roi from roiManager
	run("Select None");
	if (option[11]) { //set threshold manualy
		Stack.setDisplayMode("color");
		run("Threshold...");
		setAutoThreshold(option[9]+" dark");
		waitForUser("Now adjust Threshold manualy");
	} 
	else setAutoThreshold(option[9]+" dark"); //set threshold method in Option dialog [n3]
	run("Create Selection");
	roiManager("Add");
	r=roiManager("Count")-1;
	roiManager("Select", r);
	roiManager("Rename", "smazat"); //rename to "Threshold"
//	if (option[6]!=ostDef[12]) { //if option is not Threshold
		if (selectionType()==9) { //selectionType must be composite!
			roiManager("Split");
			rEnd=roiManager("Count")-1;
			delsel=newArray(rEnd-r);
			counter=0;
			for (s=r+1; s<=rEnd; s++) {
				roiManager("Select", s);
				List.setMeasurements;
				delsel[counter]=parseFloat(List.get("Area"));
				counter++;
			}
			sorted=delsel;
			Array.sort(sorted);
			Array.invert(sorted);
			sorted=Array.trim(sorted, 2);
			//Array.print(sorted); //debug
			counter=0;
			while (r<roiManager("count")) {
				roiManager("Select", r);
				List.setMeasurements;
				area=parseFloat(List.get("Area"));
				solidity=parseFloat(List.get("Solidity"));
				if (area==sorted[0]) {
					roiManager("rename", "AutoPeriost");
					if (solidity<=0.9) print(dir+original); //"Autoselection is probaly bad:\n"+
					r++;
				}
				else if (area==sorted[1]) {
					roiManager("rename", "AutoEndoost");
					r++;
				}
				else if (Roi.getName=="smazat"){
					//n=ostDef[12];
					roiManager("rename", ostDef[12]);
					r++;
				}
				else roiManager("delete");
			}
		} //selectionType was composite - ok
		else {
			//set up Threshold selection type
			print(dir+original); //print warning to log window
			if (selectROI("smazat")!=-1) roiManager("rename", ostDef[12]); //rename single non-composite ROI to Threshold
			if (indexOf(option[6], ostDef[1])!=-1 || indexOf(option[7], ostDef[1])!=-1) { //change to Threshold option only if some Auto was selected, but Auto failed to be created
				/*volba=getBoolean("Automatic selection failed!\nAutoPeriost and AutoEndoost selections are needed\nfor some other functions!\n \nTry \"Manual\" selection      YES \nTry \"Threshold\" selection  NO \nExit measurement            CANCEL \n \n \nChange of selection type now will affect \nall other measurements in BATCH Measurements [0]!"
				if (volba) {
					option[6]=ostDef[2]; //set Periost to Manual option
					option[7]=ostDef[2]; //set Endoost to Manual option
				}
				else { //Threshold and Null selected by pressing NO */
					option[6]=ostDef[12]; //set Periost to Threshold option
					option[7]=ostDef[0]; //set Endoost to Null option
					AutoSelectionFail=true; //Flag
				//}
			//showMessage("Warning","Automatic selection failed\nTry \"Manual Threshold\" in Options [n3]\n\nAutoPeriost and AutoEndoost selections are needed\nfor some other functions!");
			}
		}
	Stack.setDisplayMode("Composite");
//	}// Threshold option
} //end of MRI autoselection
//**************************************** checkROIS*******************************************
function checkROIs(i) { //i=6 Periost i=7 Endoost
	//print("checkROIs entered");
	//explicit suffix:
	roiChangeFlag=false;
	if (i==6) suff="Periost";
	if (i==7) suff="Endoost";
	ost=option[i]+suff; //create roiManager name variable

	//case "Auto"
	n=ostDef[1]+suff;
	if (selectROI(n)==-1 || selectROI(ostDef[12])==-1) {
		//roiManager("Show None"); //this override bug with nonsense drawings in overlay
		AutoSelectMRI();
		roiChangeFlag=true;
		//print(n+" changed"); //debug
		}

	//Points possibility
	if (indexOf(option[i], ostDef[9])!=-1) {//if option is some type of "Points"
		n=ostDef[9]+suff;
		if (selectROI(n)==-1) { //check if PointsPeriost exists, otherwise force to create...
			run("Select None");
			getPoints(suff);
			roiManager("Add");
			roiManager("Select", roiManager("Count")-1);
			roiManager("Rename", n);
			roiChangeFlag=true;
			//print(n+" changed"); //debug
		}
		if (option[i]==ostDef[9]) { //if exact use of points not defined, ask
			n=ostDef[9]+suff;
			selectROI(n);
			if (getBoolean(suff+"\nClick YES if "+ostDef[10]+" shloud be used\nClick NO if "+ostDef[11]+" should be used\n\nDo not click Cancel!")==true) {
				option[i]=ostDef[10];
				roiChangeFlag=true;
				//print("changed from points to "+option[i]+suff);
			} else option[i]=ostDef[11]; roiChangeFlag=true;
		//setOptions(option);
		}
		ost=option[i]+suff; //update roiManager name variable
	} 
	// "inner" or "outer" or "Threshold" possibility
	else if (option[i]==ostDef[7] || option[i]==ostDef[8]) {
		ost=option[i]; //create roiManager name variable
	}
	if (option[i]!=ostDef[0] && option[i]!=ostDef[12]) { //if "Null" or "Threshold" is not selected then:
		//print("befor while ost "+ost); //debug
		while (selectROI(ost)==-1) { //repeat until selection type exist or problem is solved!
			//print("while cycle"); //debug
			//case "Manual"
			if (indexOf(option[i], ostDef[2])!=-1) {
				n=ostDef[2]+suff;
				if (selectROI(n)==-1) { //check if ManualPeriost/Endoost exists, otherwise force to create...
					run("Select None");
					setTool("polygon");
					addROItitle=ostDef[2]+suff+" selection";
					addROImsg="Please make "+ostDef[2]+suff+" selection!";
					addROInewName=ostDef[2]+suff;
					addROI(-1, addROItitle, addROImsg, addROInewName); //selectROI("Auto"+suff)
					roiChangeFlag=true; 
					//print(n+" changed"); //debug
				}
			}
			//case "EllipseFromAuto"
			if (option[i]==ostDef[3]) {
				n=ostDef[1]+suff;
				selectROI(n);
				createFrom("Ellipse", i);
				roiChangeFlag=true;
				//print(n+" changed"); //debug
			}
			//case "EllipseFromManual"
			if (option[i]==ostDef[4]) {
				n=ostDef[2]+suff;
				selectROI(n);
				createFrom("Ellipse", i);
				roiChangeFlag=true;
				//print(n+" changed"); //debug
			}
			//case "SplineFromAuto"
			if (option[i]==ostDef[5]) {
				n=ostDef[1]+suff;
				selectROI(n);
				run("Fit Spline");
				createFrom("Spline", i);
				roiChangeFlag=true;
				//print(n+" changed"); //debug
			}
			//case "SplineFromManual"
			if (option[i]==ostDef[6]) {
				n=ostDef[2]+suff;
				selectROI(n);
				createFrom("Spline", i);
				roiChangeFlag=true;
				//print(n+" changed"); //debug
			}
			//case "EllipseFromPoints
			if (option[i]==ostDef[10]) {
				n=ostDef[9]+suff;
				selectROI(n);
				createFrom("Ellipse", i);
				roiChangeFlag=true;
				//print(n+" changed"); //debug
			}
			//case "SplineFromPoints"
			if (option[i]==ostDef[11]) {
				n=ostDef[9]+suff;
				selectROI(n);
				createFrom("Spline", i);
				roiChangeFlag=true;
				//print(n+" changed"); //debug
			}
			//case of not found (inner or outer)
			if (option[i]==ostDef[7] || option[i]==ostDef[8]) {
				option[i]=ostDef[2]; //if "inner" or "outer" sel. Type not found change to "Manual" type
			}
			ost=option[i]+suff;
			//print(ost);
		} //end of while cycle
	} //end of if not Null
	else ost=option[i];
	if (i==6) {
		//if (option[i]==ostDef[0]) ost=option[i]; //leave just Null description in ost;
		selection[0]=selectROI(ost); //write roiManager index to selection array
		Periost=ost;
	}
	if (i==7) {
		//if (option[i]==ostDef[0]) ost=option[i]; //leave just Null description in ost;
		selection[1]=selectROI(ost);
		Endoost=ost;
	}
	return roiChangeFlag;
}//end of chceckROIs

//****************************************prepareROIS********************************************
function prepareROIs() {
	//Double Null error possibility
	nullErrorHandle();
	setRelevantChannel();
	repairPoints();
	roiManager("Deselect");
	roiChangeFlag=false;
	if (checkROIs(6)) roiChangeFlag=true; //check for existing Periost selection Type
	if (checkROIs(7)) roiChangeFlag=true; //check for existing Endoost selection Type

	//imidiately save roiselections
	if (roiChangeFlag==true) { //if something changed, save to .zip
		setOptions(option); //save changed options
		//imidiately save roiselections
		dot=lastIndexOf(name,".");
		if (dot!=-1) name=substring(name, 0, dot); //delete extension if exists
		roiManager("Deselect");
		roiManager("Save", option[5]+name+".zip");
		selectImage(originalID);
		resetMinAndMax();
	}
	resetMinAndMax();

	if (selection[0]==-1 || selection[1]==-1) { //if "Null" is selected then:
		Array.sort(selection);
		selection[0]=selection[1];
	}
	//Array.print(selection); //debug
	roiManager("Select", selection);	
	if (selection[0]!=selection[1]) roiManager("XOR"); // use XOR only if two selections are selected
	//stop("whats selected?"); //debug
}
//***************************************Stop**************************************************
function stop(msg) { //function just for debuging purposes...
	waitForUser("Stop", msg);
}
//*************************************** nullErrorHandle *************************************
function nullErrorHandle() {
	//if One is Null
	while (option[6]==ostDef[0] && option[7]==ostDef[0]) {
		option=getOptions();
  		Dialog.create("Selection types options");
  		Dialog.addMessage("There can be only one Null option\nSelect only one Null option\nor different type of selection types");
  		Dialog.addChoice("Outer selection type:", ostDef, option[6]);
  		Dialog.addChoice("Inner selection type:", ostDef, option[7]);
  		Dialog.show();
		option[6] = Dialog.getChoice(); //read Periost selection Type
  		option[7] = Dialog.getChoice(); //read Endoost selection Type
		setOptions(option);
	}
} //end of nullErrorHandle
//*************************************** createFrom ************************************
function createFrom(tvar, index) { //tvar is "Ellipse" or just "Spline"; index is 6 (Periost) or 7 (Endoost)
	//this algorithm can be changed according to how to make elipses from manual or points...
	if (index==6) suffix="Periost";
	if (index==7) suffix="Endoost";
	if (startsWith(tvar, "Ellipse")) El=true;
	else El=false;
	if (indexOf(option[index], ostDef[9])!=-1  || indexOf(option[index], ostDef[5])!=-1) { //if points or SplinefromAuto is choosed // || indexOf(option[index], ostDef[5])!=-1
		run("Convex Hull");
	}
	if (option[index]==ostDef[9]) tvar=tvar+"From"; //ostDef 9 = "Points"
	else tvar="";
	run("Fit Spline");
	if (El) run("Fit Ellipse");
	//if (indexOf(option[index], "Points")==-1) tvar="";
	roiManager("Add");
	roiManager("Select", roiManager("Count")-1);
	roiManager("Rename", tvar+option[index]+suffix);
} //end of createFrom

//*************************************** DRAWAXES ********************************************
function DrawAxis() {
//optional function to draw major/minor axis of ellipse
  run("Select None");
  moveTo(Centrex,Centrey);
  setColor(255,255,255);
  lineTo(Centrex-(cos((0-Theta)*3.141592654/180)*2*R1),
		 Centrey+(sin((0-Theta)*3.141592654/180)*2*R1));
  moveTo(Centrex,Centrey);
  lineTo(Centrex-(cos((Theta+90)*3.141592654/180)*2*R2),
		 Centrey-(sin((Theta+90)*3.141592654/180)*2*R2));
  moveTo(Centrex,Centrey);
  lineTo(Centrex+(cos((0-Theta)*3.141592654/180)*2*R1),
		 Centrey-(sin((0-Theta)*3.141592654/180)*2*R1));
  moveTo(Centrex,Centrey);
  lineTo(Centrex+(cos((Theta+90)*3.141592654/180)*2*R2),
		 Centrey+(sin((Theta+90)*3.141592654/180)*2*R2));
  }
//**************************** SQR******************
function sqr(n) {
	return n*n;
  }
//*******************************CALCSUMS*******************************************************
function CalcSums() {
	// x-coord of Centoid and y-coord of Centroid held for calculation of max radius
//	SxSnhold = Sx/Sn;
//	SySnhold = Sy/Sn;

	Sn=0; Sx=0; Sy=0; Sxx=0; Syy=0; Sxy=0;

	vyska=ymin+ymax;  //height
	sirka=xmin+xmax;  //width
	maxRad=0;
	for (y=ymin; y<=vyska; y++)  {
		showStatus("Calculation in progress.....");
		showProgress(y/ymax);
	  		for (x=xmin; x<=sirka; x++) {
				if (selectionContains(x, y)==true){
							Sn=Sn+1;
			  				Sx=Sx+(x*cos(rot2)+y*sin(rot2));
			  				Sy=Sy+(y*cos(rot2)-x*sin(rot2));
			  				Sxx=Sxx+sqr((x*cos(rot2)+y*sin(rot2)));
			  				Syy=Syy+sqr((y*cos(rot2)-x*sin(rot2)));
			  				Sxy=Sxy+((y*cos(rot2)-x*sin(rot2))*(x*cos(rot2)+y*sin(rot2)));
			  				//Find pixel furthest away from the center and calculated the distance to that pixel
			  				//XMAXRAD function
							maxRad1 = (x - Centrex)*(x - Centrex);
							maxRad2 = (y - Centrey)*(y - Centrey);
							maxRad3 = (sqrt(maxRad2+maxRad1)) * scalar;
							if(maxRad3>maxRad) maxRad = maxRad3;
					}
			}
		}
  }
//************************************ MEASURE MOMENTS*******************************************

function measureMoments(){ // This macro calculates the anisometry and bulkiness of binary particles
// based on the dynamically equivalent ellipse as defined by Medalia (1970).
	batchState=is("Batch Mode");
	if (!batchState) setBatchMode(true);
	setBatchMode("hide");  //hide image to avoid deletion of selection by accidant during long processing
	getPixelSize(unit, pixelWidth, pixelHeight);
	scalar=pixelWidth;
	units=unit;
	selectImage(originalID);

	getSelectionBounds(xmin,ymin,xmax,ymax);	//  ymin is measured from top,xmin from left
						//  xmax & ymax= diameters along x & y axes

//Calculate Moments
	CalcSums();
		if (Sn==0) {
			showMessage("Selection too narrow. Exit calculation");
			exit;
		}

	Cx=Sx/Sn; //Cx=Sx/Sn-1;		//x-coord. of Centroid
	Cy=Sy/Sn; //Cy=Sy/Sn-1;  	//y-coord. of Centroid
	Centrex=Cx;
	Centrey=Cy;

// following  code calculates y (dist from neutral axis)
	if (((ymax + ymin) - Cy) > (Cy - ymin)) {
		Ymaxrad= ymax + ymin - Cy;
		Yminrad= Cy - ymin;

	}
	else {
		Ymaxrad= Cy - ymin;
		Yminrad= ymax + ymin - Cy;
	}

// following code calculates x (dist from neutral axis)
	if (((xmax + xmin) - Cx) > (Cx - xmin)) {
		Xmaxrad= xmax + xmin - Cx;
		Xminrad= Cx - xmin;
	}
	else {
		Xmaxrad= Cx - xmin;
		Xminrad= xmax + xmin - Cx;
	}
	BigY= Ymaxrad;
	BigX= Xmaxrad;

	Xmaxrad= Xmaxrad*scalar;		//calibrating radii
	Xminrad= Xminrad*scalar;
	Ymaxrad= Ymaxrad*scalar;
	Yminrad= Yminrad*scalar;
 	//Parea=Sn;
	Myy=Sxx-(Sx*Sx/Sn);
	Mxx=Syy-(Sy*Sy/Sn);
	Mxy=Sxy-(Sx*Sy/Sn);
	if (Mxy==0) {
		Theta=0;
	}
	else {
		Theta=atan(((Mxx-Myy)+sqrt(sqr(Mxx-Myy)+(4*sqr(Mxy))))/(2*Mxy))*180/3.141592654;
	}

  	Cx = Cx*scalar;			//save x-coord of centroid
	Cy = Cy*scalar;			//save y-coord of centroid
	BigX= BigX*scalar;			//calibrating x,y,Cx,Cy
	BigY= BigY*scalar;
	Ix= Mxx*(sqr(sqr(scalar))); 		//save mom about x-axis
	Iy= Myy*(sqr(sqr(scalar)));
	Zx= Ix/BigY;			//save section moduli
	Zy= Iy/BigX;

	rot2=Theta*3.141592654/180;
	CalcSums();
	//Parea=Sn;
	M1=Sxx-(Sx*Sx/Sn); //same as Myy
	M2=Syy-(Sy*Sy/Sn);  //same as Mxx
	R1=sqrt(M1/Sn); // M1/Parea
	R2=sqrt(M2/Sn); // M2/Parea
	Imax= M1*(sqr(sqr(scalar)));
	Imin= M2*(sqr(sqr(scalar )));
	Rmaks= R1*scalar;
	Rmyn= R2*scalar;
	rot2=0;
	//Theta= -Theta; //REMOVED due to no apparent function and gives incorrect principal axes (5/24/2005)

	//Calculate the polar moment of inertia
	J = Ix+Iy;
	//Calculate polar modulus
	Zp = J/maxRad;

/* Written by: Matthew Warfel  - Cornell University - 4/4/97
   Modified by: Stanley Serafin- Johns Hopkins University - 6/30/00
   Modified and adapted for ImageJ by:  Valerie Burke DeLeon - 2/21/05
   Modified and adapted fro ImageJ by: Adam David Sylvester - 9/28/2012
   Modified for FIJI by: Ondrej Sebesta - 6/2/2016
   Updates:
   5/24/2005 - v1.2 added "DrawAxis" function modified from MomentMacro (VBD)
   3/17/2006 - v1.2 renamed "neutral axes" to more correct term "principal axes" (VBD)
   7/21/2006 - v1.3 replaced "/*" with "//" character to define initial comment lines, following reports of comments read as code (VBD)
   9/28/2012 - v1.4 added function MAXRAD and calculations of J and Zp (ADS)
   9/1/2013 - v1.4B corrected function MAXRAD and calculations of J and Zp (ADS)
*/

// 6/2/2016 - MAXRAD function added to the calcSums function to optimize speed, OS.

//calculate CA
	getStatistics(CA_gs); //get CA of the current composite (Periost XOR Endoost) selection
	CA_jh = Sn*sqr(scalar); //this gives slightly different values at lower number orders than getStatistics method
	
//calculate TA, MA, and CA
	if (Periost==ostDef[12]) { //if Periost is Threshold
		//TA calculation according to threshold based J.Hopkins macro...
		newImage("TA calculation", "8-bit black", getWidth(), getHeight(), 1);
		
		selectROI(ostDef[12]);
		setForegroundColor(255, 255, 255);
		run("Fill", "slice");
		run("Select None");
		run("Options...", "iterations=1 count=1 black do=Nothing");
		run("Fill Holes");
		setThreshold(128, 255);
		run("Create Selection");
		getStatistics(TA);
		TA=TA*sqr(scalar);
		selectWindow("TA calculation"); close(); //close temp. mask window.
		CA = CA_jh;
		MA=TA-CA;
		CA_err_est=NaN;
	}
	else if (Periost==ostDef[0]) {  //if Periost is null
		selectROI(Endoost); //only MA is measured
		getStatistics(MA);
		CA=NaN;
		TA=NaN;
		CA_err_est=NaN;
	}
	else if (Periost!=ostDef[12] && Endoost==ostDef[0]) { //if Endoost is null, but Periost is not Threshold
		selectROI(Periost); //only TA is measured
		getStatistics(TA);
		CA=NaN;
		MA=NaN;
		CA_err_est=NaN;
	} 
	else { //all other cases will be measured like this>
		selectROI(Periost);
		getStatistics(TA); //get TA of the Perioost	
		selectROI(Endoost);
		getStatistics(MA);
		CA=TA-MA; //
		CA_err_est=100-((minOf(CA, CA_gs)/maxOf(CA, CA_gs))*100);
		}
//end of calculate TA, MA, and CA

	//roiManager("Deselect");
	if (!batchState) setBatchMode("show"); //show image again if not in batch mode.
	setBatchMode(batchState);
} //  End of main macro "Calculating Moments"

//********************************************save results*******************************************************
function saveResults(){
	setForegroundColor(255, 255, 255);
	setBackgroundColor(0,0,0);
	Stack.getDimensions(width, height, channels, slices, frames);

//Draw selection
	selectImage(originalID);
//	Stack.setDisplayMode("color");
	Stack.setChannel(channels-1);
	clearChannel();
	prepareROIs();
	//stop();
	//roiManager("Select", selection);
	Stack.setChannel(channels-1);
	run("Draw", "slice");
	resetMinAndMax();

//Draw principal axes
	Stack.setChannel(channels);
	clearChannel();
	DrawAxis();
	resetMinAndMax();
	setRelevantChannel();

//displays the results in the upper left corner of the text window
//not implemented

	path=option[5];
	dot=lastIndexOf(name,".");
	if (dot!=-1) name=substring(name, 0, dot); //delete extension if exists

	writeResults(); //writes measurements into result window instead to Log Window
	//print(name+tab+scalar+units+"/pixel"+tab+TA+tab+CA+tab+Cx+tab+Cy+tab+Ix+tab+Iy+tab+Imax+tab+Imin+tab+Theta+tab+Zx+tab+Zy+tab+Xmaxrad+tab+Ymaxrad);
	saveResultsTable(); // save results as Results.txt into destination directory
	selectImage(originalID);
	if (!is("Batch Mode")) {
		Stack.setDisplayMode("composite");
		activeChannels=activateChannels(channels);
		Stack.setActiveChannels(activeChannels);
	}
	//run("Stack to RGB");
	//print(name);
	saveAs("Tiff", path+name+".tif"); //+".tif"
	//close();

	roiManager("Deselect");
	roiManager("Save", path+name+".zip");
	//print("saving .zip at the end"); //debug
	selectImage(originalID);
	//rename(name+".tif");

} //  End of "saveResults"
//********************** activate channels ********************
function activateChannels(channels) {
	array=newArray(channels);
	Array.fill(array, 1);
	if (!option[2]) array[channels-2]=0;
	if (!option[3]) array[channels-1]=0;
	string="";
	for (i=0; i<array.length; i++) {
		string=string+d2s(array[i],0);
	}
	return string;
}
//************************* saveResultsTabel ******************
function saveResultsTable() {
	if (!option[8]) resName=path+"Results_"+Periost+"_"+Endoost;
	else resName=path+"Results";
	path=option[5];
	if (isOpen("Log")) {
		selectWindow("Log");
		saveAs("Text", resName+"_"+option[9]+"_Fails.txt");
	}
	selectWindow("Results");
 	saveAs("Results", resName+".txt"); // File>Save As>Text
} //end of saveResultsTable

//************************* openResultsTable *******************
function openResultsTable() {
	path=option[5];
	//set Result file name
	if (!option[8]) file=path+"Results_"+Periost+"_"+Endoost+".txt";
	else file=path+"Results.txt";
	//file=path+"Results_"+Periost+"_"+Endoost+".txt";
	if (File.exists(file)) {
		run("Clear Results");
		run("Results... ", "open=["+file+"]");
	}
	else if (!option[8]) run("Clear Results");
} //end of openResultsTable

//************************clearChannel*********************
function clearChannel(){
	run("Select All");
	run("Clear", "slice");
	run("Restore Selection");
}

//**************************addROI************************************
function addROI(index, capture, message, newName) {
	if (is("Batch Mode")) setBatchMode("show");
	ZOOM(); //Auto zoom in
	Stack.setDisplayMode("composite");
	getDimensions(width, height, channels, slices, frames);
	activeChannels=activateChannels(channels);
	Stack.setActiveChannels(activeChannels);
	if (index==-1) run("Select None");
   	do {
   		waitForUser(capture, message);
	  } while (selectionType==-1);
	roiManager("Add");
	roiManager("Select", roiManager("Count")-1);
	roiManager("Rename", newName);
	return roiManager("index");
} //end of addROI

//**************************selectROIname*****************************
function selectROI(Rname) {
//this function returns index of ROI name in roiManager. Returns -1 if not find and deselect previously selected roi
	i=0; //roiindex counter
	iMax=roiManager("Count")-1; //max rois
	if (iMax!=-1) {
	do { //find roi with variable Rname
		//i++;
		roiManager("Select", i);
		currentROIname=call("ij.plugin.frame.RoiManager.getName", i);
	} while (Rname!=currentROIname && i++!=iMax);
	//control of accuracy
	if (Rname==currentROIname) {
		return roiManager("index");
	}
	else {
		roiManager("Deselect");
		return -1;
	}
} //end if
else return -1;
}//end of function selectROI(Rname);

//************************write Results****************************
function writeResults() {
	newRow=nResults;
	if (option[11]) AutoThr="Manual";
	else AutoThr=option[9];
	setResult("Periost", newRow, Periost);
	setResult("Endoost", newRow, Endoost);
	setResult("original", newRow, original);
	setResult("AutoThr", newRow, AutoThr);
	setResult("scalar", newRow, scalar);
	setResult(units+"/pixel", newRow, units+"/pixel");
	setResult("TA", newRow, TA);
	setResult("CA", newRow, CA);
//	setResult("CA_jh", newRow, CA_jh);
//	setResult("CA_gs", newRow, CA_gs);
	setResult("MA", newRow, MA);
	setResult("%CA", newRow, (CA/TA)*100);
	setResult("%CA_err_est", newRow, CA_err_est);
	setResult("Cx", newRow, Cx);
	setResult("Cy", newRow, Cy);
	setResult("Ix", newRow, Ix);
	setResult("Iy", newRow, Iy);
	setResult("Imax", newRow, Imax);
	setResult("Imin", newRow, Imin);
	setResult("Theta", newRow, Theta);
	setResult("Zx", newRow, Zx);
	setResult("Zy", newRow, Zy);
	setResult("Xmaxrad", newRow, Xmaxrad);
	setResult("Ymaxrad", newRow, Ymaxrad);
	setResult("xmin", newRow, xmin);
	setResult("ymin", newRow, ymin);
	setResult("xmax", newRow, xmax*scalar);
	setResult("ymax", newRow, ymax*scalar);
	setResult("J", newRow, J); //polar moment of inertia
	setResult("Zp", newRow, Zp); //polar modulus
	setResult("maxRad", newRow, maxRad);
	updateResults();
} //end of write results
//**************************getPoints*********************************
function getPoints(type) {
	xpoints=newArray();
	if (is("Batch Mode")) setBatchMode("show");
	ZOOM(); //set auto ZOOM in
	run("Select None");
	Stack.setDisplayMode("composite");
	getDimensions(width, height, channels, slices, frames);
	activeChannels=activateChannels(channels);
	Stack.setActiveChannels(activeChannels);

	do {
		if (selectionType!=10) setTool("multipoint");
		waitForUser("Points Selection Adjustment","Now pick up manually at least 3 "+type+" selection points.\n "+type+" point");
		if (selectionType!=-1) {
			getSelectionCoordinates(xpoints, ypoints);
			//roundArray(xpoints);
			//roundArray(ypoints);	  		
		}
	} while (xpoints.length<3 || selectionType!=10);
	makeSelection("Points", xpoints, ypoints); //rounding coordinates and redraw override problems with .zip opening exceptions and saving 0b Threshold composite selection
}
//************************ roundArray *******************************
function roundArray(array){
	for (a=0; a<array.length; a++) {
		array[a]=round(array[a]);
	}
	return array;
}
//************************ ZOOM *************************************
function ZOOM() {
		//auto zoom function
	if (option[10]) {
		indx=roiManager("Index");
		selectROI("Autoperiost");
		run("To Selection");
		if (indx!=-1) roiManager("select", indx);
		else run("Restore Selection");
	}
	return getZoom();
}
//************************ delAllRoisContaining(vyraz) ****************
function delAllRoisContaining(vyraz) {
	r=roiManager("Count")-1;
	s=newArray();
	while (r>-1) {
		roiManager("Select", r);
		roiName=Roi.getName;
		if (indexOf(roiName, vyraz)!=-1) {
			//print(roiName+" deleted "+r); //debug
			s=Array.concat(s,r);
			}
		r--;
	}
	if (s.length>0) {
		roiManager("Select", s);
		roiManager("Delete");
	}
}
//*********************** repairPoints ********************************
function repairPoints() {	
	//repair PointsPeriost and PointsEndoost from previous versions.
	n=ostDef[9]+"Periost";
	if (selectROI(ostDef[12])==-1 && selectROI(n)!=-1) {
		getSelectionCoordinates(Xcor, Ycor);
		roiManager("Delete");
		makeSelection("Points", Xcor,Ycor);
		roiManager("Add");
		roiManager("Select", roiManager("Count")-1);
		roiManager("Rename", n);
	}
	n=ostDef[9]+"Endoost";
	if (selectROI(ostDef[12])==-1 && selectROI(n)!=-1) {
		getSelectionCoordinates(Xcor, Ycor);
		roiManager("Delete");
		makeSelection("Points", Xcor,Ycor);
		roiManager("Add");
		roiManager("Select", roiManager("Count")-1);
		roiManager("Rename", n);
	}
}