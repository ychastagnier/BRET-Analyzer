// Luminescence Ratio Analyzer version 0.30 (2017-09-08)
// by Yan Chastagnier

// Put this macro into the folder Fiji.app/macros/toolsets/
// Select it with the >> symbol at the extrem right of the toolbar.
// Use the Action Tools to run the different parts of the process.

// Global parameters
var donorName = call("ij.Prefs.get", "LRA.donorName", "LUC"); // Donor
var acceptorName = call("ij.Prefs.get", "LRA.acceptorName", "YFP"); // Acceptor
var batchClean = call("ij.Prefs.get", "LRA.batchClean", false); // Batch clean?
var subtractBackgroundImage = call("ij.Prefs.get", "LRA.subtractBackgroundImage", false); // Subtract dark image taken without luminescence (offset + read noise + light pollution)?
var alignStacks = call("ij.Prefs.get", "LRA.alignStacks", true); // Align stacks?
var batchCrop = call("ij.Prefs.get", "LRA.batchCrop", false); // Batch crop?
var nameCROPs = call("ij.Prefs.get", "LRA.nameCROPs", true); // Give a label to CROPs?
var divideSelection = call("ij.Prefs.get", "LRA.divideSelection", "Image: Multi if CROP");
var batchDivide = call("ij.Prefs.get", "LRA.batchDivide", false); // Divide without confirmation
var thresholdMethod = call("ij.Prefs.get", "LRA.thresholdMethod", "AutoTh - Chastagnier");
var coefMultMeanROI = parseFloat(call("ij.Prefs.get", "LRA.coefMultMeanROI", 1)); // Coefficient
var radiusLocalTh = parseFloat(call("ij.Prefs.get", "LRA.radiusLocalTh", 10)); // AutoLocalTh radius
var overallMinThreshold = parseFloat(call("ij.Prefs.get", "LRA.overallMinThreshold", 0)); // Minimum threshold
var rangeMin = parseFloat(call("ij.Prefs.get", "LRA.rangeMin", 0.2)); // Min range
var rangeMax = parseFloat(call("ij.Prefs.get", "LRA.rangeMax", 2)); // Max range
var time_between_images_sec = parseFloat(call("ij.Prefs.get", "LRA.time_between_images_sec", 30)); // Time between images (s)
var normalizeSlice = parseFloat(call("ij.Prefs.get", "LRA.normalizeSlice", 5)); // Slice used to normalize
var weightImage = call("ij.Prefs.get", "LRA.weightImage", false); // Display wieghted images?
var plot3D = call("ij.Prefs.get", "LRA.plot3D", "No"); // Plot Ratio vs intensity?
var dataFolderName = call("ij.Prefs.get", "LRA.dataFolderName", "data"); // Folder and data name

// Tools definition
macro "Clean donor and acceptor images Action Tool - B03 C059 T060dC Ta60dl Td60de T3f0da Taf0dn" {cleanImages();}
macro "Crop clean donor and acceptor images Action Tool - B03 C059 T060dC Ta60dr T3f0do Tbf0dp" {cropImages();}
macro "Divide clean images to get Ratio image Action Tool - B03 C059 T050dD Ta50di Td50dv T2f0di T5f0dd Tcf0de" {makeRatioImage();}
macro "Ratio analysis Action Tool - B03 C059 T050dA T850dn Tf50da T0f0dl T3f0dy Taf0ds Tff0de" {makeRatioAnalysis();}
macro "Get and set image location and size Action Tool - B03 C059" {setLoc();}
macro "Close everything Action Tool - B03 C059 T060dC Ta60dl Td60do T3f0ds Taf0de" {closeImages();}
macro "Set default parameters Action Tool - B03 C059 T050dP T750da Te50dr T1f0da T8f0dm" {setParameters();}
macro "Batch set min and max of Ratio images in a folder and its subfolders Action Tool - B03 C059 T050dM Tb50di Te50dn T0f0bM Taf0aa Tff0ax" {batchMinAndMax("Ratio", 2);}

var nbROIsArray = newArray("0");
var nbSlicesArray = newArray();
var nbSlicesTotArray = newArray("0");
var nbValuesTotArray = newArray("0");
var path = "";
var lateMacOSX = isLateMacOSX();
function isLateMacOSX() {
	res = false;
	if (matches(getInfo("os.name"), "Mac OS X")) {
		version = getInfo("os.version");
		components = split(version, ".,");
		if (lengthOf(components)>1) {
			if (parseInt(components[1]) >= 11) {
				res = true;
			}
		}
	}
	return res;
}

// **************************************************
// Clean donor and acceptor images
// **************************************************
function cleanImages() {
	if (batchClean) {
		nbPass = 0;
		imageList = newArray();
		path = "";
		while (nbPass < 2 && lengthOf(imageList) == 0) { // look first in the folder itself if there are images, if not, look into subfolders.
			nbPass++;
			imageList2 = getFiles(donorName, nbPass, path);
			for (i = 0; i < imageList2.length; i++) {
				donor = imageList2[i];
				index = lastIndexOf(donor, donorName);
				if (index != -1) {
					acceptor = substring(donor, 0, index)+acceptorName+substring(donor, index+lengthOf(donorName), lengthOf(donor));
				} else {
					acceptor = "";
				}
				if (File.exists(donor) && File.exists(acceptor)) {
					imageList = Array.concat(imageList, imageList2[i]);
				}
			}
		}
	} else {
		// Dialogue window to choose image
		imageList = newArray(1);
		tempPath = chooseFile("Select raw "+donorName+" image");
		imageList[0] = tempPath;
	}
	for (j = 0; j < imageList.length; j++) {
		if (batchClean) {
			setBatchMode(true);
			print("Cleaning image "+(j+1)+" / "+imageList.length);
		}
		donor = imageList[j];
		// Create sub folder if needed
		index = lastIndexOf(donor, donorName);
		extensionSize = getExtensionSize(donor);
		if (index == -1) {
			if (extensionSize == 0) {
				folderPath = donor+"_";
			} else {
				folderPath = substring(donor, 0, lengthOf(donor)-extensionSize);
			}
		} else {
			folderPath = substring(donor, 0, index)+substring(donor, index+lengthOf(donorName), lengthOf(donor)-extensionSize);
			if (lengthOf(folderPath) == 1+lengthOf(File.getParent(donor))) {
				folderPath += "clean";
			}
		}
		if (!File.exists(folderPath)) {
			File.makeDirectory(folderPath);
		}
		
		// Open and place images
		open(donor);
		run("Enhance Contrast", "saturated=0.35");
		setLocation(0.05*screenWidth, 0.1*screenHeight);
		rename(donorName);
		
		if (index != -1) {
			acceptor = substring(donor, 0, index)+acceptorName+substring(donor, index+lengthOf(donorName), lengthOf(donor));
		} else {
			acceptor = "";
		}
		if (index == -1 || !File.exists(acceptor)) {
			// If acceptor image is not automatically found, ask user to choose it
			acceptor = chooseFile("Select raw "+acceptorName+" image");
		}
		open(acceptor);
		run("Enhance Contrast", "saturated=0.35");
		setLocation(0.5*screenWidth, 0.1*screenHeight);
		rename(acceptorName);
		
		if (subtractBackgroundImage && j==0) {
			bgImageSmoothRadius = 10;
			donorBG = chooseFile("Select background image for "+donorName);
			acceptorBG = chooseFile("Select background image for "+acceptorName);
			open(donorBG);
			setLocation(0.03*screenWidth, 0.06*screenHeight);
			if (nSlices > 1) {
				stackDonorBGID = getImageID();
				run("Z Project...", "projection=Median");
				rename(donorName+"BackGround");
				donorBGID = getImageID();
				selectImage(stackDonorBGID);
				close();
			} else {
				rename(donorName+"BackGround");
				donorBGID = getImageID();
			}
			run("Median...", "radius="+bgImageSmoothRadius);
			open(acceptorBG);
			setLocation(0.48*screenWidth, 0.06*screenHeight);
			rename(acceptorName+"BackGround");
			if (nSlices > 1) {
				stackAcceptorBGID = getImageID();
				run("Z Project...", "projection=Median");
				rename(acceptorName+"BackGround");
				acceptorBGID = getImageID();
				selectImage(stackAcceptorBGID);
				close();
			} else {
				rename(acceptorName+"BackGround");
				acceptorBGID = getImageID();
			}
			run("Median...", "radius="+bgImageSmoothRadius);
			selectWindow(acceptorName);
		}

		selectWindow(donorName);
		coords = getBgArea();
		makeRectangle(coords[0], coords[1], coords[2], coords[3]);

		if (!batchClean) {
			// User prompt to select background zone
			title = "Background area selection";
			msg = "Please select background area, then click \"OK\".";
			waitForUser(title, msg);
			run("Select None");
		} else {
			run("Select None");
		}
		
		if (!batchClean && nSlices != 1) {
			// Ask the user if he wants to align images
			Dialog.create("Align");
			Dialog.addCheckbox("Align images?", alignStacks);
			Dialog.addHelp("http://htmlpreview.github.com/?https://github.com/ychastagnier/LR-Analyzer/blob/master/help/align.html");
			Dialog.show();
			alignStacks = Dialog.getCheckbox();
			call("ij.Prefs.set", "LRA.alignStacks", alignStacks);
		}
		
		setBatchMode(true);
		
		// Get median value from area selected on background images (not to subtract them twice)
		if (subtractBackgroundImage && j==0) {
			selectImage(donorBGID);
			run("Restore Selection");
			run("Measure");
			medAreaImageBGDonor = getResult("Median");
			selectImage(acceptorBGID);
			run("Restore Selection");
			run("Measure");
			medAreaImageBGAcceptor = getResult("Median");
		}
				
		// Clean donor
		run("Set Measurements...", "mean standard min median redirect=None decimal=3");
		selectWindow(donorName);
		setBatchMode("hide");
		run("Median...", "radius=1 stack"); // Median Filter
		for (n=1; n<=nSlices; n++) {
			setSlice(n);
			run("Restore Selection");
			run("Measure");
			backgroundDonor = getResult("Median");
			if (subtractBackgroundImage) {
				backgroundDonor -= medAreaImageBGDonor;
			}
			run("Select None");
			run("Subtract...", "value=" + backgroundDonor + " slice"); // Remove background
		}
		
		// Clean acceptor
		selectWindow(acceptorName);
		setBatchMode("hide");
		run("Median...", "radius=1 stack"); // Median Filter
		for (n=1; n<=nSlices; n++) {
			setSlice(n);
			run("Restore Selection");
			run("Measure");
			backgroundAcceptor = getResult("Median");
			if (subtractBackgroundImage) {
				backgroundAcceptor -= medAreaImageBGAcceptor;
			}
			run("Select None");
			run("Subtract...", "value=" + backgroundAcceptor + " slice"); // Remove background
		}
		
		// Subtract background images
		if (subtractBackgroundImage) {
			imageCalculator("Subtract stack", donorName, donorName+"BackGround");
			imageCalculator("Subtract stack", acceptorName, acceptorName+"BackGround");
		}
		
		// Align slices using TurboReg plugin to compute translation coordinates
		if (alignStacks && nSlices != 1) {
			List.setCommands;
			if (List.get("TurboReg ")!="") {
				selectWindow(donorName);
				nbSlices=nSlices;
				refSlice = floor(nbSlices/2); // Start alignment from the middle of the stack
				setSlice(refSlice);
				run("Duplicate...", "title=Source");
				width = getWidth();
				height = getHeight();
				xcoord = newArray(nbSlices);
				ycoord = newArray(nbSlices);
				xcoord[refSlice]=0;
				ycoord[refSlice]=0;
				// Compute translations coordinates for first half of the stack
				for (i = refSlice-1; i>0; i--) {
					selectWindow(donorName);
					setSlice(i);
					showStatus("Computing Translation Correction "+(refSlice-i)+"/"+nbSlices);
					run("Duplicate...", "title=Target");
					run("TurboReg ","-align -window Source 0 0 "+(width-1)+" "+(height-1)+" -window Target 0 0 "+(width-1)+" "+(height-1)+
						" -translation "+(width/2)+" "+(height/2)+" "+(width/2)+" "+(height/2)+" -hideOutput");
					selectWindow("Source");
					close();
					selectWindow("Target");
					rename("Source");
					xcoord[i-1] = xcoord[i] + getResult("sourceX", 0)-getResult("targetX", 0);
					ycoord[i-1] = ycoord[i] + getResult("sourceY", 0)-getResult("targetY", 0);
				}
				selectWindow("Source");
				close();
				selectWindow(donorName);
				setSlice(refSlice);
				run("Duplicate...", "title=Source");
				// Compute translations coordinates for second half of the stack
				for (i = refSlice+1; i<=nbSlices; i++) {
					selectWindow(donorName);
					setSlice(i);
					showStatus("Computing Translation Correction "+i+"/"+nbSlices);
					run("Duplicate...", "title=Target");
					run("TurboReg ","-align -window Source 0 0 "+(width-1)+" "+(height-1)+" -window Target 0 0 "+(width-1)+" "+(height-1)+
						" -translation "+(width/2)+" "+(height/2)+" "+(width/2)+" "+(height/2)+" -hideOutput");
					selectWindow("Source");
					close();
					selectWindow("Target");
					rename("Source");
					xcoord[i-1] = xcoord[i-2] + getResult("sourceX", 0)-getResult("targetX", 0);
					ycoord[i-1] = ycoord[i-2] + getResult("sourceY", 0)-getResult("targetY", 0);
				}
				selectWindow("Source");
				close();
				
				if (isOpen("Refined Landmarks")) {
					selectWindow("Refined Landmarks");
					run("Close");
				}
				
				// Apply translations to both stacks
				selectWindow(donorName);
				for (i = 0; i<nbSlices; i++) {
					setSlice(i+1);
					run("Translate...", "x=" + round(xcoord[i]) + " y=" + round(ycoord[i]) + " interpolation=None slice");
				}
				selectWindow(acceptorName);
				for (i = 0; i<nbSlices; i++) {
					setSlice(i+1);
					run("Translate...", "x=" + round(xcoord[i]) + " y=" + round(ycoord[i]) + " interpolation=None slice");
				}
			} else {
				Dialog.create("Plugin TurboReg not found");
				Dialog.addMessage("The plugin to align images across a stack has not been found.");
				Dialog.addMessage("Click OK to continue the process without aligning.");
				Dialog.addMessage("Click Cancel to abord the process.");
				Dialog.addMessage("Click Help to open the website where you can find the plugin.\nDownload the file according to your operating system "
							+"(UNIX, Mac OS or Windows).\nFind the file TurboReg_.jar and place it in the folder Fiji.app/plugins/\nRestart Fiji to use it.");
				Dialog.addHelp("http://bigwww.epfl.ch/thevenaz/turboreg/");
				Dialog.show();
			}
		}
		if (!batchClean) {
			setBatchMode("exit and display");
		}
		if (isOpen("Results")) {
			selectWindow("Results");
			run("Close");
		}
		
		// Save "clean" images in subfolder
		selectWindow(acceptorName);
		setLocation(0.5*screenWidth, 0.1*screenHeight);
		setSlice(1);
		run("Enhance Contrast", "saturated=0.35");
		extensionSizeAcceptor = getExtensionSize(acceptor);
		saveAs("tiff", folderPath + File.separator + substring(File.getName(acceptor), 0, lengthOf(File.getName(acceptor))-extensionSizeAcceptor)+"_clean");
		if (batchClean) {
			close();
		} else {
			rename(acceptorName+"_clean");
		}
		selectWindow(donorName);
		setLocation(0.05*screenWidth, 0.1*screenHeight);
		setSlice(1);
		run("Enhance Contrast", "saturated=0.35");
		saveAs("tiff", folderPath + File.separator + substring(File.getName(donor), 0, lengthOf(File.getName(donor))-extensionSize)+"_clean");
		if (batchClean) {
			close();
		} else {
			rename(donorName+"_clean");
		}
	}
	if (isOpen(donorName+"BackGround")) {
		selectWindow(donorName+"BackGround");
		close();
	}
	if (isOpen(acceptorName+"BackGround")) {
		selectWindow(acceptorName+"BackGround");
		close();
	}
	if (batchClean) {
		if (lengthOf(imageList) == 0) {
			print("No pairs of images were found with donorName", donorName, "and acceptorName", acceptorName, "in the selected folder.");
		}
		print("Clean operation finished");
	}
	beep();
	showStatus("Clean Operation finished.");
}

