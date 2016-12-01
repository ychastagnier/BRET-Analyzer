// Luminescence Ratio Analyzer version 0.27 (2016-12-01)
// by Yan Chastagnier

// Put this macro into the folder Fiji.app/macros/toolsets/
// Select it with the >> symbol at the extrem right of the toolbar.
// Use the Action Tools to run the different parts of the process.

// Global parameters default values : change them to alter permanently default behaviour on toolset startup

var donorName = "LUC"; // Donor
var acceptorName = "YFP"; // Acceptor
var batchClean = false; // Batch clean?
var alignStacks = true; // Align stacks?
var batchCrop = false; // Batch crop?
var nameCROPs = true; // Give a label to CROPs?
var divideSelection = "Image: Multi if CROP";
var batchDivide = false; // Batch divide?
var thresholdMethod = "AutoTh - Chastagnier";
var coefMultMeanROI = 1; // Coefficient
var radiusLocalTh = 10; // AutoLocalTh radius
var overallMinThreshold = 0; // Minimum threshold
var rangeMin = 0.2; // Min range
var rangeMax = 2; // Max range
var time_between_images_sec = 30; // Time between images (s)
var normalizeSlice = 5; // Slice used to normalize
var saveROIs = true; // Save ROIs?
var plot3D = "No"; // Plot Ratio vs intensity?
var dataFolderName = "data"; // Folder and data name

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