// **************************************************
// Crop Clean Images
// **************************************************
function cropImages() {
	
	alreadyOpen = false;
	imageList = newArray();
	
	// If images are not already open, dialogue window to choose them
	if (isOpen(donorName+"_clean")) {
		selectWindow(donorName+"_clean");
		donor = getInfo("image.directory")+getInfo("image.filename");
		alreadyOpen = true;
		imageList = Array.concat(imageList, donor);
	} else {
		if (isOpen(acceptorName+"_clean")) { // If acceptor is open alone, close it
			selectWindow(acceptorName+"_clean");
			close();
		}
		if (!batchCrop) {
			donor = chooseFile("Select "+donorName+" image");
			imageList = Array.concat(imageList, donor);
		} else {
			imageList2 = getFiles("_clean.tif", 3, "");
			imageList = newArray(imageList2.length);
			nbImages = 0;
			for (i = 0; i < imageList2.length; i++) {
				index = indexOf(imageList2[i], "CROP");
				if (index == -1) {
					imageList[nbImages] = imageList2[i];
					nbImages++;
				}
			}
			imageList2 = Array.slice(imageList, 0, nbImages);
			nbImages = 0;
			for (i = 0; i < imageList2.length; i++) {
				index = indexOf(imageList2[i], donorName);
				if (index != -1) {
					temp = substring(imageList2[i], 0, index)+acceptorName+substring(imageList2[i], index+lengthOf(donorName), lengthOf(imageList2[i]));
					if (File.exists(temp)) {
						imageList[nbImages] = imageList2[i];
						nbImages++;
						imageList[nbImages] = temp;
						nbImages++;
					}
				}
			}
			imageList = Array.slice(imageList, 0, nbImages);
		}
		//open(donor);
		//rename(donorName+"_clean");
		//setLocation(0.05*screenWidth, 0.1*screenHeight);
		//run("Enhance Contrast", "saturated=0.35");
	}
	if (imageList.length == 1) {
		if (isOpen(acceptorName+"_clean")) {
			selectWindow(acceptorName+"_clean");
			acceptor = getInfo("image.directory")+getInfo("image.filename");
		} else {
			index = lastIndexOf(donor, donorName);
			if (index != -1) {
				acceptor = substring(donor, 0, index)+acceptorName+substring(donor, index+lengthOf(donorName), lengthOf(donor));
			} else {
				acceptor = "";
			}
			if(!File.exists(acceptor)) {
				acceptor = chooseFile("Select clean acceptor image");
			}
			if (alreadyOpen) {
				open(acceptor);
				rename(acceptorName+"_clean");
				setLocation(0.5*screenWidth, 0.1*screenHeight);
				run("Enhance Contrast", "saturated=0.35");
			}
		}
		imageList = Array.concat(imageList, acceptor);
	}
	
	for (nbImages = 0; nbImages < imageList.length/2; nbImages++) {
		if (!alreadyOpen) {
			donor = imageList[2*nbImages];
			index = lastIndexOf(donor, donorName);
			open(donor);
			rename(donorName+"_clean");
			setLocation(0.05*screenWidth, 0.1*screenHeight);
			run("Enhance Contrast", "saturated=0.35");
			acceptor = imageList[2*nbImages+1];
			open(acceptor);
			rename(acceptorName+"_clean");
			setLocation(0.5*screenWidth, 0.1*screenHeight);
			run("Enhance Contrast", "saturated=0.35");
		} else {
			selectWindow(donorName+"_clean");
		}
		
		folderPath = getInfo("image.directory");
		if (nameCROPs) {
			// Prepare a text file for crop numbers and description entered by the user
			// It will print lines into the log window, then save it
			cropFile = folderPath + "CROPs.txt";
			if (isOpen("Log")) {
				selectWindow("Log");
				run("Close");
			}
			cropFileExisted = File.exists(cropFile);
			if (cropFileExisted) {
				// If file already exists, store it to keep existing data
				existingData = File.openAsString(cropFile);
			}
			cropFileVar = File.open(cropFile);
			if (cropFileExisted) {
				print(cropFileVar, existingData);
			}
		}
		
		cropFileName = folderPath+"cropAREAs.zip"; // Path to the file that will contain CROP's ROIs
		roiManager("Reset");
		if (File.exists(cropFileName)) {
			// Recover existing CROP's regions into the ROI Manager
			roiManager("Open", cropFileName);
		}
		nbExistingROIs = roiManager("count");
		roiManagerNames = newArray(nbExistingROIs);
		for (i = 0; i < nbExistingROIs; i++) {
			// Recover existing CROP's regions' names
			roiManager("select", i);
			roiManagerNames[i] = call("ij.plugin.frame.RoiManager.getName", i);
		}
		selectWindow(donorName+"_clean");
		index = lastIndexOf(donor, donorName);
		if (index != -1) {
			cropNameStart = substring(donor, 0, index)+"CROP";
			cropNameEnd = substring(donor, index+lengthOf(donorName),lengthOf(donor)-4);
		} else {
			cropNameStart = substring(donor, 0, lengthOf(donor)-(lengthOf(donorName)+10))+"CROP";
			cropNameEnd = "_clean";
		}
		cropNames = newArray();
		i=1;
		seltype = 0;
		while (seltype != -1) { // While user has selected a region
			while (File.exists(cropNameStart+i+"_"+donorName+cropNameEnd+".tif")) {
				i++;
			}
			// User prompt to select crop
			title = "Crop area selection";
			msg = "Please select a rectangular area to crop, then click \"OK\".\nSelect nothing to stop making crops.";
			waitForUser(title, msg);
			seltype = selectionType();
			run("Select None");
			if (seltype != -1) {
				selectWindow(donorName+"_clean");
				tempInd = -1;
				for (j = 0; j < nbExistingROIs; j++) {
					if (matches(roiManagerNames[j], "CROP"+i)) {
						tempInd = j;
					}
				}
				if (tempInd == -1) {
					run("Restore Selection");
					roiManager("Add");
					roiManager("select", roiManager("count")-1);
					roiManager("Rename", "CROP"+i);
				} else {
					roiManager("select", tempInd);
					run("Restore Selection");
					roiManager("Update");
				}
				selectWindow(donorName+"_clean");
				run("Restore Selection");
				run("Duplicate...", "title=["+donorName+"_CROP"+i+"] duplicate");
				saveAs("tiff", cropNameStart+i+"_"+donorName+cropNameEnd);
				close();
				selectWindow(acceptorName+"_clean");
				run("Restore Selection");
				run("Duplicate...", "title=["+acceptorName+"_CROP"+i+"] duplicate");
				saveAs("tiff", cropNameStart+i+"_"+acceptorName+cropNameEnd);
				close();
				if (nameCROPs) {
					Dialog.create("CROP label");
					Dialog.addString("CROP label", "");
					Dialog.show();
					temp =Dialog.getString();
					print(""+i+" : "+temp);
					print(cropFileVar, ""+i+" : "+temp);
				}
				selectWindow(acceptorName+"_clean");
				run("Select None");
				selectWindow(donorName+"_clean");
				run("Select None");
			}
		}
		
		if (nameCROPs) {
			File.close(cropFileVar);
			if (isOpen("Log")) {
				selectWindow("Log");
				run("Close");
			}
		}
	
		if (isOpen("ROI Manager")) {
			selectWindow("ROI Manager");
			if (roiManager("count") > 0) {
				roiManager("Save", cropFileName);
			}
			run("Close");
		}
		
		selectWindow(donorName+"_clean");
		close();
		selectWindow(acceptorName+"_clean");
		close();
	}
	if (lengthOf(imageList) == 0) {
		print("No pairs of images were found with donorName", donorName, "and acceptorName", acceptorName, "in the selected folder.");
	}
	showStatus("Crop Operation finished.");
}