// **************************************************
// Clean donor and acceptor images
// **************************************************
function cleanImages() {
	if (batchClean) {
		imageList2 = getTIF(donorName, 1);
		imageList = newArray();
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
	} else {
		// Dialogue window to choose image
		imageList = newArray(1);
		imageList[0] = File.openDialog("Select raw "+donorName+" image");
	}
	for (j = 0; j < imageList.length; j++) {
		if (batchClean) {
			setBatchMode(true);
			print("Cleaning image "+(j+1)+" / "+imageList.length);
		}
		donor = imageList[j];
		// Create sub folder if needed
		index = lastIndexOf(donor, donorName);
		if (index == -1) {
			folderPath = substring(donor, 0, lengthOf(donor)-4);
		} else {
			folderPath = substring(donor, 0, index)+substring(donor, index+lengthOf(donorName), lengthOf(donor)-4);
		}
		if (!File.exists(folderPath)) {
			File.makeDirectory(folderPath);
		}
		
		// Open and place images
		open(donor);
		run("Enhance Contrast", "saturated=0.35");
		setLocation(110, 110);
		rename(donorName);
		
		if (index != -1) {
			acceptor = substring(donor, 0, index)+acceptorName+substring(donor, index+lengthOf(donorName), lengthOf(donor));
		} else {
			acceptor = "";
		}
		if (index == -1 || !File.exists(acceptor)) {
			// If acceptor image is not automatically found, ask user to choose it
			acceptor = File.openDialog("Select raw "+acceptorName+" image");
		}
		open(acceptor);
		run("Enhance Contrast", "saturated=0.35");
		setLocation(1010, 110);
		rename(acceptorName);

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
			Dialog.addCheckbox("Align images?", true);
			Dialog.addHelp("http://htmlpreview.github.com/?https://github.com/ychastagnier/LR-Analyzer/blob/master/help/align.html");
			Dialog.show();
			alignStacks = Dialog.getCheckbox();
		}
		
		setBatchMode(true);
		
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
			run("Select None");
			run("Subtract...", "value=" + backgroundAcceptor + " slice"); // Remove background
		}
		
		// Align slices using TurboReg plugin to compute translation coordinates
		if (alignStacks && nSlices != 1) {
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
		setLocation(1010, 110);
		setSlice(1);
		run("Enhance Contrast", "saturated=0.35");
		saveAs("tiff", folderPath + File.separator + substring(File.getName(acceptor), 0, lengthOf(File.getName(acceptor))-4)+"_clean");
		if (batchClean) {
			close();
		} else {
			rename(acceptorName+"_clean");
		}
		selectWindow(donorName);
		setLocation(110, 110);
		setSlice(1);
		run("Enhance Contrast", "saturated=0.35");
		saveAs("tiff", folderPath + File.separator + substring(File.getName(donor), 0, lengthOf(File.getName(donor))-4)+"_clean");
		if (batchClean) {
			close();
		} else {
			rename(donorName+"_clean");
		}
	}
	if (batchClean) {
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
			donor = File.openDialog("Select "+donorName+" image");
			imageList = Array.concat(imageList, donor);
		} else {
			imageList2 = getTIF("_clean", 2);
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
		//setLocation(110, 110);
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
				acceptor = File.openDialog("Select clean acceptor image");
			}
			if (alreadyOpen) {
				open(acceptor);
				rename(acceptorName+"_clean");
				setLocation(1010, 110);
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
			setLocation(110, 110);
			run("Enhance Contrast", "saturated=0.35");
			acceptor = imageList[2*nbImages+1];
			open(acceptor);
			rename(acceptorName+"_clean");
			setLocation(1010, 110);
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
			donor = File.openDialog("Select clean "+donorName+" image");
			imageList = Array.concat(imageList, donor);
		} else if (matches(divideSelection, "Image: Multi if CROP")) { // Case select image, process all CROPs if one is selected, else single image
			donor = File.openDialog("Select clean "+donorName+" image");
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
			imageList2 = getTIF("_clean", 2);
			nbCROPs = 0;
			for (i = 0; i < imageList2.length - nbCROPs; i++) {
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
				index = indexOf(imageList2[i], donorName);
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
				acceptor = File.openDialog("Select clean acceptor image");
			}
			if (alreadyOpen) {
				open(acceptor);
				rename(acceptorName+"_clean");
				setLocation(1010, 110);
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
			setLocation(110, 110);
			run("Enhance Contrast", "saturated=0.35");
			acceptor = imageList[2*i+1];
			open(acceptor);
			rename(acceptorName+"_clean");
			setLocation(1010, 110);
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
				setLocation(110, 310);
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
					//run("Median...", "radius=2 stack");
					run("Auto Threshold", "method=Li white stack");
					selectWindow("donor_test2");
					//run("Median...", "radius=2 stack");
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
				setLocation(1010, 310);
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
				setLocation(110, 310);
				run("8-bit");
				run("Auto Local Threshold", "method="+substring(thresholdMethod, 14, lengthOf(thresholdMethod))+" radius="+radiusLocalTh+" parameter_1=0 parameter_2=0 white stack");
				run("Duplicate...", "title="+donorName+"_Mask duplicate");
				setLocation(1010, 310);
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
				setLocation(110, 310);
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
				coefMultMeanROI = Dialog.getNumber();
				radiusLocalTh = Dialog.getNumber();
				overallMinThreshold = Dialog.getNumber();
				updateThreshold = Dialog.getCheckbox();
			} else {
				updateThreshold = false;
			}
		}
		
		close(donorName+"_clean");
		selectWindow(donorName+"_test");
		rename(donorName+"_clean");
		setLocation(110, 110);
		
		run("Misc...", "divide=0.0");
		
		imageCalculator("Divide create 32-bit stack", acceptorName+"_clean", donorName+"_clean");
		selectWindow(donorName+"_clean");
		close();
		selectWindow(acceptorName+"_clean");
		close();
		selectWindow("Result of "+acceptorName+"_clean");
		rename("Ratio");
		setLocation(110, 110);
		call("ij.ImagePlus.setDefault16bitRange", 16);
		
		// Create a duplicate of the Ratio image with computed color range
		run("Duplicate...", "title=Ratio_AutoRange duplicate");
		setLocation(1010, 110);
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
				setLocation(670,350);
				selectWindow("Ratio");
				run("Histogram", "bins=256 x_min="+minStack+" x_max="+maxStack+" y_max=Auto stack");
				rename("Stack Histogram of Ratio");
				setLocation(670,680);
				
				title = "Check";
				msg = "Check values ["+rangeMin+", "+rangeMax+"] then click \"OK\".\nAuto Range : ["+minStack+", "+maxStack+"]";
				waitForUser(title, msg);
				
				Dialog.create("Choose range");
				Dialog.addNumber("Min:", rangeMin);
				Dialog.addNumber("Max:", rangeMax);
				Dialog.addCheckbox("Update Min and Max?", true);
				Dialog.show();
				rangeMin = Dialog.getNumber();
				rangeMax = Dialog.getNumber();
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
		saveAs("tiff", substring(donor, 0, index)+"Ratio"+substring(donor, index+lengthOf(donorName), lengthOf(donor)-10));
		close();
	}
	
	if (isOpen("Results")) {
		selectWindow("Results");
		run("Close");
	}
	
	if (batchDivide) {
		setBatchMode(false);
	}
	
	showStatus("Divide Operation finished.");
}


// **************************************************
// Ratio Analysis
// **************************************************
function makeRatioAnalysis() {
	imagesParentAndFileNames = newArray();
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
			setLocation(20*nbImages, 20+20*nbImages);
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
		parentAndFileName = getParentAndFileName();
		imagesParentAndFileNames = Array.concat(imagesParentAndFileNames, parentAndFileName);
		if (nbImages == 1) {
			folderPath = getDirectory("image");
			slicesByStack = nSlices;
		}
		nbROIsArray[nbImages] = roiNb+nbROIsArray[nbImages-1];
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
		imageRatio = File.openDialog("Select Ratio image "+(nbImages+1));
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
					cancel = true;
				}
			}
			if (!cancel) {
				nbImages++;
				open(imageRatio);
				rename("Ratio"+IJ.pad(nbImages,2));
				parentAndFileName = getParentAndFileName();
				imageAlreadyOpen = -1;
				for (i = 0; i < imagesParentAndFileNames.length; i++) {
					if (matches(parentAndFileName, imagesParentAndFileNames[i])) {
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
						title = "ROIs selection";
						msg = "Image already open.\nAdd your regions (Ctrl+T) to the ROI manager on image Ratio"+IJ.pad(imageAlreadyOpen,2)+", then click \"OK\".";
						waitForUser(title, msg);
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
					setLocation(20*nbImages, 20+20*nbImages);
					roisPath = getROIPath();
					if (File.exists(roisPath)) {
						i = roiManager("count");
						roiManager("Open", roisPath);
						i = roiManager("count") - i;
						msg = ""+i+" ROI(s) have been loaded in the manager for image Ratio"+IJ.pad(nbImages,2)+".\n";
					} else {
						msg = "";
					}
					slicesByStack = nSlices;
					
					if (!usetxt) {
						title = "ROIs selection";
						msg = msg+"Add your regions (Ctrl+T) to the ROI manager on image Ratio"+IJ.pad(nbImages,2)+", then click \"OK\".";
						waitForUser(title, msg);
					}
					
					if (lengthOf(nbROIsArray) > nbImages) {
						nbROIsArray[nbImages] = roiManager("count");
					} else {
						nbROIsArray = Array.concat(nbROIsArray, roiManager("count"));
					}
					if (nbROIsArray[nbImages]-nbROIsArray[nbImages-1]==0) {
						close();
						nbImages--;
						showMessage("Image closed", "The image was closed because no regions were selected on it.");
					} else {
						imagesParentAndFileNames = Array.concat(imagesParentAndFileNames, parentAndFileName);
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
	
	Dialog.create("Parameters");
	Dialog.addNumber("Time between images (s)", time_between_images_sec);
	Dialog.addNumber("Slice to use for normalization", normalizeSlice);
	Dialog.addCheckbox("Save ROIs?", saveROIs);
	Dialog.addChoice("Plot Ratio vs intensity?", newArray("No", "Vs intensity", "Vs intensity ratio"), plot3D);
	Dialog.addString("Folder and Data Name", dataFolderName, 18);
	Dialog.addHelp("http://htmlpreview.github.com/?https://github.com/ychastagnier/LR-Analyzer/blob/master/help/analyse.html");
	Dialog.show();
	time_between_images_sec = Dialog.getNumber();
	normalizeSlice = Dialog.getNumber();
	saveROIs = Dialog.getCheckbox();
	plot3D = Dialog.getChoice();
	dataFolderName = Dialog.getString();
	
	if (matches(dataFolderName, "")) {
		dataFolderName = "data";
	}
	
	f = File.open(folderPath+dataFolderName+".txt");
	for (i = 0; i < imagesParentAndFileNames.length; i++) {
		duplicate = false;
		for (j = 0; j < i; j++) {
			if (matches(imagesParentAndFileNames[i], imagesParentAndFileNames[j])) {
				duplicate = true;
			}
		}
		if (!duplicate) {
			print(f, imagesParentAndFileNames[i]);
		}
	}
	File.close(f);
	
	nbROI = roiManager("count");	
	// **************************************************
	// 3D Plot Part 1/2 (measure)
	// **************************************************
	if (!matches(plot3D, "No")) {
		run("Clear Results");
		intensityMeasures = newArray(nbROI);
		vsRatio = endsWith(plot3D, "ratio");
		if (vsRatio) {
			intensityMeasures2 = newArray(nbROI);
		}
		for (i = 1; i <= nbImages; i++) {
			selectWindow("Ratio"+IJ.pad(i,2));
			for (j = nbROIsArray[i-1]; j < nbROIsArray[i]; j++) {
				if (j == nbROIsArray[i-1]) {
					open(File.openDialog("Select intensity image 1 corresponding to Ratio"+IJ.pad(i,2)));
					rename("Intensity 1 of Ratio"+IJ.pad(i,2)+"_"+IJ.pad(j+1,2));
					setLocation(800, 100);
				} else {
					selectWindow("Intensity 1 of Ratio"+IJ.pad(i,2)+"_"+IJ.pad(j+1,2));
				}
				roiManager("select", j);
				roiManager("Deselect");
				// User prompt to select fluorescent area
				title = "Area selection";
				msg = "Please select intensity area, then click \"OK\".";
				waitForUser(title, msg);
				if (isOpen("Intensity 1 of Ratio"+IJ.pad(i,2)+"_"+IJ.pad(j+1,2))) {
					selectWindow("Intensity 1 of Ratio"+IJ.pad(i,2)+"_"+IJ.pad(j+1,2));
				}
				run("Measure");
				run("Select None");
				intensityMeasures[j] = round(getResult("Mean"));
				if (j == nbROIsArray[i]-1) {
					close();
				} else {
					rename("Intensity 1 of Ratio"+IJ.pad(i,2)+"_"+IJ.pad(j+2,2));
				}
				if (vsRatio) {
					if (j == nbROIsArray[i-1]) {
						open(File.openDialog("Select intensity image 2 corresponding to Ratio"+IJ.pad(i,2)));
						rename("Intensity 2 of Ratio"+IJ.pad(i,2)+"_"+IJ.pad(j+1,2));
						setLocation(900, 200);
					} else {
						selectWindow("Intensity 2 of Ratio"+IJ.pad(i,2)+"_"+IJ.pad(j+1,2));
					}
					roiManager("select", j);
					roiManager("Deselect");
					waitForUser(title, msg);
					if (isOpen("Intensity 2 of Ratio"+IJ.pad(i,2)+"_"+IJ.pad(j+1,2))) {
						selectWindow("Intensity 2 of Ratio"+IJ.pad(i,2)+"_"+IJ.pad(j+1,2));
					}
					run("Measure");
					run("Select None");
					intensityMeasures2[j] = round(getResult("Mean"));
					if (j == nbROIsArray[i]-1) {
						close();
					} else {
						rename("Intensity 2 of Ratio"+IJ.pad(i,2)+"_"+IJ.pad(j+2,2));
					}
				}
			}
		}
	}
	
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
	if (normalizeSlice > slicesByStack || normalizeSlice < 1) {
		normalizeSlice = 1;
	}
	fullIndex = Array.getSequence(nbROI+1);
	if (saveROIs) {
		for (k = 1; k <= nbImages; k++) {
			selectWindow("Ratio"+IJ.pad(k,2));
			roiPath = getROIPath();
			indexes = Array.slice(fullIndex, nbROIsArray[k-1], nbROIsArray[k]);
			roiManager("select", indexes)
			roiManager("Save Selected", roiPath);
		}
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
	meanROI = newArray(slicesByStack*nbROI);
	stdDevROI = newArray(slicesByStack*nbROI);
	
	run("Set Measurements...", "mean standard min limit redirect=None decimal=3");
	run("Clear Results");
	// Measure mean and standard deviation
	i = 0;
	for (k = 1; k <= nbImages; k++) {
		selectWindow("Ratio"+IJ.pad(k,2));
		setThreshold(0.01, 65535, "no color");
		for (j = nbROIsArray[k-1]; j < nbROIsArray[k]; j++){
			roiManager("Select", j);
			for (n=1; n<=slicesByStack; n++) {
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
	timeArray = newArray(slicesByStack);
	colors = newArray("black", "blue","green","magenta","orange","red","yellow","gray","cyan","pink");
	
	for (n=0; n<slicesByStack; n++) {
		timeArray[n] = n * time_between_images;
		setResult("t(min)", n, n * time_between_images);
	}
	timeArrayReverse = Array.reverse(Array.copy(timeArray));

	// Normalization of means and standard deviations
	meanROI_Norm = Array.copy(meanROI);
	stdDevROI_Norm = Array.copy(stdDevROI);
	for (j=0; j<nbROI; j++) {
		tempNorm = meanROI_Norm[j*slicesByStack+normalizeSlice-1];
		if (tempNorm == 0) {tempNorm = 1;}
		for (n=0; n<slicesByStack; n++) {	
			meanROI_Norm[j*slicesByStack+n] = meanROI_Norm[j*slicesByStack+n]/tempNorm;
			stdDevROI_Norm[j*slicesByStack+n] = stdDevROI_Norm[j*slicesByStack+n]/tempNorm;
		}
	}
	
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
	
	if (slicesByStack != 1) {
		
		// Mean values normalized
		for (i=1; i<=nbROI; i++){
			tempROIArray = Array.slice(meanROI_Norm,(i-1)*slicesByStack,(i*slicesByStack));
			for (n=0; n < slicesByStack; n++) {
				setResult("mean"+i, n, tempROIArray[n]);
			}
		}
	
		// Standard deviation normalized
		for (i=1; i<=nbROI; i++){
			tempROIArray = Array.slice(stdDevROI_Norm,(i-1)*slicesByStack,(i*slicesByStack));
			for (n=0; n < slicesByStack; n++) {
				setResult("stdDev"+i, n, tempROIArray[n]);
			}
		}
		
		// Save normalized results
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
		saveAs("Results", dataNormGraphPathCSV);
		saveAs("Results", dataNormGraphPathXLS);
		// Converts dots to commas in xls file
		dataNormXLS = File.openAsString(dataNormGraphPathXLS);
		dataNormXLS = replace(dataNormXLS, ".", ",");
		File.saveString(dataNormXLS, dataNormGraphPathXLS)
		
		
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
		setLocation(1360, 130);
		
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
		setLocation(1360, 480);
	
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
		
		
		// Graph mean values
		Plot.create("Means", "Time (min)", "Mean");
		graphLegend = "";
		for (i=1; i<=nbROI; i++){
			tempROIArray = Array.slice(meanROI,(i-1)*slicesByStack,(i*slicesByStack));
			Plot.setColor(colors[(i-1)%10]);
			Plot.add("line", timeArray, tempROIArray);
			graphLegend = graphLegend + "ROI "+i+"\t";
			for (n=0; n < slicesByStack; n++) {
				setResult("mean"+i, n, tempROIArray[n]);
			}
		}
		Plot.setLegend(graphLegend);
		Plot.show();
		Plot.setLimitsToFit();
		setLocation(810, 130);
		
		// Graph standard deviation
		Plot.create("Standard deviations", "Time (min)", "Standard deviation");
		for (i=1; i<=nbROI; i++){
			tempROIArray = Array.slice(stdDevROI,(i-1)*slicesByStack,(i*slicesByStack));
			Plot.setColor(colors[(i-1)%10]);
			Plot.add("line", timeArray, tempROIArray);
			for (n=0; n < slicesByStack; n++) {
				setResult("stdDev"+i, n, tempROIArray[n]);
			}
		}
		Plot.setLegend(graphLegend);
		Plot.show();
		Plot.setLimitsToFit();
		setLocation(810, 480);
		
		// Save results
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
		
		if (isOpen("Plot Values")) {
			selectWindow("Plot Values");
			run("Close");
		}
	} else { // if (slicesByStack == 1)
		for (i=1; i<=nbROI; i++){
			tempROIArray = Array.slice(meanROI,(i-1)*slicesByStack,(i*slicesByStack));
			setResult("mean"+i, 0, tempROIArray[0]);
		}
		for (i=1; i<=nbROI; i++){
			tempROIArray = Array.slice(stdDevROI_Norm,(i-1)*slicesByStack,(i*slicesByStack));
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
	// 3D Plot Part 2/2
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
		if (slicesByStack == 1) {
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
			newImage("test", "32-bit black", slicesByStack, 256, 1);
			selectWindow("test");
			for (i = 1; i <= nbROI; i++) {
				tempFluo = round((intensityMeasures[i-1]-minFluorescence)/(maxFluorescence-minFluorescence)*255);
				for (j = 0; j < slicesByStack; j++) {
					tempRes = getResult("mean"+i,j);
					setPixel(j, tempFluo, tempRes);
					if (tempRes < minRatio) {
						minRatio = tempRes;
					} else if (tempRes > maxRatio) {
						maxRatio = tempRes;
					}
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
// Get all .tif containing "subString" in the first "depth"
// levels subfolders, from a selected folder
// **************************************************
function getTIF(subString, depth) {
	resultList = newArray();
	folder = getDirectory("Choose directory containing \""+subString+"\" images");
	foldersList = newArray(1);
	foldersList[0] = folder;
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
					if (endsWith(fileList[j], ".tif")) {							// only .tif images
						resultList = Array.concat(resultList, fileList[j]);
					}
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
	fileList2 = getTIF(subString, depth);
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
	Dialog.addNumber("Time between images (s)", time_between_images_sec);
	Dialog.addNumber("Slice used to normalize", normalizeSlice);
	Dialog.addCheckbox("Save ROIs?", saveROIs);
	Dialog.addChoice("Plot Ratio vs intensity?", newArray("No", "Vs intensity", "Vs intensity ratio"), plot3D);
	Dialog.addString("Folder and data name", dataFolderName, 18);
	
	Dialog.addHelp("http://htmlpreview.github.com/?https://github.com/ychastagnier/LR-Analyzer/blob/master/help/param.html");
	
	Dialog.show();
	donorName = Dialog.getString();
	acceptorName = Dialog.getString();
	batchClean = Dialog.getCheckbox();
	alignStacks = Dialog.getCheckbox();
	batchCrop = Dialog.getCheckbox();
	nameCROPs = Dialog.getCheckbox();
	divideSelection = Dialog.getChoice();
	batchDivide = Dialog.getCheckbox();
	thresholdMethod = Dialog.getChoice();
	coefMultMeanROI = Dialog.getNumber();
	radiusLocalTh = Dialog.getNumber();
	overallMinThreshold = Dialog.getNumber();
	rangeMin = Dialog.getNumber();
	rangeMax = Dialog.getNumber();
	time_between_images_sec = Dialog.getNumber();
	normalizeSlice = Dialog.getNumber();
	saveROIs = Dialog.getCheckbox();
	plot3D = Dialog.getChoice();
	dataFolderName = Dialog.getString();
}