// **************************************************
// Divide Clean Images to get Ratio Images
// **************************************************
function makeRatioImage() {
	
	updateMinMax = true;
	alreadyOpen = false;
	imageList = newArray();
	if (batchDivide) {
		if (startsWith(thresholdMethod, "Auto")) {
			setBatchMode(true);
		} else {
			batchDivide = false; // If threshold method is manual, exit batch mode
		}
	}
	
	crops = 0;
	if (isOpen(donorName+"_clean")) { // Case donor is already open
		selectWindow(donorName+"_clean");
		donor = getInfo("image.directory")+getInfo("image.filename");
		alreadyOpen = true;
		imageList = Array.concat(imageList, donor);
	} else {
		if (isOpen(acceptorName+"_clean")) { // If acceptor is open alone, close it
			selectWindow(acceptorName+"_clean");
			close();
		}
		if (matches(divideSelection, "Image: Single")) { // Case select and process single image
			donor = chooseFile("Select clean "+donorName+" image");
			imageList = Array.concat(imageList, donor);
		} else if (matches(divideSelection, "Image: Multi if CROP")) { // Case select image, process all CROPs if one is selected, else single image
			donor = chooseFile("Select clean "+donorName+" image");
			indexCROP = lastIndexOf(donor, "CROP");
			index = lastIndexOf(donor, donorName);
			if (indexCROP != -1) {
				cropStartPath = substring(donor, 0, indexCROP+4);
				cropEndPath = substring(donor, index+lengthOf(donorName), lengthOf(donor));
				donorCrop = cropStartPath+(crops+1)+"_"+donorName+cropEndPath;
				acceptorCrop = cropStartPath+(crops+1)+"_"+acceptorName+cropEndPath;
				while (File.exists(donorCrop) && File.exists(acceptorCrop)){
					crops++; // Count crops corresponding to opened images.
					imageList = Array.concat(imageList, newArray(donorCrop, acceptorCrop));
					donorCrop = cropStartPath+(crops+1)+"_"+donorName+cropEndPath;
					acceptorCrop = cropStartPath+(crops+1)+"_"+acceptorName+cropEndPath;
				}
			} else {
				imageList = Array.concat(imageList, donor);
			}
		} else {
			imageList2 = getFiles("_clean.tif", 3, "");
			nbCROPs = 0;
			for (i = 0; i < imageList2.length - nbCROPs; i++) { // Sort list to have all crops at the end
				index = indexOf(imageList2[i], "CROP");
				if (index != -1) {
					nbCROPs++;
					temp = imageList2[i];
					imageList2[i] = imageList2[imageList2.length-nbCROPs];
					imageList2[imageList2.length-nbCROPs] = temp;
					i--;
				}
			}
			if (matches(divideSelection, "Folder: CROPs only")) {
				imageList2 = Array.slice(imageList2, imageList2.length-nbCROPs, imageList2.length); 
			} else if (matches(divideSelection, "Folder: All but CROPs")) {
				imageList2 = Array.slice(imageList2, 0, imageList2.length-nbCROPs);
			} // else "Folder: All": keep whole imageList2
			for (i = 0; i < imageList2.length; i++) {
				index = lastIndexOf(imageList2[i], donorName);
				if (index != -1) {
					temp = substring(imageList2[i], 0, index)+acceptorName+substring(imageList2[i], index+lengthOf(donorName), lengthOf(imageList2[i]));
					if (File.exists(temp)) {
						imageList = Array.concat(imageList, newArray(imageList2[i], temp));
					}
				}
			}
		}
	}
	
	if (imageList.length == 1) {
		if (isOpen(acceptorName+"_clean")) {
			selectWindow(acceptorName+"_clean");
			acceptor = getInfo("image.directory")+getInfo("image.filename");
		} else {
			index = lastIndexOf(donor, donorName);
			if (index != -1) {
				acceptor = substring(donor, 0, index)+acceptorName+substring(donor, index+lengthOf(donorName), lengthOf(donor));
			} else {
				acceptor = "";
			}
			if(!File.exists(acceptor)) {
				acceptor = chooseFile("Select clean acceptor image");
			}
			if (alreadyOpen) {
				open(acceptor);
				rename(acceptorName+"_clean");
				setLocation(0.5*screenWidth, 0.1*screenHeight);
				run("Enhance Contrast", "saturated=0.35");
			}
		}
		imageList = Array.concat(imageList, acceptor);
	}
	
	run("Set Measurements...", "mean standard min median redirect=None decimal=3");
	
	for (i = 0; i < imageList.length/2; i++) {
		if (!alreadyOpen) {
			donor = imageList[2*i];
			index = lastIndexOf(donor, donorName);
			open(donor);
			rename(donorName+"_clean");
			setLocation(0.05*screenWidth, 0.1*screenHeight);
			run("Enhance Contrast", "saturated=0.35");
			acceptor = imageList[2*i+1];
			open(acceptor);
			rename(acceptorName+"_clean");
			setLocation(0.5*screenWidth, 0.1*screenHeight);
			run("Enhance Contrast", "saturated=0.35");
		} else {
			selectWindow(donorName+"_clean");
		}
		
		folderPath = getInfo("image.directory");
		
		// Prepare a file to put min threshold values used
		index2 = lastIndexOf(donor, "CROP");
		index = lastIndexOf(donor, donorName);
		if (index2 != -1 && index > index2+5) {
			thresholdUsed = folderPath + File.separator + "thresholdUsedCROP"+substring(donor, index2+4, index-1)+".txt";
		} else {
			thresholdUsed = folderPath + File.separator + "thresholdUsed.txt";
		}
		
		updateThreshold = true;
		
		while (updateThreshold) {
			if (isOpen(donorName+"_test")) {
				selectWindow(donorName+"_test");
				close();
				selectWindow(donorName+"_clean");
				run("Restore Selection");
			} else {
				selectWindow(donorName+"_clean");
			}
			thresholdUsedFile = File.open(thresholdUsed);
			if (startsWith(thresholdMethod, "AutoTh")) {
				print(thresholdUsedFile, thresholdMethod);
				msg = "Threshold method: "+thresholdMethod;
				selectWindow(donorName+"_clean");
				run("Select None");
				run("Duplicate...", "title="+donorName+"_test duplicate");
				selectWindow(donorName+"_test");
				setLocation(0.05*screenWidth, 0.4*screenHeight);
				if (endsWith(thresholdMethod, "Chastagnier")) {
					if (!batchDivide) {
						setBatchMode(true);
					}
					run("Duplicate...", "title=donor_test2 duplicate");
					run("Duplicate...", "title=donor_test_otsu duplicate");
					run("Duplicate...", "title=donor_test_li5 duplicate");
					run("Duplicate...", "title=donor_test_li15 duplicate");
					run("Gaussian Blur...", "sigma=15 stack");
					selectWindow("donor_test_li5");
					run("Gaussian Blur...", "sigma=5 stack");
					imageCalculator("Subtract stack", donorName+"_test", "donor_test_li15");
					imageCalculator("Subtract stack", "donor_test2", "donor_test_li5");
					selectWindow(donorName+"_test");
					run("Auto Threshold", "method=Li white stack");
					selectWindow("donor_test2");
					run("Auto Threshold", "method=Li white stack");
					imageCalculator("AND stack", donorName+"_test","donor_test2");
					selectWindow("donor_test_otsu");
					run("Auto Threshold", "method=Otsu ignore_black ignore_white white stack");
					imageCalculator("OR stack", donorName+"_test","donor_test_otsu");
					close("donor_test_li15");
					close("donor_test_li5");
					close("donor_test_otsu");
					close("donor_test2");
					selectWindow(donorName+"_test");
					if (!batchDivide) {
						setBatchMode(false);
					}
				} else {
					run("Auto Threshold", "method="+substring(thresholdMethod, 9, lengthOf(thresholdMethod))+" ignore_black ignore_white white stack");
				}
				run("Duplicate...", "title="+donorName+"_Mask duplicate");
				setLocation(0.5*screenWidth, 0.4*screenHeight);
				selectWindow(donorName+"_test");
				run("Divide...", "value=255 stack");
				run("16-bit");
				imageCalculator("Multiply stack", donorName+"_test", donorName+"_clean");
			} else if (startsWith(thresholdMethod, "AutoLocalTh")) {
				print(thresholdUsedFile, thresholdMethod);
				msg = "Threshold method: "+thresholdMethod;
				selectWindow(donorName+"_clean");
				run("Select None");
				run("Duplicate...", "title="+donorName+"_test duplicate");
				selectWindow(donorName+"_test");
				setLocation(0.05*screenWidth, 0.4*screenHeight);
				run("8-bit");
				run("Auto Local Threshold", "method="+substring(thresholdMethod, 14, lengthOf(thresholdMethod))+" radius="+radiusLocalTh+" parameter_1=0 parameter_2=0 white stack");
				run("Duplicate...", "title="+donorName+"_Mask duplicate");
				setLocation(0.05*screenWidth, 0.4*screenHeight);
				selectWindow(donorName+"_test");
				run("Divide...", "value=255 stack");
				run("16-bit");
				imageCalculator("Multiply stack", donorName+"_test", donorName+"_clean");
			} else {
				// Choose area to calculate a "dynamic threshold"
				title = "Threshold area selection";
				msg = "Please select an area for the threshold, then click \"OK\".";
				if (matches(thresholdMethod, "Median")) {
					msg += "\nCurrent threshold level: area median";
				} else {
					msg += "\nCurrent threshold level: area mean * "+coefMultMeanROI;
				}
				waitForUser(title, msg);
				run("Select None");
				
				if (matches(thresholdMethod, "Median")) {
					msg = "Threshold method: area median";
				} else {
					msg = "Threshold method: area mean * "+coefMultMeanROI;
				}
			
				selectWindow(donorName+"_clean");
				run("Duplicate...", "title="+donorName+"_test duplicate");
				selectWindow(donorName+"_test");
				setLocation(0.05*screenWidth, 0.4*screenHeight);
				for (n=1; n<=nSlices; n++) {
					setSlice(n);
					run("Restore Selection");
					run("Measure");
					if (matches(thresholdMethod, "Median")) {
						thresholdValue = getResult("Median");
						print(thresholdUsedFile, "Slice "+n+" : "+thresholdValue+" (Median)");
					} else {
						thresholdValue = getResult("Mean") * coefMultMeanROI;
						print(thresholdUsedFile, "Slice "+n+" : "+thresholdValue+" (Mean * "+coefMultMeanROI+")");
					}
					run("Select None");
					changeValues(0, thresholdValue, 0); // Put all values under the threshold to 0
				}
			}
			
			if (overallMinThreshold > 0) {
				for (n=1; n<=nSlices; n++) {
					setSlice(n);
					changeValues(0, overallMinThreshold, 0); // set to 0 pixels for which value is under the "minimum threshold"
				}
			}
			print(thresholdUsedFile, "Overall Minimum Threshold : "+overallMinThreshold);
			File.close(thresholdUsedFile);
			
			run("Enhance Contrast", "saturated=0.35");
			
			if (!batchDivide) {
				if (nSlices != 1) {
					title = "Check";
					msg = "Check values then click \"OK\".\n"+msg;
					waitForUser(title, msg); // Allow the user to verify values along the stack before the dialog
				}
				close(donorName+"_Mask");
				Dialog.create("Threshold settings");
				Dialog.addChoice("Threshold method", newArray("Median", "Mean * Coefficient", "AutoTh - Otsu", "AutoTh - Chastagnier", "AutoLocalTh - Phansalkar",  
						"AutoLocalTh - MidGrey", "AutoLocalTh - Niblack"), thresholdMethod);
				Dialog.addNumber("Coefficient", coefMultMeanROI);
				Dialog.addNumber("AutoLocalTh radius", radiusLocalTh);
				Dialog.addNumber("Minimum threshold", overallMinThreshold);
				Dialog.addHelp("http://htmlpreview.github.com/?https://github.com/ychastagnier/LR-Analyzer/blob/master/help/threshold.html");
				Dialog.addCheckbox("Update Threshold Settings?", updateThreshold);
				Dialog.show();
				thresholdMethod = Dialog.getChoice();
				call("ij.Prefs.set", "LRA.thresholdMethod", thresholdMethod);
				coefMultMeanROI = Dialog.getNumber();
				call("ij.Prefs.set", "LRA.coefMultMeanROI", coefMultMeanROI);
				radiusLocalTh = Dialog.getNumber();
				call("ij.Prefs.set", "LRA.radiusLocalTh", radiusLocalTh);
				overallMinThreshold = Dialog.getNumber();
				call("ij.Prefs.set", "LRA.overallMinThreshold", overallMinThreshold);
				updateThreshold = Dialog.getCheckbox();
			} else {
				updateThreshold = false;
			}
		}
		
		close(donorName+"_clean");
		selectWindow(donorName+"_test");
		rename(donorName+"_clean");
		setLocation(0.05*screenWidth, 0.1*screenHeight);
		
		run("Misc...", "divide=0.0");
		
		imageCalculator("Divide create 32-bit stack", acceptorName+"_clean", donorName+"_clean");
		selectWindow(donorName+"_clean");
		close();
		selectWindow(acceptorName+"_clean");
		close();
		selectWindow("Result of "+acceptorName+"_clean");
		rename("Ratio");
		setLocation(0.05*screenWidth, 0.1*screenHeight);
		call("ij.ImagePlus.setDefault16bitRange", 16);
		
		// Create a duplicate of the Ratio image with computed color range
		run("Duplicate...", "title=Ratio_AutoRange duplicate");
		setLocation(0.5*screenWidth, 0.1*screenHeight);
		setThreshold(0.01, 10, "no color");
		run("NaN Background", "stack");
		run("Statistics");
		minStack = getResult("Min");
		maxStack = getResult("Max");
		cumulHisto = newArray(256);
		nHisto = 0;
		selectWindow("Ratio_AutoRange");
		for (n=1; n<=nSlices; n++) {
			setSlice(n);
			getHistogram(values, counts, 256, minStack, maxStack);
			for (j=0; j<256; j++) {
				cumulHisto[j] += counts[j];
				nHisto += counts[j];
			}
		}
		count = 0;
		icount = -1;
		limit = 0.005;
		lowlimit = limit * nHisto;
		highlimit = (1 - limit) * nHisto;
		while (count <= lowlimit && icount < 255) {
			icount++;
			count += cumulHisto[icount];
		}
		minStack = values[icount];
		while (count < highlimit && icount < 255) {
			icount++;
			count += cumulHisto[icount];
		}
		maxStack = values[icount];
		setMinAndMax(minStack,maxStack);
		run("16 colors");
		
		if(i == 0 && !batchDivide) { // The user adjust the range based on the first image
			while (updateMinMax) {
				selectWindow("Ratio");
				setMinAndMax(rangeMin, rangeMax);
				run("16 colors");
				run("Histogram", "bins=256 use x_min=0 x_max=2 y_max=Auto");
				rename("Slice Histogram of Ratio");
				setLocation(0.33*screenWidth, 0.2*screenHeight);
				selectWindow("Ratio");
				run("Histogram", "bins=256 x_min="+minStack+" x_max="+maxStack+" y_max=Auto stack");
				rename("Stack Histogram of Ratio");
				setLocation(0.33*screenWidth, 0.55*screenHeight);
				
				title = "Check";
				msg = "Check values ["+rangeMin+", "+rangeMax+"] then click \"OK\".\nAuto Range : ["+minStack+", "+maxStack+"]";
				waitForUser(title, msg);
				
				Dialog.create("Choose range");
				Dialog.addNumber("Min:", rangeMin);
				Dialog.addNumber("Max:", rangeMax);
				Dialog.addCheckbox("Update Min and Max?", true);
				Dialog.show();
				rangeMin = Dialog.getNumber();
				call("ij.Prefs.set", "LRA.rangeMin", rangeMin);
				rangeMax = Dialog.getNumber();
				call("ij.Prefs.set", "LRA.rangeMax", rangeMax);
				updateMinMax = Dialog.getCheckbox();
				if (isOpen("Slice Histogram of Ratio")) {
					selectWindow("Slice Histogram of Ratio");
					run("Close");
				}
				if (isOpen("Stack Histogram of Ratio")) {
					selectWindow("Stack Histogram of Ratio");
					run("Close");
				}
			}
		} else {
			selectWindow("Ratio");
			setMinAndMax(rangeMin, rangeMax);
			run("16 colors");
			if (!batchDivide) {
				title = "Ranges";
				msg = "Normal range : ["+rangeMin+", "+rangeMax+"]\nAuto Range : ["+minStack+", "+maxStack+"]";
				waitForUser(title, msg);
			}
		}
		
		// Save Ratio image
		selectWindow("Ratio_AutoRange");
		close();		
		selectWindow("Ratio");
		indexClean = lastIndexOf(donor, "_clean.tif");
		indexLastFileSep = lastIndexOf(donor, File.separator);
		indexExtension = lastIndexOf(donor, ".");
		if (index <= indexLastFileSep) { // donorName is not in the file name
			if (indexClean <= indexLastFileSep) { // "Clean" tool was not used on this image
				if (indexExtension <= indexLastFileSep) { // image has no extension
					saveAs("tiff", donor+"_Ratio");
				} else { // image has extension
					saveAs("tiff", substring(donor, 0, indexExtension)+"_Ratio");
				}
			} else { // image ends with _clean.tif
				saveAs("tiff", substring(donor, 0, indexClean)+"_Ratio");
			}
		} else { // donorName is in the file name
			if (indexClean <= indexLastFileSep) { // but no clean
				if (indexExtension < index) { // image has no extension or donorName is after last dot
					saveAs("tiff", substring(donor, 0, index)+"Ratio"+substring(donor, index+lengthOf(donorName), lengthOf(donor)));
				} else { // image has extension
					saveAs("tiff", substring(donor, 0, index)+"Ratio"+substring(donor, index+lengthOf(donorName), indexExtension));
				}
			} else { // and it was cleaned, this should be most general case
				saveAs("tiff", substring(donor, 0, index)+"Ratio"+substring(donor, index+lengthOf(donorName), lengthOf(donor)-10));
			}
		}
		close();
	}
	
	if (isOpen("Results")) {
		selectWindow("Results");
		run("Close");
	}
	
	if (batchDivide) {
		close("*");
		setBatchMode(false);
		if (lengthOf(imageList) == 0) {
			print("No pairs of images were found with donorName", donorName, "and acceptorName", acceptorName, "in the selected folder.");
		}
		beep();
		print("Divide Operation finished.");
	}
	showStatus("Divide Operation finished.");
}


// **************************************************
// Ratio Analysis
// **************************************************
function makeRatioAnalysis() {
	imagesPaths = newArray();
	roiManagerNames = getRoiManagerNames();
	
	// close images which names don't start with "Ratio"
	imageTitles = getList("image.titles");
	for (i = 0; i < imageTitles.length; i++) {
		if (!startsWith(imageTitles[i], "Ratio")) {
			selectWindow(imageTitles[i]);
			close();
		}
	}
	imageTitles = getList("image.titles");
	
	// close images without rois
	for (i = 0; i < imageTitles.length; i++) {
		delete = true;
		for (j = 0; j < roiManagerNames.length; j++) {
			if (startsWith(roiManagerNames[j], imageTitles[i])) {
				delete = false;
				break;
			}
		}
		if (delete) {
			selectWindow(imageTitles[i]);
			close();
		}
	}
	// delete rois without image
	for (j = roiManagerNames.length-1; j >= 0; j--) {
		delete = true;
		for (i = 0; i < imageTitles.length; i++) {
			if (startsWith(roiManagerNames[j], imageTitles[i])) {
				delete = false;
				break;
			}
		}
		if (delete) {
			roiManager("Select", j);
			roiManager("Delete");
		}
	}
	
	// update numbering to avoid "holes"
	imageTitles = getList("image.titles");
	Array.sort(imageTitles);
	roiManager("Sort");
	roiManagerNames = getRoiManagerNames();
	nbImages = 0;
	for (i = 0; i < imageTitles.length; i++) {
		nbImages++;
		roiNb = 0;
		if (nbImages != parseInt(substring(imageTitles[i], 4))) {
			selectWindow(imageTitles[i]);
			setLocImage(nbImages);
			rename("Ratio"+IJ.pad(nbImages,2));
			for (j = 0; j < roiManagerNames.length; j++) {
				if (startsWith(roiManagerNames[j], imageTitles[i])) {
					roiNb++;
					roiManager("Select", j);
					roiManager("Rename", "Ratio"+IJ.pad(nbImages,2)+"_"+IJ.pad(roiNb,2));
				}
			}
		} else {
			selectWindow(imageTitles[i]);
			for (j = 0; j < roiManagerNames.length; j++) {
				if (startsWith(roiManagerNames[j], imageTitles[i])) {
					roiNb++;
				}
			}
		}
		imagePath = getInfo("image.directory")+getInfo("image.filename");
		imagesPaths = Array.concat(imagesPaths, imagePath);
		if (nbImages == 1) {
			folderPath = getDirectory("image");
		}
		nbROIsArray[nbImages] = roiNb+nbROIsArray[nbImages-1];
		nbSlicesArray[nbImages-1] = nSlices;
		nbSlicesTotArray[nbImages] = nSlices+nbSlicesTotArray[nbImages-1];
		nbValuesTotArray[nbImages] = roiNb*nSlices+nbValuesTotArray[nbImages-1];
	}
	
	if (nbImages != 0) {
		Dialog.create("Add another stack");
		Dialog.addCheckbox("Add another stack?", false);
		Dialog.show();
		addImages = Dialog.getCheckbox();
	} else {
		addImages = true;
	}
	
	while (addImages) {
		imageRatio = chooseFile("Select Ratio image "+(nbImages+1));
		imageRatioCopy = imageRatio;
		if (endsWith(imageRatio, ".txt")) { // If the user selects a text file instead of an image, read the file to get the list of images to open
			imagesList = split(File.openAsString(imageRatio),"\n");
			imagesNumber = imagesList.length;
			startPath = File.getParent(File.getParent(imageRatio));
			usetxt = true;
		} else {
			imagesNumber = 1;
			usetxt = false;
		}
		
		for (j = 0; j < imagesNumber; j++) {
			cancel = false;
			if (usetxt) {
				midEndPath = split(imagesList[j], "( ____ )");
				if (midEndPath.length == 2) {
					imageRatio = startPath + File.separator + midEndPath[0] + File.separator + midEndPath[1];
				} else {
					commonSize = getCommonStartPath(imagesList[j], imagesList[imagesNumber-1]);
					imageRatioCopySplit = split(imageRatioCopy, "\\\/");
					imageRatio = ""+getSubPath(imageRatioCopy, 0, imageRatioCopySplit.length - commonSize[2])+File.separator+getSubPath(imagesList[j], 0, -commonSize[1]);
					if (!File.exists(imageRatio)) {
						cancel = true;
					}
				}
			}
			if (!cancel) {
				nbImages++;
				open(imageRatio);
				rename("Ratio"+IJ.pad(nbImages,2));
				imagePath = getInfo("image.directory")+getInfo("image.filename");
				imageAlreadyOpen = -1;
				for (i = 0; i < imagesPaths.length; i++) {
					if (samePaths(imagesPaths[i],imagePath)) {
						imageAlreadyOpen = i+1;
						break;
					}
				}
				if (imageAlreadyOpen!=-1) {
					close();
					nbImages--;
					if (!usetxt) {
						nbNewROIs = roiManager("count");
						selectWindow("Ratio"+IJ.pad(imageAlreadyOpen,2));
						if (weightImage) {
							buildWeightedImage();
						}
						title = "ROIs selection";
						msg = "Image already open.\nAdd your regions (Ctrl+T) to the ROI manager for image Ratio"+IJ.pad(imageAlreadyOpen,2)+", then click \"OK\".";
						waitForUser(title, msg); // New regions selection
						if (isOpen("Weighted")) {
							close("Weighted");
						}
						nbNewROIs = roiManager("count") - nbNewROIs;
						if (nbNewROIs > 0) {
							for (i = 0; i < nbNewROIs; i++) {
								roiManager("select", nbROIsArray[nbImages]+i);
								roiManager("Rename", "Ratio"+IJ.pad(imageAlreadyOpen,2)+"_"+IJ.pad(nbROIsArray[nbImages]-nbROIsArray[nbImages-1]+i,2));
							}
							for (i = imageAlreadyOpen; i <= nbImages; i++) {
								nbROIsArray[i] = nbNewROIs + nbROIsArray[i];
							}
							roiManager("Sort");
						}
					}
				} else {
					if (nbImages == 1) {
						folderPath = getDirectory("image");
					}
					setLocImage(nbImages);
					roisPath = getROIPath();
					if (File.exists(roisPath)) {
						i = roiManager("count");
						roiManager("Open", roisPath);
						i = roiManager("count") - i;
						msg = ""+i+" ROI(s) have been loaded in the manager for image Ratio"+IJ.pad(nbImages,2)+".\n";
					} else {
						msg = "";
					}
					
					if (!usetxt) {
						if (weightImage) {
							buildWeightedImage();
						}
						title = "ROIs selection";
						msg = msg+"Add your regions (Ctrl+T) to the ROI manager for image Ratio"+IJ.pad(nbImages,2)+", then click \"OK\".";
						waitForUser(title, msg); // New regions selection
						if (isOpen("Weighted")) {
							close("Weighted");
						}
					}
					roiNb = roiManager("count") - nbROIsArray[nbImages-1]; 
					if (lengthOf(nbROIsArray) > nbImages) {
						nbROIsArray[nbImages] = roiManager("count");
						nbSlicesTotArray[nbImages] = nSlices+nbSlicesTotArray[nbImages-1];
						nbValuesTotArray[nbImages] = roiNb*nSlices+nbValuesTotArray[nbImages-1];
						nbSlicesArray[nbImages-1] = nSlices;
					} else {
						nbROIsArray = Array.concat(nbROIsArray, roiManager("count"));
						nbSlicesTotArray = Array.concat(nbSlicesTotArray, nSlices+nbSlicesTotArray[nbImages-1]);
						nbValuesTotArray = Array.concat(nbValuesTotArray, roiNb*nSlices+nbValuesTotArray[nbImages-1]);
						nbSlicesArray = Array.concat(nbSlicesArray, nSlices);
					}
					if (nbROIsArray[nbImages]-nbROIsArray[nbImages-1]==0) {
						close();
						nbImages--;
						showMessage("Image closed", "The image was closed because no regions were selected on it.");
					} else {
						imagesPaths = Array.concat(imagesPaths, imagePath);
						for (i = 0; i < nbROIsArray[nbImages]-nbROIsArray[nbImages-1]; i++) {
							roiManager("select", nbROIsArray[nbImages-1]+i);
							roiManager("Rename", "Ratio"+IJ.pad(nbImages,2)+"_"+IJ.pad(i+1,2));
						}
					}
				}
			}
		}
		
		Dialog.create("Add another stack");
		Dialog.addCheckbox("Add another stack?", true);
		Dialog.show();
		addImages = Dialog.getCheckbox();
	}
	tempArray = Array.trim(nbSlicesArray, nbImages);
	Array.getStatistics(tempArray, nbSlicesMin, nbSlicesMax, nbSlicesMean, nbSlicesStdDev);
	Dialog.create("Parameters");
	if (nbSlicesMax > 1) {
		Dialog.addNumber("Time between images (s)", time_between_images_sec);
		Dialog.addNumber("Slice to use for normalization", normalizeSlice);
	}
	Dialog.addChoice("Plot Ratio vs intensity?", newArray("No", "Vs intensity", "Vs intensity ratio"), plot3D);
	Dialog.addString("Folder and Data Name", dataFolderName, 18);
	Dialog.addHelp("http://htmlpreview.github.com/?https://github.com/ychastagnier/LR-Analyzer/blob/master/help/analyse.html");
	Dialog.show();
	if (nbSlicesMax > 1) {
		time_between_images_sec = Dialog.getNumber();
		call("ij.Prefs.set", "LRA.time_between_images_sec", time_between_images_sec);
		normalizeSlice = Dialog.getNumber();
		call("ij.Prefs.set", "LRA.normalizeSlice", normalizeSlice);
	}
	plot3D = Dialog.getChoice();
	call("ij.Prefs.set", "LRA.plot3D", plot3D);
	dataFolderName = Dialog.getString();
	
	if (matches(dataFolderName, "")) {
		dataFolderName = "data";
	}
	call("ij.Prefs.set", "LRA.dataFolderName", dataFolderName);
	
	f = File.open(folderPath+dataFolderName+".txt");
	for (i = 0; i < imagesPaths.length; i++) {
		duplicate = false;
		for (j = 0; j < i; j++) {
			if (samePaths(imagesPaths[i],imagesPaths[j])) {
				duplicate = true;
			}
		}
		if (!duplicate) {
			print(f, imagesPaths[i]);
		}
	}
	print(f, folderPath+dataFolderName+".txt"); // writes the file name at the end of the file for relative path building
	File.close(f);
	
	nbROI = roiManager("count");	
	// **************************************************
	// 3D Plot (vs Intensity (Ratio)) Part 1/2 (measure) 
	// **************************************************
	if (!matches(plot3D, "No")) {
		run("Clear Results");
		intensityMeasures = newArray(nbROI);
		vsRatio = endsWith(plot3D, "ratio");
		if (vsRatio) {
			intensityMeasures2 = newArray(nbROI);
			vIorvIR = "vIR";
		} else {
			vIorvIR = "vI";
		}
		for (i = 1; i <= nbImages; i++) {
			selectWindow("Ratio"+IJ.pad(i,2));
			imagePath = getInfo("image.directory")+getInfo("image.filename");
			if (File.exists(imagePath)) {
				extIndex = lastIndexOf(imagePath, ".");
				if (extIndex == -1) {
					extIndex = lengthOf(imagePath);
				}
				vsIntensityFolder = substring(imagePath, 0, extIndex)+"_vsIntensity"+File.separator;
				File.makeDirectory(vsIntensityFolder);
				vsIntensityPath = vsIntensityFolder+vIorvIR+"1.txt";
				if (File.exists(vsIntensityPath)) {
					str = File.openAsString(vsIntensityPath);
					str = split(str, "( ____ )");
					vsIntensityImagePath = vsIntensityFolder+str[0];
					if (!File.exists(vsIntensityImagePath)) {
						vsIntensityImagePath = chooseFile("Select intensity image 1 corresponding to Ratio"+IJ.pad(i,2));
					}
					open(vsIntensityImagePath);
					rename("Intensity 1 of Ratio"+IJ.pad(i,2)+"_"+IJ.pad(nbROIsArray[i-1]+1,2));
					setLocation(0.40*screenWidth, 0.1*screenHeight);
				}
				if (vsRatio) {
					vsIntensityPath = vsIntensityFolder+vIorvIR+"2.txt";
					if (File.exists(vsIntensityPath)) {
						str = File.openAsString(vsIntensityPath);
						str = split(str, "( ____ )");
						vsIntensityImagePath = vsIntensityFolder+str[0];
						if (!File.exists(vsIntensityImagePath)) {
							vsIntensityImagePath = chooseFile("Select intensity image 2 corresponding to Ratio"+IJ.pad(i,2));
						}
						open(vsIntensityImagePath);
						rename("Intensity 2 of Ratio"+IJ.pad(i,2)+"_"+IJ.pad(nbROIsArray[i-1]+1,2));
						setLocation(0.45*screenWidth, 0.2*screenHeight);
					}
				}
			} else {
				vsIntensityFolder = " ";
			}
			for (j = nbROIsArray[i-1]; j < nbROIsArray[i]; j++) {
				selectWindow("Ratio"+IJ.pad(i,2));
				roiManager("select", j);
				
				if (j == nbROIsArray[i-1] && !isOpen("Intensity 1 of Ratio"+IJ.pad(i,2)+"_"+IJ.pad(j+1,2))) {
					int1FullPath = chooseFile("Select intensity image 1 corresponding to Ratio"+IJ.pad(i,2));
					open(int1FullPath);
					commonSize = getCommonStartPath(vsIntensityFolder, int1FullPath);
					relativePath = "";
					for (k = 0; k < commonSize[1]; k++) {
						relativePath += ".."+File.separator;
					}
					relativePath = relativePath+getSubPath(int1FullPath, commonSize[0], commonSize[2])+" ____ ";
					int1FullPathID = File.open(vsIntensityFolder+vIorvIR+"1.txt");
					print(int1FullPathID, relativePath);
					File.close(int1FullPathID);
					rename("Intensity 1 of Ratio"+IJ.pad(i,2)+"_"+IJ.pad(j+1,2));
					setLocation(0.40*screenWidth, 0.1*screenHeight);
				} else {
					selectWindow("Intensity 1 of Ratio"+IJ.pad(i,2)+"_"+IJ.pad(j+1,2));
				}
				vsIntensityROIpath = vsIntensityFolder+vIorvIR+"1_"+(j-nbROIsArray[i-1]+1)+".txt";
				if (File.exists(vsIntensityROIpath)) {
					loadSelectionAsPoints(vsIntensityROIpath);
				} else {
					roiManager("select", j);
					roiManager("deselect");
				}
				// User prompt to select fluorescent area
				title = "Area selection";
				msg = "Please select intensity area, then click \"OK\".";
				waitForUser(title, msg);
				if (isOpen("Intensity 1 of Ratio"+IJ.pad(i,2)+"_"+IJ.pad(j+1,2))) {
					selectWindow("Intensity 1 of Ratio"+IJ.pad(i,2)+"_"+IJ.pad(j+1,2));
				}
				saveSelectionAsPoints(vsIntensityROIpath);
				run("Measure");
				intensityMeasures[j] = round(getResult("Mean"));
				if (j == nbROIsArray[i]-1) {
					close();
				} else {
					rename("Intensity 1 of Ratio"+IJ.pad(i,2)+"_"+IJ.pad(j+2,2));
				}
				if (vsRatio) {
					if (j == nbROIsArray[i-1] && !isOpen("Intensity 2 of Ratio"+IJ.pad(i,2)+"_"+IJ.pad(j+1,2))) {
						int2FullPath = chooseFile("Select intensity image 2 corresponding to Ratio"+IJ.pad(i,2));
						open(int2FullPath);
						commonSize = getCommonStartPath(vsIntensityFolder, int2FullPath);
						relativePath = "";
						for (k = 0; k < commonSize[1]; k++) {
							relativePath += ".."+File.separator;
						}
						relativePath = relativePath+getSubPath(int2FullPath, commonSize[0], commonSize[2])+" ____ ";
						int2FullPathID = File.open(vsIntensityFolder+vIorvIR+"2.txt");
						print(int2FullPathID, relativePath);
						File.close(int2FullPathID);
						rename("Intensity 2 of Ratio"+IJ.pad(i,2)+"_"+IJ.pad(j+1,2));
						setLocation(0.45*screenWidth, 0.2*screenHeight);
					} else {
						selectWindow("Intensity 2 of Ratio"+IJ.pad(i,2)+"_"+IJ.pad(j+1,2));
					}
					vsIntensityROIpath = vsIntensityFolder+vIorvIR+"2_"+(j-nbROIsArray[i-1]+1)+".txt";
					if (File.exists(vsIntensityROIpath)) {
						loadSelectionAsPoints(vsIntensityROIpath);
					} else {
						roiManager("select", j);
						roiManager("Deselect");
					}
					waitForUser(title, msg);
					if (isOpen("Intensity 2 of Ratio"+IJ.pad(i,2)+"_"+IJ.pad(j+1,2))) {
						selectWindow("Intensity 2 of Ratio"+IJ.pad(i,2)+"_"+IJ.pad(j+1,2));
					}
					saveSelectionAsPoints(vsIntensityROIpath);
					run("Measure");
					intensityMeasures2[j] = round(getResult("Mean"));
					if (j == nbROIsArray[i]-1) {
						close();
					} else {
						rename("Intensity 2 of Ratio"+IJ.pad(i,2)+"_"+IJ.pad(j+2,2));
					}
				}
			}
		}
	} // end of 3D Plot Part 1/2 (measure)
	
	dataFolderPath = folderPath+dataFolderName+File.separator;
	if (!File.exists(dataFolderPath)) {
		File.makeDirectory(dataFolderPath);
	} else {
		list = getFileList(dataFolderPath);
		for (i = 0; i < list.length; i++) {
			if (endsWith(list[i], ".png") && startsWith(list[i], "Image")) {
				ok = File.delete(dataFolderPath+list[i]);
			}
		}
	}
	
	dataGraphPathCSV = dataFolderPath+dataFolderName+".csv";
	dataGraphPathXLS = dataFolderPath+dataFolderName+".xls";
	dataNormGraphPathCSV = dataFolderPath+dataFolderName+"Norm.csv";
	dataNormGraphPathXLS = dataFolderPath+dataFolderName+"Norm.xls";
	
	time_between_images = time_between_images_sec/60.0;
	if (normalizeSlice > nbSlicesMin || normalizeSlice < 1) {
		normalizeSlice = 1;
	}
	fullIndex = Array.getSequence(nbROI+1);
	for (k = 1; k <= nbImages; k++) {
		selectWindow("Ratio"+IJ.pad(k,2));
		roiPath = getROIPath();
		indexes = Array.slice(fullIndex, nbROIsArray[k-1], nbROIsArray[k]);
		roiManager("select", indexes)
		roiManager("Save Selected", roiPath);
	}
	
	setBatchMode(true);
	for (k = 1; k <= nbImages; k++) {
		selectWindow("Ratio"+IJ.pad(k,2));
		setSlice(normalizeSlice);
		run("Select None");
		roiManager("Deselect");
		run("Duplicate...", "title=Preview"+IJ.pad(k,2));
		indexes = Array.slice(fullIndex, nbROIsArray[k-1], nbROIsArray[k]);
		setColor(0,0,255);
		setFont("SansSerif", 16, "bold");
		for (i = 0; i < indexes.length; i++) {
			roiManager("select", indexes[i]);
			Roi.getBounds(x, y, width, height)
			Overlay.addSelection("blue", 2)
			Overlay.drawString(1+indexes[i], x+width/2-5-6*(floor(log(1+indexes[i])/log(10))), y+height/2+10);
		}
		if (nbROIsArray[k]-nbROIsArray[k-1]==1) {
			saveAs("png", dataFolderPath+"Image"+k+"_ROI"+nbROIsArray[k]);
		} else {
			saveAs("png", dataFolderPath+"Image"+k+"_ROI"+(nbROIsArray[k-1]+1)+"-"+nbROIsArray[k]);
		}
		close();
	}
	
	// Arrays initialization
	arraySize = nbValuesTotArray[nbImages];
	meanROI = newArray(arraySize);
	stdDevROI = newArray(arraySize);
	
	run("Set Measurements...", "mean standard min limit redirect=None decimal=3");
	run("Clear Results");
	// Measure mean and standard deviation
	i = 0;
	for (k = 1; k <= nbImages; k++) {
		selectWindow("Ratio"+IJ.pad(k,2));
		setThreshold(0.01, 65535, "no color");
		for (j = nbROIsArray[k-1]; j < nbROIsArray[k]; j++){
			roiManager("Select", j);
			for (n=1; n<=nbSlicesArray[k-1]; n++) {
				setSlice(n);
				run("Measure");
				meanValueTemp = getResult("Mean");
				if (meanValueTemp != meanValueTemp) { meanValueTemp = 0.0; }
				stdDevValueTemp = getResult("StdDev");
				if (stdDevValueTemp != stdDevValueTemp) { stdDevValueTemp = 0.0; }
				meanROI[i] = meanValueTemp;
				stdDevROI[i] = stdDevValueTemp;
				i++;
			} 
		}
	}
	setBatchMode(false);
	
	run("Clear Results");
	setOption("ShowRowNumbers", false);
	timeArray = newArray(nbSlicesMax);
	colors = newArray("black", "blue","green","magenta","orange","red","yellow","gray","cyan","pink");
	
	for (n=0; n<nbSlicesMax; n++) {
		timeArray[n] = n * time_between_images;
		setResult("t(min)", n, n * time_between_images);
	}
	timeArrayReverse = Array.reverse(Array.copy(timeArray));

	// Normalization of means and standard deviations
	meanROI_Norm = Array.copy(meanROI);
	stdDevROI_Norm = Array.copy(stdDevROI);
	for (k = 1; k <= nbImages; k++) {
		for (j = 0; j < nbROIsArray[k]-nbROIsArray[k-1]; j++){
			tempNorm = meanROI_Norm[nbValuesTotArray[k-1]+j*nbSlicesArray[k-1]+normalizeSlice-1];
			if (tempNorm == 0) {tempNorm = 1;} // prevent division by 0
			for (n = nbValuesTotArray[k-1]+j*nbSlicesArray[k-1]; n < nbValuesTotArray[k-1]+(j+1)*nbSlicesArray[k-1]; n++) {
				meanROI_Norm[n] /= tempNorm;
				stdDevROI_Norm[n] /= tempNorm;
			}
		}
	}
	
	if (nbSlicesMin == nbSlicesMax) {
		slicesByStack = nbSlicesMin;
		// Compute quartiles of regions of interest
		q1 = (nbROI-1) * 0.25;
		q1d = floor(q1);
		q1 = q1 - q1d;
		q3 = (nbROI-1) * 0.75;
		q3d = floor(q3);
		q3 = q3 - q3d;
		q4 = nbROI-1;
		
		q0ROIs = newArray(slicesByStack);
		q1ROIs = newArray(slicesByStack);
		q2ROIs = newArray(slicesByStack);
		q3ROIs = newArray(slicesByStack);
		q4ROIs = newArray(slicesByStack);
		
		q0ROIsSD = newArray(slicesByStack);
		q1ROIsSD = newArray(slicesByStack);
		q2ROIsSD = newArray(slicesByStack);
		q3ROIsSD = newArray(slicesByStack);
		q4ROIsSD = newArray(slicesByStack);
		
		q0ROIsNorm = newArray(slicesByStack);
		q1ROIsNorm = newArray(slicesByStack);
		q2ROIsNorm = newArray(slicesByStack);
		q3ROIsNorm = newArray(slicesByStack);
		q4ROIsNorm = newArray(slicesByStack);
		
		q0ROIsSDNorm = newArray(slicesByStack);
		q1ROIsSDNorm = newArray(slicesByStack);
		q2ROIsSDNorm = newArray(slicesByStack);
		q3ROIsSDNorm = newArray(slicesByStack);
		q4ROIsSDNorm = newArray(slicesByStack);
		
		tempArray = newArray(nbROI);
		tempArraySD = newArray(nbROI);
		tempArrayNorm = newArray(nbROI);
		tempArraySDNorm = newArray(nbROI);
		for (n=0; n<slicesByStack; n++) {	
			for (j=0; j<nbROI; j++) {
				tempArray[j] = meanROI[j*slicesByStack+n];
				tempArraySD[j] = stdDevROI[j*slicesByStack+n];
				tempArrayNorm[j] = meanROI_Norm[j*slicesByStack+n];
				tempArraySDNorm[j] = stdDevROI_Norm[j*slicesByStack+n];
			}
			Array.sort(tempArray);
			Array.sort(tempArraySD);
			Array.sort(tempArrayNorm);
			Array.sort(tempArraySDNorm);
			q0ROIs[n] = tempArray[0];
			q0ROIsSD[n] = tempArraySD[0];
			q0ROIsNorm[n] = tempArrayNorm[0];
			q0ROIsSDNorm[n] = tempArraySDNorm[0];
			q4ROIs[n] = tempArray[q4];
			q4ROIsSD[n] = tempArraySD[q4];
			q4ROIsNorm[n] = tempArrayNorm[q4];
			q4ROIsSDNorm[n] = tempArraySDNorm[q4];
			if (nbROI % 2 == 0) {
				q2ROIs[n] = (tempArray[nbROI/2]+tempArray[nbROI/2-1])/2;
				q2ROIsSD[n] = (tempArraySD[nbROI/2]+tempArraySD[nbROI/2-1])/2;
				q2ROIsNorm[n] = (tempArrayNorm[nbROI/2]+tempArrayNorm[nbROI/2-1])/2;
				q2ROIsSDNorm[n] = (tempArraySDNorm[nbROI/2]+tempArraySDNorm[nbROI/2-1])/2;
			} else {
				q2ROIs[n] = tempArray[(nbROI-1)/2];
				q2ROIsSD[n] = tempArraySD[(nbROI-1)/2];
				q2ROIsNorm[n] = tempArrayNorm[(nbROI-1)/2];
				q2ROIsSDNorm[n] = tempArraySDNorm[(nbROI-1)/2];
			}
			if (q1 == 0) {
				q1ROIs[n] = tempArray[q1d];
				q3ROIs[n] = tempArray[q3d];
				q1ROIsSD[n] = tempArraySD[q1d];
				q3ROIsSD[n] = tempArraySD[q3d];
				q1ROIsNorm[n] = tempArrayNorm[q1d];
				q3ROIsNorm[n] = tempArrayNorm[q3d];
				q1ROIsSDNorm[n] = tempArraySDNorm[q1d];
				q3ROIsSDNorm[n] = tempArraySDNorm[q3d];
			} else {
				q1ROIs[n] = tempArray[q1d]*(1-q1)+tempArray[q1d+1]*q1;
				q3ROIs[n] = tempArray[q3d]*(1-q3)+tempArray[q3d+1]*q3;
				q1ROIsSD[n] = tempArraySD[q1d]*(1-q1)+tempArraySD[q1d+1]*q1;
				q3ROIsSD[n] = tempArraySD[q3d]*(1-q3)+tempArraySD[q3d+1]*q3;
				q1ROIsNorm[n] = tempArrayNorm[q1d]*(1-q1)+tempArrayNorm[q1d+1]*q1;
				q3ROIsNorm[n] = tempArrayNorm[q3d]*(1-q3)+tempArrayNorm[q3d+1]*q3;
				q1ROIsSDNorm[n] = tempArraySDNorm[q1d]*(1-q1)+tempArraySDNorm[q1d+1]*q1;
				q3ROIsSDNorm[n] = tempArraySDNorm[q3d]*(1-q3)+tempArraySDNorm[q3d+1]*q3;
			}
		}
	}
	
	if (nbSlicesMax != 1) {
		
		// Mean and standard deviation values normalized
		i = 0;
		for (k = 1; k <= nbImages; k++) {
			for (j = 0; j < nbROIsArray[k]-nbROIsArray[k-1]; j++){
				tempValue = nbValuesTotArray[k-1]+j*nbSlicesArray[k-1];
				tempROIArray = Array.slice(meanROI_Norm, tempValue, tempValue + nbSlicesArray[k-1]);
				i++;
				for (n = 0; n < nbSlicesArray[k-1]; n++) {
					setResult("mean"+i, n, tempROIArray[n]);
				}
			}
		}
		i = 0;
		for (k = 1; k <= nbImages; k++) {
			for (j = 0; j < nbROIsArray[k]-nbROIsArray[k-1]; j++){
				tempValue = nbValuesTotArray[k-1]+j*nbSlicesArray[k-1];
				tempROIArray = Array.slice(stdDevROI_Norm, tempValue, tempValue + nbSlicesArray[k-1]);
				i++;
				for (n = 0; n < nbSlicesArray[k-1]; n++) {
					setResult("stdDev"+i, n, tempROIArray[n]);
				}
			}
		}
		
		// Save normalized results
		if (nbSlicesMin == nbSlicesMax) {
			for (n=0; n<slicesByStack; n++) {
				setResult("Min", n, q0ROIsNorm[n]);
				setResult("1st quartile", n, q1ROIsNorm[n]);
				setResult("Median", n, q2ROIsNorm[n]);
				setResult("3rd quartile", n, q3ROIsNorm[n]);
				setResult("Max", n, q4ROIsNorm[n]);
				setResult("SD Min", n, q0ROIsSDNorm[n]);
				setResult("SD 1st quartile", n, q1ROIsSDNorm[n]);
				setResult("SD Median", n, q2ROIsSDNorm[n]);
				setResult("SD 3rd quartile", n, q3ROIsSDNorm[n]);
				setResult("SD Max", n, q4ROIsSDNorm[n]);
			}
		}
		saveAs("Results", dataNormGraphPathCSV);
		saveAs("Results", dataNormGraphPathXLS);
		// Converts dots to commas in xls file
		dataNormXLS = File.openAsString(dataNormGraphPathXLS);
		dataNormXLS = replace(dataNormXLS, ".", ",");
		File.saveString(dataNormXLS, dataNormGraphPathXLS)
		
		if (nbSlicesMin == nbSlicesMax) {
			// Graph quartiles of mean values normalized
			Plot.create("Distribution of means (normalized data)", "Time (min)", "Distribution of means");
			Plot.setColor("blue");
			Plot.add("line", timeArray, q4ROIsNorm);
			graphLegend = "Max";
			Plot.setColor("green");
			Plot.add("line", timeArray, q3ROIsNorm);
			graphLegend += "\t3rd quartile";
			Plot.setColor("red");
			Plot.setLineWidth(2);
			Plot.add("line", timeArray, q2ROIsNorm);
			graphLegend += "\tMedian";
			Plot.setColor("green");
			Plot.setLineWidth(1);
			Plot.add("line", timeArray, q1ROIsNorm);
			graphLegend += "\t1st quartile";
			Plot.setColor("blue");
			Plot.add("line", timeArray, q0ROIsNorm);
			graphLegend += "\tMin";
			
			Plot.setLegend(graphLegend);
			Plot.show();
			Plot.setLimitsToFit();
			setLocation(0.70*screenWidth, 0.1*screenHeight);
			
			doubleTimeArray = Array.concat(timeArray, timeArrayReverse);
			doubleTimeArray2 = Array.copy(doubleTimeArray);
			q04ROIsNorm = Array.concat(q0ROIsNorm, Array.reverse(Array.copy(q4ROIsNorm)));
			q13ROIsNorm = Array.concat(q1ROIsNorm, Array.reverse(Array.copy(q3ROIsNorm)));
			
			toUnscaled(doubleTimeArray, q13ROIsNorm); // Convert to image coordinates
			makeSelection("polygon", doubleTimeArray, q13ROIsNorm);
			changeValues(0xffffff, 0xffffff, 0x00ff00); // Change white to green
			run("Select None");
			toUnscaled(doubleTimeArray2, q04ROIsNorm); // Convert to image coordinates
			makeSelection("polygon", doubleTimeArray2, q04ROIsNorm);
			changeValues(0xffffff, 0xffffff, 0x0000ff); // Change white to blue
			run("Select None");
			
			Plot.freeze();
			
			
			// Graph quartiles of normalized standard deviation values
			Plot.create("Distribution of standard deviations (normalized data)", "Time (min)", "Distribution of standard deviations");
			Plot.setColor("blue");
			Plot.add("line", timeArray, q4ROIsSDNorm);
			graphLegend = "Max";
			Plot.setColor("green");
			Plot.add("line", timeArray, q3ROIsSDNorm);
			graphLegend += "\t3rd quartile";
			Plot.setColor("red");
			Plot.setLineWidth(2);
			Plot.add("line", timeArray, q2ROIsSDNorm);
			graphLegend += "\tMedian";
			Plot.setColor("green");
			Plot.setLineWidth(1);
			Plot.add("line", timeArray, q1ROIsSDNorm);
			graphLegend += "\t1st quartile";
			Plot.setColor("blue");
			Plot.add("line", timeArray, q0ROIsSDNorm);
			graphLegend += "\tMin";
			
			Plot.setLegend(graphLegend);
			Plot.show();
			Plot.setLimitsToFit();
			setLocation(0.70*screenWidth, 0.5*screenHeight);
		
			doubleTimeArray = Array.concat(timeArray, timeArrayReverse);
			doubleTimeArray2 = Array.copy(doubleTimeArray);
			q04ROIsSDNorm = Array.concat(q0ROIsSDNorm, Array.reverse(q4ROIsSDNorm));
			q13ROIsSDNorm = Array.concat(q1ROIsSDNorm, Array.reverse(q3ROIsSDNorm));
		
			toUnscaled(doubleTimeArray, q13ROIsSDNorm); // Convert to image coordinates
			makeSelection("polygon", doubleTimeArray, q13ROIsSDNorm);
			changeValues(0xffffff, 0xffffff, 0x00ff00); // Change white to green
			run("Select None");
			toUnscaled(doubleTimeArray2, q04ROIsSDNorm); // Convert to image coordinates
			makeSelection("polygon", doubleTimeArray2, q04ROIsSDNorm);
			changeValues(0xffffff, 0xffffff, 0x0000ff); // Change white to blue
			run("Select None");
		
			Plot.freeze();
		}
		
		// Graph mean values
		Plot.create("Means", "Time (min)", "Mean");
		graphLegend = "";
		i = 0;
		for (k = 1; k <= nbImages; k++) {
			for (j = 0; j < nbROIsArray[k]-nbROIsArray[k-1]; j++){
				tempValue = nbValuesTotArray[k-1]+j*nbSlicesArray[k-1];
				tempROIArray = Array.slice(meanROI, tempValue, tempValue + nbSlicesArray[k-1]);
				Plot.setColor(colors[i%10]);
				i++;
				Plot.add("line", timeArray, tempROIArray);
				graphLegend = graphLegend + "ROI "+i+"\t";
				for (n = 0; n < nbSlicesArray[k-1]; n++) {
					setResult("mean"+i, n, tempROIArray[n]);
				}
			}
		}
		Plot.setLegend(graphLegend);
		Plot.show();
		Plot.setLimitsToFit();
		setLocation(0.40*screenWidth, 0.1*screenHeight);
		
		// Graph standard deviation
		Plot.create("Standard deviations", "Time (min)", "Standard deviation");
		i = 0;
		for (k = 1; k <= nbImages; k++) {
			for (j = 0; j < nbROIsArray[k]-nbROIsArray[k-1]; j++){
				tempValue = nbValuesTotArray[k-1]+j*nbSlicesArray[k-1];
				tempROIArray = Array.slice(stdDevROI, tempValue, tempValue + nbSlicesArray[k-1]);
				Plot.setColor(colors[i%10]);
				Plot.add("line", timeArray, tempROIArray);
				i++;
				graphLegend = graphLegend + "ROI "+i+"\t";
				for (n = 0; n < nbSlicesArray[k-1]; n++) {
					setResult("stdDev"+i, n, tempROIArray[n]);
				}
			}
		}
		Plot.setLegend(graphLegend);
		Plot.show();
		Plot.setLimitsToFit();
		setLocation(0.40*screenWidth, 0.5*screenHeight);
		
		// Save results
		if (nbSlicesMin == nbSlicesMax) {
			for (n=0; n<slicesByStack; n++) {
				setResult("Min", n, q0ROIs[n]);
				setResult("1st quartile", n, q1ROIs[n]);
				setResult("Median", n, q2ROIs[n]);
				setResult("3rd quartile", n, q3ROIs[n]);
				setResult("Max", n, q4ROIs[n]);
				setResult("SD Min", n, q0ROIsSD[n]);
				setResult("SD 1st quartile", n, q1ROIsSD[n]);
				setResult("SD Median", n, q2ROIsSD[n]);
				setResult("SD 3rd quartile", n, q3ROIsSD[n]);
				setResult("SD Max", n, q4ROIsSD[n]);
			}
		}
		
		if (isOpen("Plot Values")) {
			selectWindow("Plot Values");
			run("Close");
		}
	} else { // if (slicesByStack == 1)
		for (i=1; i<=nbROI; i++){
			tempROIArray = Array.slice(meanROI, i-1, i);
			setResult("mean"+i, 0, tempROIArray[0]);
		}
		for (i=1; i<=nbROI; i++){
			tempROIArray = Array.slice(stdDevROI_Norm, i-1, i*slicesByStack);
			setResult("stdDev"+i, 0, tempROIArray[0]);
		}
		setResult("Min", 0, q0ROIs[0]);
		setResult("1st quartile", 0, q1ROIs[0]);
		setResult("Median", 0, q2ROIs[0]);
		setResult("3rd quartile", 0, q3ROIs[0]);
		setResult("Max", 0, q4ROIs[0]);
		setResult("SD Min", 0, q0ROIsSD[0]);
		setResult("SD 1st quartile", 0, q1ROIsSD[0]);
		setResult("SD Median", 0, q2ROIsSD[0]);
		setResult("SD 3rd quartile", 0, q3ROIsSD[0]);
		setResult("SD Max", 0, q4ROIsSD[0]);
	}

	// **************************************************
	// 3D Plot (vs Intensity (Ratio)) Part 2/2 
	// **************************************************
	if (!matches(plot3D, "No")) {
		for (i = 0; i < nbROI; i++) {
			setResult("Intensity_"+(i+1), 0, intensityMeasures[i]);
		}
		if (vsRatio) {
			for (i = 0; i < nbROI; i++) {
				intensityMeasures[i] /= intensityMeasures2[i];
				setResult("Intensity2_"+(i+1), 0, intensityMeasures2[i]);
			}
		}
		if (nbSlicesMax == 1) {
			if (vsRatio) {
				Plot.create("Ratio vs Intensity ratio", "Intensity ratio", "Ratio");
			} else {
				Plot.create("Ratio vs Intensity", "Intensity", "Ratio");
			}
			Plot.setColor("red");
			RatioValues = newArray(nbROI);
			for (i = 0; i < nbROI; i++) {
				RatioValues[i] = getResult("mean"+(i+1));
			}
			Plot.add("cross", intensityMeasures, RatioValues);
			Plot.show();
			Plot.setLimitsToFit();
			path3D = dataFolderPath+"RatiovsIntensity";
			saveAs("tiff", path3D);
		} else {
			setBatchMode(true);
			maxFluorescence = intensityMeasures[0];
			minFluorescence = maxFluorescence;
			for (i = 1; i < nbROI; i++) {
				if (maxFluorescence < intensityMeasures[i]) {
					maxFluorescence = intensityMeasures[i];
				} else if (minFluorescence > intensityMeasures[i]) {
					minFluorescence = intensityMeasures[i];
				}
			}
			maxRatio = getResult("mean1",0);
			minRatio = maxRatio;
			newImage("test", "32-bit black", nbSlicesMax, 256, 1);
			selectWindow("test");
			
			i = 1;
			for (k = 1; k <= nbImages; k++) {
				for (j = 0; j < nbROIsArray[k]-nbROIsArray[k-1]; j++){
					tempFluo = round((intensityMeasures[i-1]-minFluorescence)/(maxFluorescence-minFluorescence)*255);
					for (n = 0; n < nbSlicesArray[k-1]; n++) {
						tempRes = getResult("mean"+i,n);
						setPixel(n, tempFluo, tempRes);
						if (tempRes < minRatio) {
							minRatio = tempRes;
						} else if (tempRes > maxRatio) {
							maxRatio = tempRes;
						}
					}
					i++;
				}
			}
			run("Duplicate...", "title=3D");
			setMinAndMax(minRatio, maxRatio);
			setBatchMode(false);
			run("3D Surface Plot","plotType=1 smooth=0 colorType=2 min=0 max=100 scale=1.1 scaleZ=1.1 grid=256");
			selectWindow("3D");
			path3D = dataFolderPath+"3D_"+minFluorescence+"_"+maxFluorescence;
			saveAs("tiff", path3D);
			//close();
		}
		
	}
	saveAs("Results", dataGraphPathCSV);
	saveAs("Results", dataGraphPathXLS);
	// Converts dots to commas in xls file
	dataXLS = File.openAsString(dataGraphPathXLS);
	dataXLS = replace(dataXLS, ".", ",");
	File.saveString(dataXLS, dataGraphPathXLS);
	showStatus("Ratio Analysis Operation finished.");
}

// **************************************************
// Close Opened Images
// **************************************************
function closeImages() {
	close("*");
	if (isOpen("ROI Manager")) {
		selectWindow("ROI Manager");
		run("Close");
	}
	if (isOpen("Results")) {
		selectWindow("Results");
		run("Close");
	}
	if (isOpen("Log")) {
		selectWindow("Log");
		run("Close");
	}
}

// **************************************************
// Get ROI Set Path of current image
// **************************************************
function getROIPath() {
	imageName = getInfo("image.filename");
	index = lastIndexOf(imageName, "CROP");
	index2 = lastIndexOf(imageName, "_");
	if ( index != -1 ) {
		roiPath = getDirectory("image")+"RoiSetCROP"+substring(imageName, index+4, index2)+".zip";
	} else {
		roiPath = getDirectory("image")+"RoiSet.zip";
	}
	return roiPath;
}

// **************************************************
// Get parent and file name
// **************************************************
function getParentAndFileName() {
	filePath = getInfo("image.directory");
	fileName = getInfo("image.filename");
	parentPath = File.getParent(filePath);
	parentFolderAndFileName = substring(filePath, lengthOf(parentPath)+1, lengthOf(filePath)-1)+" ____ "+fileName;
	return parentFolderAndFileName;
}
// Replacement in version 0.29 to save the whole path and use relative path allowing more depth difference between files.
function getSubPath(path, start, nbParts) {
	partsArray = split(path, "\\\/");
	if (nbParts < 0) { // If nbParts is negative, take the last -nbParts parts
		nbParts = -nbParts;
		start = partsArray.length-nbParts;
	}
	if (start < 0) {start = 0;}
	if (start >= partsArray.length) {start = partsArray.length-1;}
	if (nbParts == 0) {nbParts = partsArray.length-start;}
	if (nbParts > partsArray.length-start) {nbParts = partsArray.length-start;}
	res = partsArray[start];
	for (i = start+1; i < start+nbParts; i++) {
		res += File.separator+partsArray[i];
	}
	return res;
}
function getCommonStartPath(path1, path2) {
	path1Array = split(path1, "\\\/");
	path2Array = split(path2, "\\\/");
	searchSize = minOf(path1Array.length, path2Array.length);
	res=newArray(0, 0, 0);
	while (res[0] < searchSize) {
		if (path1Array[res[0]]==path2Array[res[0]]) res[0]++;
		else break;
	}
	res[1] = path1Array.length-res[0];
	res[2] = path2Array.length-res[0];
	return res;
}
function samePaths(path1, path2) {
	res = true;
	path1Array = split(path1, "\\\/");
	path2Array = split(path2, "\\\/");
	if (path1Array.length == path2Array.length) {
		for (i = 0; i < path1Array.length; i++) {
			if (!matches(path1Array[i], path2Array[i])) {
				res = false;
			}
		}
	} else { 
		res = false;
	}
	return res;
}

// **************************************************
// Get roi manager names
// **************************************************
function getRoiManagerNames() {
	roiManagerNames = newArray(roiManager("count")); // Array to store and recover ROI names
	if (roiManager("count")>0) {
		roiManager("List");
		selectWindow("Overlay Elements");
		lines = split(getInfo("window.contents"),"\n");
		run("Close");
		for (i = 1; i < lines.length; i++) {
			temp = split(lines[i], "\t");
			roiManagerNames[i-1] = temp[1];
		}
	}
	return roiManagerNames;
}

// **************************************************
// Set Image Location based on ID
// **************************************************
function setLocImage(nbImages) {
	setLocation(0.01*screenWidth*modulus(nbImages,33), 0.03*screenHeight*modulus(nbImages,18));
}
function modulus(a, b) {
	return a-floor(a/b)*b;
}

// **************************************************
// Get And Set Image Location and Size
// **************************************************
function setLoc() {
	getLocationAndSize(posX, posY, width, height);
	Dialog.create("Window location and size");
	Dialog.addNumber("x", posX);
	Dialog.addNumber("y", posY);
	Dialog.addNumber("width", width);
	Dialog.addNumber("height", height);
	Dialog.show();
	setLocation(Dialog.getNumber(), Dialog.getNumber(), Dialog.getNumber(), Dialog.getNumber());
}

// **************************************************
// Get area corresponding to the background
// **************************************************
function getBgArea() {
	getDimensions(width, height, channels, slices, frames);
	areaWidth = minOf(32, width);
	areaHeight = minOf(32, height);
	stepWidth = minOf(8, areaWidth);
	stepHeight = minOf(8, areaHeight);
	min = 1/0;
	x = 0;
	y = 0;
	if (slices > 1) {
		currentImage = getImageID;
		run("Z Project...", "projection=[Average Intensity]");
	}
	for (i = 0; i <= -floor((areaWidth-width)/stepWidth); i++) {
		for (j = 0; j <= -floor((areaHeight-height)/stepHeight); j++) {
			makeRectangle(i*stepWidth, j*stepHeight, areaWidth, areaHeight);
			run("Measure");
			if (getResult("Mean") < min) {
				min = getResult("Mean");
				x = i;
				y = j;
			}
		}
	}
	if (slices > 1) {
		close();
		selectImage(currentImage);
	}
	coord = newArray(4);
	coord[0] = x*stepWidth;
	coord[1] = y*stepHeight;
	coord[2] = areaWidth;
	coord[3] = areaHeight;
	return coord;
}


// **************************************************
// Get extension size from a file path
// **************************************************
function getExtensionSize(filePath) {
	lastName = File.getName(filePath);
	if (lastIndexOf(lastName, ".") == -1) {
		extensionSize = 0;
	} else {
		extensionSize = lengthOf(lastName)-lastIndexOf(lastName, ".");
	}
	return extensionSize;
}

// **************************************************
// Get all files containing "subString" in the first "depth"
// levels subfolders, from a selected folder
// **************************************************
function getFiles(subString, depth, folderPath) {
	resultList = newArray();
	if (File.exists(folderPath)) {
		path = folderPath;
	} else { // if folderPath is invalid (eg on purpose ""), ask the user to choose a directory
		path = chooseDirectory("Choose directory containing \""+subString+"\" images"); 
	}
	foldersList = newArray(1);
	foldersList[0] = path;
	for (k = 0; k < depth; k++) {
		folders = Array.copy(foldersList);
		foldersList = newArray();
		for (i = 0; i < folders.length; i++) {
			fileList = getFileList(folders[i]);
			for (j = 0; j < fileList.length; j++) {
				fileList[j] = folders[i] + fileList[j];
				if (File.isDirectory(fileList[j])) {
					foldersList = Array.concat(foldersList, fileList[j]);
				} else if (indexOf(File.getName(fileList[j]), subString)!=-1) {		// only files containing "subString"
					resultList = Array.concat(resultList, fileList[j]);
				}
			}
		}
	}
	return resultList;
}

// **************************************************
// Change LUT display range of all .tif containing "subString"
// in the first "depth" levels subfolders, from a selected folder
// **************************************************
function batchMinAndMax(subString, depth) {
	fileList2 = getFiles(subString, depth, "");
	fileList = newArray();
	for (i = 0; i < fileList2.length; i++) {
		if (endsWith(fileList2[i], ".tif")) {
			fileList = Array.concat(fileList, fileList2[i]);
		}
	}
	for (i = 0; i < fileList.length; i++) {
		open(fileList[i]);
		if (i == 0) {
			getMinAndMax(setRangeMin, setRangeMax);
			Dialog.create("Choose range");
			Dialog.addNumber("Min:", setRangeMin);
			Dialog.addNumber("Max:", setRangeMax);
			Dialog.show();
			setRangeMin = Dialog.getNumber();
			setRangeMax = Dialog.getNumber();
			setBatchMode(true);
		}
		setMinAndMax(setRangeMin,setRangeMax);
		saveAs("tiff", File.directory+File.nameWithoutExtension);
		close();
	}
	setBatchMode(false);
}



// **************************************************
// Functions to save and load area of 3D plot (vs Intensity (Ratio))
// **************************************************
function saveSelectionAsPoints(path) {
	getSelectionCoordinates(xpoints, ypoints);
	xString = ""+xpoints[0];
	yString = ""+ypoints[0];
	for (i = 1; i < xpoints.length; i++) {
		xString += ";"+xpoints[i];
		yString += ";"+ypoints[i];
	}
	s = getSliceNumber();
	fileID = File.open(path);
	print(fileID, s);
	print(fileID, xString);
	print(fileID, yString);
	File.close(fileID);
}
function loadSelectionAsPoints(path) {
	fileStr = File.openAsString(path);
	lines = split(fileStr, "\n");
	sliceNumber = parseInt(lines[0]);
	if (sliceNumber < 1 || sliceNumber > nSlices) {
		sliceNumber = 1;
	}
	setSlice(sliceNumber);
	xpoints = split(lines[1], ";");
	ypoints = split(lines[2], ";");
	makeSelection("polygon",xpoints, ypoints);
}

// **************************************************
// Build weighted image 
// **************************************************
function buildWeightedImage() {
	imageID = getImageID();
	imagePath = getInfo("image.directory")+getInfo("image.filename");
	indice = lastIndexOf(imagePath, "Ratio");
	if (indice > -1) {
		weightPath = substring(imagePath, 0, indice)+donorName+"_clean"+substring(imagePath, indice+5, lengthOf(imagePath));
	} else {
		weightPath = "_";
	}
	if (!File.exists(weightPath)) {
		weightPath = chooseFile("Select weight image");
	}
	open(weightPath);
	setLocation(0.6*screenWidth, 0.15*screenHeight);
	rename("Weight");
	title = "Contrast";
	message = "Adjust contrast on weight image then click OK.";
	waitForUser(title, message);
	setBatchMode(true);
	selectImage(imageID);
	run("Select None");
	run("Duplicate...", "title=O duplicate");
	run("RGB Color");
	run("RGB Stack");
	if (nSlices==1) {
		run("Stack to Images");
		selectWindow("Red");
		rename("C1-O");
		selectWindow("Green");
		rename("C2-O");
		selectWindow("Blue");
		rename("C3-O");
	} else {
		run("Split Channels");
	}
	selectWindow("Weight");
	run("8-bit"); // rescale to [0, 255] values
	run("32-bit");
	run("Macro...", "code=[v = v / 255] stack"); // rescale to [0, 1] values
	for (i = 1; i <= 3; i++) {
		selectWindow("C"+i+"-O");
		run("32-bit");
		imageCalculator("Multiply stack", "C"+i+"-O","Weight");
	}
	selectWindow("Weight");
	close();
	run("Merge Channels...", "c1=C1-O c2=C2-O c3=C3-O create");
	run("RGB Color", "slices");
	rename("Weighted");
	setBatchMode(false);
	setLocation(0.6*screenWidth, 0.15*screenHeight);
}

// **************************************************
// Redefine getFile and getDirectory to behave differently on Mac OS X to prevent bugs in recent versions.
// Mac OS X.11 : no titles for the windows of File.openDialog and getDirectory
// Mac OS X.12 : getDirectory force to choose a file and append a slash to it...
// **************************************************
function chooseDirectory(title) {
	if (lateMacOSX) {
		setOption("JFileChooser", true);
		dirPath = getDirectory(title);
		setOption("JFileChooser", false);
		if (matches(dirPath, "")) {exit;}
	} else {
		dirPath = getDirectory(title);
	}
	return dirPath;
}
function chooseFile(title) {
	if (lateMacOSX) {
		setOption("JFileChooser", true);
		filePath = File.openDialog(title);
		setOption("JFileChooser", false);
		if (matches(filePath, "")) {exit;}
	} else {
		filePath = File.openDialog(title);
	}
	return filePath;
}

// **************************************************
// Set default parameters
// **************************************************
function setParameters() {
	Dialog.create("Parameters");
	
	Dialog.addString("Donor", donorName);
	Dialog.addString("Acceptor", acceptorName);
	
	Dialog.setInsets(20, 20, 0);
	Dialog.addMessage("Clean parameters:");
	Dialog.setInsets(0, 20, 0);
	Dialog.addCheckbox("Batch clean? (see Help)", batchClean);
	Dialog.addCheckbox("Subtract background image?", subtractBackgroundImage);
	Dialog.addCheckbox("Align stacks?", alignStacks);
	
	Dialog.setInsets(20, 20, 0);
	Dialog.addMessage("Crop parameters:");
	Dialog.addCheckbox("Batch crop? (see Help)", batchCrop);
	Dialog.addCheckbox("Give a label to CROPs? (see Help)", nameCROPs);
	
	Dialog.setInsets(20, 20, 0);
	Dialog.addMessage("Divide parameters:");
	Dialog.setInsets(0, 0, 3);
	Dialog.addChoice("Selection? (see Help)", newArray("Image: Single", "Image: Multi if CROP",
					"Folder: CROPs only", "Folder: All but CROPs", "Folder: All"), divideSelection);
	Dialog.addCheckbox("Without confirmation? (see Help)", batchDivide);
	Dialog.setInsets(0, 0, 3);
	Dialog.addChoice("Threshold method", newArray("Median", "Mean * Coefficient", "AutoTh - Otsu", "AutoTh - Chastagnier", "AutoLocalTh - Phansalkar", 
					"AutoLocalTh - MidGrey", "AutoLocalTh - Niblack"), thresholdMethod);
	Dialog.setInsets(0, 0, 3);
	Dialog.addNumber("Coefficient", coefMultMeanROI);
	Dialog.addNumber("AutoLocalTh radius", radiusLocalTh);
	Dialog.addNumber("Minimum threshold", overallMinThreshold);
	Dialog.addNumber("Min range", rangeMin);
	Dialog.addNumber("Max range", rangeMax);
	
	Dialog.setInsets(20, 20, 0);
	Dialog.addMessage("Analyse parameters:");
	Dialog.addCheckbox("Display weighted images?", weightImage);
	Dialog.addNumber("Time between images (s)", time_between_images_sec);
	Dialog.addNumber("Slice used to normalize", normalizeSlice);
	Dialog.addChoice("Plot Ratio vs intensity?", newArray("No", "Vs intensity", "Vs intensity ratio"), plot3D);
	Dialog.addString("Folder and data name", dataFolderName, 18);
	
	Dialog.addHelp("http://htmlpreview.github.com/?https://github.com/ychastagnier/LR-Analyzer/blob/master/help/param.html");
	
	Dialog.show();
	donorName = Dialog.getString();
	call("ij.Prefs.set", "LRA.donorName", donorName);
	acceptorName = Dialog.getString();
	call("ij.Prefs.set", "LRA.acceptorName", acceptorName);
	batchClean = Dialog.getCheckbox();
	call("ij.Prefs.set", "LRA.batchClean", batchClean);
	subtractBackgroundImage = Dialog.getCheckbox();
	call("ij.Prefs.set", "LRA.subtractBackgroundImage", subtractBackgroundImage);
	alignStacks = Dialog.getCheckbox();
	call("ij.Prefs.set", "LRA.alignStacks", alignStacks);
	batchCrop = Dialog.getCheckbox();
	call("ij.Prefs.set", "LRA.batchCrop", batchCrop);
	nameCROPs = Dialog.getCheckbox();
	call("ij.Prefs.set", "LRA.nameCROPs", nameCROPs);
	divideSelection = Dialog.getChoice();
	call("ij.Prefs.set", "LRA.divideSelection", divideSelection);
	batchDivide = Dialog.getCheckbox();
	call("ij.Prefs.set", "LRA.batchDivide", batchDivide);
	thresholdMethod = Dialog.getChoice();
	call("ij.Prefs.set", "LRA.thresholdMethod", thresholdMethod);
	coefMultMeanROI = Dialog.getNumber();
	call("ij.Prefs.set", "LRA.coefMultMeanROI", coefMultMeanROI);
	radiusLocalTh = Dialog.getNumber();
	call("ij.Prefs.set", "LRA.radiusLocalTh", radiusLocalTh);
	overallMinThreshold = Dialog.getNumber();
	call("ij.Prefs.set", "LRA.overallMinThreshold", overallMinThreshold);
	rangeMin = Dialog.getNumber();
	call("ij.Prefs.set", "LRA.rangeMin", rangeMin);
	rangeMax = Dialog.getNumber();
	call("ij.Prefs.set", "LRA.rangeMax", rangeMax);
	weightImage = Dialog.getCheckbox();
	call("ij.Prefs.set", "LRA.weightImage", weightImage);
	time_between_images_sec = Dialog.getNumber();
	call("ij.Prefs.set", "LRA.time_between_images_sec", time_between_images_sec);
	normalizeSlice = Dialog.getNumber();
	call("ij.Prefs.set", "LRA.normalizeSlice", normalizeSlice);
	plot3D = Dialog.getChoice();
	call("ij.Prefs.set", "LRA.plot3D", plot3D);
	dataFolderName = Dialog.getString();
	call("ij.Prefs.set", "LRA.dataFolderName", dataFolderName);
	
}

