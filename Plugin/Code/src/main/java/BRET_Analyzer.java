import ij.IJ;
import ij.ImageJ;
import ij.WindowManager;
import ij.ImagePlus;
import ij.ImageStack;
import ij.gui.DialogListener;
import ij.gui.GenericDialog;
import ij.gui.ImageWindow;
import ij.gui.NonBlockingGenericDialog;
import ij.gui.Overlay;
import ij.gui.Plot;
import ij.gui.PolygonRoi;
import ij.gui.Roi;
import ij.gui.WaitForUserDialog;
import ij.io.DirectoryChooser;
import ij.io.OpenDialog;
import ij.io.FileSaver;
import ij.measure.ResultsTable;
import ij.Prefs;
import ij.process.ByteProcessor;
import ij.process.ColorProcessor;
import ij.process.FloatPolygon;
import ij.process.ImageStatistics;
import ij.process.LUT;
import ij.process.StackStatistics;
import ij.process.ImageProcessor;

import java.awt.AWTEvent;
import java.awt.Button;
import java.awt.Choice;
import java.awt.Color;
import java.awt.Component;
import java.awt.Container;
import java.awt.Dimension;
import java.awt.Font;
import java.awt.Frame;
import java.awt.GridBagConstraints;
import java.awt.GridBagLayout;
import java.awt.GridLayout;
import java.awt.Label;
import java.awt.List;
import java.awt.Panel;
import java.awt.Rectangle;
import java.awt.Scrollbar;
import java.awt.TextField;
import java.awt.Toolkit;
import java.awt.Window;
import java.awt.event.ActionEvent;
import java.awt.event.ActionListener;
import java.awt.event.AdjustmentEvent;
import java.awt.event.AdjustmentListener;
import java.awt.event.ItemEvent;
import java.awt.event.ItemListener;
import java.awt.event.TextEvent;
import java.awt.event.TextListener;
import java.awt.event.WindowEvent;
import java.awt.event.WindowListener;
import java.util.Arrays;
import java.util.LinkedList;
import java.util.ListIterator;
import java.io.File;
import java.io.FileNotFoundException;
import java.io.IOException;
import java.io.PrintWriter;
import java.io.UnsupportedEncodingException;

import javax.swing.BorderFactory;
import javax.swing.DefaultListCellRenderer;
import javax.swing.DefaultListModel;
import javax.swing.JButton;
import javax.swing.JLabel;
import javax.swing.JList;
import javax.swing.ListSelectionModel;
import javax.swing.ToolTipManager;

import ij.plugin.PlugIn;
import ij.plugin.ZProjector;
import ij.plugin.frame.RoiManager;
import ij.plugin.ImageCalculator;
import ij.plugin.LutLoader;

import java.lang.reflect.InvocationTargetException;
import java.lang.reflect.Method;

/**
 * BRET Analyzer
 * @author Yan Chastagnier
 */
public class BRET_Analyzer implements PlugIn {
	public void run(String arg0) {
		ToolTipManager.sharedInstance().setDismissDelay(30000);
		BRETAnalyzerProcess.getInstance().getFrame();
	}
	
	public static void main(String[] args) {
		// set the plugins.dir property to make the plugin appear in the Plugins menu
		Class<?> clazz = BRET_Analyzer.class;
		String url = clazz.getResource("/" + clazz.getName().replace('.', '/') + ".class").toString();
		String pluginsDir = url.substring("file:".length(), url.length() - clazz.getName().length() - ".class".length());
		System.setProperty("plugins.dir", pluginsDir);
		
		// create the ImageJ application context with all available services
		//final ImageJ ij = new ImageJ();
		new ImageJ();
		
		// run the plugin
		IJ.runPlugIn(clazz.getName(), "");
		//ij.quit();
	}
}

class BRETAnalyzerProcess implements ActionListener, WindowListener {
	private static BRETAnalyzerProcess instance = null;
	Dimension screenSize = Toolkit.getDefaultToolkit().getScreenSize();
	private double screenWidth = screenSize.getWidth();
	private double screenHeight = screenSize.getHeight();
	private double framePosX = Prefs.get("BRETa.framePosX", 0);
	private double framePosY = Prefs.get("BRETa.framePosY", 0);
	private double frameSizeX = Prefs.get("BRETa.globalFrameSizeX", 465);
	private double frameSizeY = Prefs.get("BRETa.globalFrameSizeY", 51);
	
	public static final String autoThCmd = getCommand("Auto_Threshold");
	public static final String autoLocThCmd = getCommand("Auto_Local_Threshold");
	public static final String surfPlotCmd = getCommand("Interactive_3D_Surface_Plot");
	
	private Frame frame = null;
	private JButton butClean, butCrop, butDivide, butAnalyse, butClose;
	private OpenDialog od;
	private DirectoryChooser dc;
	private File existFile;
	
	private String donorName;
	private String acceptorName;
	private CleanParameters cleanParms;
	private CropParameters cropParms;
	private DivideParameters divideParms;	
	private final String[] thresholdMethodList = {"Median", "Mean x Coeff", "AutoTh-Otsu", "AutoTh-Chastagnier",
			"AutoLocalTh-Phansalkar", "AutoLocalTh-MidGrey", "AutoLocalTh-Niblack"};
			// add AutoTh or AutoLocalTh methods to the list, to easily add them in the Divide process
	
	protected BRETAnalyzerProcess() {}
	
	public static BRETAnalyzerProcess getInstance() {
		if (instance == null) {
			instance = new BRETAnalyzerProcess();
		}
		return instance;
	}
	
	private static String getCommand(String cmdVal) {
		String res = IJ.runMacro("str = getArgument(); List.setCommands; List.toArrays(keys, values);"+
		"for (i = 0; i < values.length; i++) {if (endsWith(values[i], str)) {return keys[i];}}", cmdVal);
		if (res == null) {
			res = cmdVal+" plugin not found.\nInstall the plugin and restart the application to use it.";
		}
		return res;
	}
	
	public void getFrame() {
		if (frame == null) {
			frame = new Frame("BRET Analyzer (v1.0.9)");
			donorName = Prefs.get("BRETa.donorName", "LUC");
			acceptorName = Prefs.get("BRETa.acceptorName", "YFP");
			cleanParms = new CleanParameters();
			cropParms = new CropParameters();
			divideParms = new DivideParameters(thresholdMethodList);
			frame.setVisible(true);
			frame.setLayout(new GridLayout(1,0));
			butClean = new JButton("Clean");
			//butClean.setToolTipText("tooltip test");
			butClean.addActionListener(this);
	        frame.add(butClean);
	        butCrop = new JButton("Crop");
	        butCrop.addActionListener(this);
	        frame.add(butCrop);
	        butDivide = new JButton("Divide");
	        butDivide.addActionListener(this);
	        frame.add(butDivide);
	        butAnalyse = new JButton("Analyse");
	        butAnalyse.addActionListener(this);
	        frame.add(butAnalyse);
	        butClose = new JButton("Close");
	        butClose.addActionListener(this);
	        frame.add(butClose);
	        frame.setLocation((int)framePosX, (int)framePosY);
	        frame.pack();
			frame.setSize((int)frameSizeX, (int)frameSizeY);
	        frame.addWindowListener(this);
		} else {
			frame.toFront();
		}
	}
	
	public void actionPerformed(ActionEvent e) {
		Object b = e.getSource();
        if (b==butClean) {
            if (setCleanParms()) {
        		if (cleanParms.alignStacks) {
	            	String turboRegPath = IJ.getDirectory("plugins")+"TurboReg_.jar";
	    			existFile = new File(turboRegPath);
	    			if (!existFile.exists()) {
	    				IJ.log("TurboReg plugin is not installed, please download it from http://bigwww.epfl.ch/thevenaz/turboreg/"
								+ "\nUnpack it and put file TurboReg_.jar in "+IJ.getDirectory("plugins")
								+ "\nClean process continues without alignment.");
	    				cleanParms.alignStacks = false;
	    			}
        		}
        		String[][] pathPairs = getPathPairs(cleanParms.batchClean, "raw", null, null);
        		if (pathPairs != null) {
        			BWImps bwImps = getBWImps();
	        		CleanProcess cp = new CleanProcess(donorName, acceptorName, pathPairs, bwImps, cleanParms);
    				cp.getThread().start();
        		} else {IJ.log("Clean operation canceled (dialog canceled or no pair found, check donor and acceptor names)");}
        		IJ.beep();
            }
        } else if (b==butCrop){
            if (setCropParms()) {
            	String[][] pathPairs = getOpenedCleanPairPaths();
        		Boolean alreadyOpen = true;
            	if (pathPairs == null) {
            		alreadyOpen = false;
            		pathPairs = getPathPairs(cropParms.batchCrop, "clean", "_clean", "CROP");
            	}
        		if (pathPairs != null) {
        			CropProcess cp = new CropProcess(donorName, acceptorName, alreadyOpen, pathPairs, cropParms);
        			cp.getThread().start();
        		} else {IJ.log("Crop operation canceled (dialog canceled or no pair found, check donor and acceptor names)");}
        		IJ.beep();
            }
        } else if (b==butDivide){
            if (setDivideGlobalParms()) {
        		String[][] pathPairs = getOpenedCleanPairPaths();
        		Boolean alreadyOpen = true;
            	if (pathPairs == null) {
            		alreadyOpen = false;
            		pathPairs = getPathPairs(divideParms.batchDivide, "clean", "_clean", null);
            	}
        		if (pathPairs != null) {
        			DivideProcess dp = new DivideProcess(donorName, acceptorName, alreadyOpen, pathPairs, divideParms, thresholdMethodList);
        			dp.getThread().start();
        		} else {IJ.log("Divide operation canceled (dialog canceled or no pair found, check donor and acceptor names)");}
        		IJ.beep();
            }
        } else if (b==butAnalyse){
    		AnalyseProcess ap = AnalyseProcess.getInstance();
    		ap.update(donorName, acceptorName);
    		ap.run();
        } else if (b==butClose){
        	int[] imageIDs = WindowManager.getIDList();
        	if (imageIDs != null) {
	        	ImagePlus impToClose;
	        	for (int imageID : imageIDs) {
	        		impToClose = WindowManager.getImage(imageID);
	        		if (impToClose != null) {
	        			impToClose.close();
	        		}
	        	}
        	}
        	String[] windowsToClose = {"Results", "Log", "Analyse results"};
        	for (String windowToClose : windowsToClose) {
        		java.awt.Window win = WindowManager.getWindow(windowToClose);
        		if (win != null) {
        			win.dispose();
        		}
        	}
        }
	}
	
	private String[][] getOpenedCleanPairPaths() {
		ImagePlus donorClean = WindowManager.getImage(donorName+"_clean");
		ImagePlus acceptorClean = WindowManager.getImage(acceptorName+"_clean");
		String[][] pathPairs = null;
		if (donorClean!=null && acceptorClean!=null) {
			pathPairs = new String[][]{{(String)donorClean.getProperty("Path")}, {(String)acceptorClean.getProperty("Path")}};
			if (pathPairs[0][0] == null) {
				pathPairs[0][0] = donorClean.getFileInfo().directory+donorClean.getFileInfo().fileName;
			}
			if (pathPairs[1][0] == null) {
				pathPairs[1][0] = acceptorClean.getFileInfo().directory+acceptorClean.getFileInfo().fileName;
			}
		}
		return pathPairs;
	}

	private BWImps getBWImps() {
		BWImps res;
		if (cleanParms.subtractBlackImage) {
			String donorBlackPath;
			String acceptorBlackPath;
			String donorWhitePath;
			String acceptorWhitePath;
			IJ.showStatus("Select black image for "+donorName+".");
			od = new OpenDialog("Select black image for "+donorName+".");
			donorBlackPath = od.getPath();
			if (donorBlackPath != null) {
				acceptorBlackPath = replaceLast(donorBlackPath, donorName, acceptorName);
				existFile = new File(acceptorBlackPath);
		    		if (!existFile.exists()) {
		    			IJ.showStatus("Select black image for "+acceptorName+".");
		    			od = new OpenDialog("Select black image for "+acceptorName+".");
		    			acceptorBlackPath = od.getPath();
		    		}
		    		if (acceptorBlackPath != null) {
		    			if (cleanParms.divideByWhiteImage) {
		    				IJ.showStatus("Select white image for "+donorName+".");
		    				od = new OpenDialog("Select white image for "+donorName+".");
		    				donorWhitePath = od.getPath();
		    				if (donorWhitePath != null) {
		    					acceptorWhitePath = replaceLast(donorWhitePath, donorName, acceptorName);
		    					existFile = new File(acceptorWhitePath);
		    		    		if (!existFile.exists()) {
		    		    			IJ.showStatus("Select white image for "+acceptorName+".");
		    		    			od = new OpenDialog("Select white image for "+acceptorName+".");
		    		    			acceptorWhitePath = od.getPath();
		    		    		}
		    		    		if (acceptorWhitePath != null) {
		    		    			// if subtract black and divide by white
		    		    			res = new BWImps(donorBlackPath, acceptorBlackPath, donorWhitePath, acceptorWhitePath);
		    		    		} else {
		    		    			// if acceptorWhitePath dialog has been canceled
		    		    			res = new BWImps(donorBlackPath, acceptorBlackPath);
		    		    			IJ.log("Incorrect white acceptor image path, proceeding with only black image subtraction");
		    		    		}
		    				} else {
		    					// if donorWhitePath dialog has been canceled
		    					res = new BWImps(donorBlackPath, acceptorBlackPath);
	    		    			IJ.log("Incorrect white donor image path, proceeding with only black image subtraction");
		    				}
		    			} else {
		    				// if subtract black but not divide by white
		    				res = new BWImps(donorBlackPath, acceptorBlackPath);
		    			}
		    		} else {
		    			// if acceptorBlackPath dialog has been canceled
		    			res = new BWImps();
		    			IJ.log("Incorrect black acceptor image path, proceeding without black image subtraction");
		    		}
			} else {
				// if donorBlackPath dialog has been canceled
				res = new BWImps();
				IJ.log("Incorrect black donor image path, proceeding without black image subtraction");}
		} else {
			// if no subtract black image return BWImps set to false with no paths
			res = new BWImps();
		}
    	return res;
	}
	
	private String[][] getPathPairs(boolean batch, String title, String suppl, String exclude) {
		// title is "raw" for clean and "clean" for crop and divide
		// suppl is null for clean and "_clean" for crop and divide
		// exclude is null for clean and divide, and "CROP" for crop
		String[][] pathPairs = null;
		if (batch) {
			IJ.showStatus("Choose directory containing "+title+" images");
			dc = new DirectoryChooser("Choose directory containing "+title+" images");
			String directoryPath = dc.getDirectory();
			if (directoryPath != null) {
    			File directory = new File(directoryPath);
    			String[] pathsStrings = getFilePairs(directory, donorName, acceptorName, suppl, exclude);
    			pathPairs = new String[][]{pathsStrings[0].split("( ____ )"), pathsStrings[1].split("( ____ )")};
			}
		} else {
			IJ.showStatus("Select "+title+" "+donorName+" image to open.");
    		od = new OpenDialog("Select "+title+" "+donorName+" image to open.");
    		String donorPath = od.getPath();
    		if (donorPath != null) {
        		String acceptorPath = replaceLast(donorPath, donorName, acceptorName);
        		existFile = new File(acceptorPath);
        		if (!existFile.exists()) {
        			IJ.showStatus("Select "+title+" "+acceptorName+" image to open.");
        			od = new OpenDialog("Select "+title+" "+acceptorName+" image to open.");
        			acceptorPath = od.getPath();
        		}
        		if (acceptorPath != null) {
        			pathPairs = new String[][]{{donorPath},{acceptorPath}};
        		}
    		}
		}
		return pathPairs;
	}
	
	private String[] getFilePairs(final File folder, String donorName, String acceptorName, String suppl, String exclude) {
		String [] res = {"", ""};
		File[] listFiles;
		File[] listFiles2 = folder.listFiles();
		File[] listFiles3;
		boolean searchSuppl = (suppl != null);
		boolean searchExclude = (exclude != null);
		boolean addFiles;
		int searchMaxDepth = 5;
		while (searchMaxDepth > 0 && res[0] == "") {
			searchMaxDepth--;
			listFiles = Arrays.copyOf(listFiles2, listFiles2.length);
			listFiles2 = new File[0];
			for (final File fileEntry : listFiles) {
				if (fileEntry.isDirectory()) {
					listFiles3 = fileEntry.listFiles();
					listFiles2 = Arrays.copyOf(listFiles2, listFiles2.length+listFiles3.length);
					System.arraycopy(listFiles3, 0, listFiles2, listFiles2.length-listFiles3.length, listFiles3.length);
				} else if (fileEntry.isFile()) {
		        		existFile = new File(replaceLast(fileEntry.getPath(), donorName, acceptorName));
		        		if (existFile.exists() && !existFile.equals(fileEntry)) {
		        			addFiles = true;
		        			if (searchSuppl) {
		        				addFiles = fileEntry.getName().indexOf(suppl) != -1;
		        			}
		        			if (searchExclude) {
		        				addFiles = fileEntry.getName().indexOf(exclude) == -1 && addFiles;
		        			}
		        			if (addFiles) {
		        				res[0] += fileEntry.getPath()+" ____ ";
		        				res[1] += existFile.getPath()+" ____ ";
		        			}
		        		}
				}
			}
		}
		return res;
	}
	
	public String[] getAllFilePairs(final File folder, String donorName, String acceptorName) {
		String[] res = {"", ""};
	    for (final File fileEntry : folder.listFiles()) {
	        if (fileEntry.isDirectory()) {
	            String[] tempRes = getAllFilePairs(fileEntry, donorName, acceptorName);
	            if (tempRes[0].length() > 1) {
	            		res[0] += tempRes[0];
	            		res[1] += tempRes[1];
	            }
	        } else {
	        		existFile = new File(replaceLast(fileEntry.getPath(), donorName, acceptorName));
	        		if (existFile.exists() && !existFile.equals(fileEntry)) {
	        			res[0] += fileEntry.getPath()+" ____ ";
	        			res[1] += existFile.getPath()+" ____ ";
	        		}
	        }
	    }
		return res;
	}
	
	private boolean setCleanParms() {
		GenericDialog gd = new GenericDialog("Clean parameters");
		gd.addStringField("Donor name:", donorName);
		gd.addStringField("Acceptor name:", acceptorName);
		gd.addCheckbox("Subtract dark area median", cleanParms.subtractAreaMedian);
		gd.addCheckbox("Subtract black image", cleanParms.subtractBlackImage);
		gd.addCheckbox("Divide by white image", cleanParms.divideByWhiteImage);
		gd.addCheckbox("Align images", cleanParms.alignStacks);
		gd.addCheckbox("Batch mode", cleanParms.batchClean);
		gd.showDialog();
		if (gd.wasCanceled()) return false;
		donorName = gd.getNextString();
		Prefs.set("BRETa.donorName", donorName);
		acceptorName = gd.getNextString();
		Prefs.set("BRETa.acceptorName", acceptorName);
		cleanParms.subtractAreaMedian = gd.getNextBoolean();
		Prefs.set("BRETa.subtractAreaMedian", cleanParms.subtractAreaMedian);
		cleanParms.subtractBlackImage = gd.getNextBoolean();
		Prefs.set("BRETa.subtractBlackImage", cleanParms.subtractBlackImage);
		cleanParms.divideByWhiteImage = gd.getNextBoolean();
		Prefs.set("BRETa.divideByWhiteImage", cleanParms.divideByWhiteImage);
		cleanParms.alignStacks = gd.getNextBoolean();
		Prefs.set("BRETa.alignStacks", cleanParms.alignStacks);
		cleanParms.batchClean = gd.getNextBoolean();
		Prefs.set("BRETa.batchClean", cleanParms.batchClean);
		return true;
	}
	
	private boolean setCropParms() {
		GenericDialog gd = new GenericDialog("Crop parameters");
		gd.addStringField("Donor name:", donorName);
		gd.addStringField("Acceptor name:", acceptorName);
		gd.addCheckbox("Label crops", cropParms.nameCROPs);
		gd.addCheckbox("Batch mode", cropParms.batchCrop);
		gd.showDialog();
		if (gd.wasCanceled()) return false;
		donorName = gd.getNextString();
		Prefs.set("BRETa.donorName", donorName);
		acceptorName = gd.getNextString();
		Prefs.set("BRETa.acceptorName", acceptorName);
		cropParms.nameCROPs = gd.getNextBoolean();
		Prefs.set("BRETa.nameCROPs", cropParms.nameCROPs);
		cropParms.batchCrop = gd.getNextBoolean();
		Prefs.set("BRETa.batchCrop", cropParms.batchCrop);
		return true;
	}
	
	private boolean setDivideGlobalParms() {
		GenericDialog gd = new GenericDialog("Divide parameters");
		gd.addStringField("Donor name:", donorName);
		gd.addStringField("Acceptor name:", acceptorName);
		gd.addCheckbox("Batch mode", divideParms.batchDivide);
		gd.showDialog();
		if (gd.wasCanceled()) return false;
		donorName = gd.getNextString();
		Prefs.set("BRETa.donorName", donorName);
		acceptorName = gd.getNextString();
		Prefs.set("BRETa.acceptorName", acceptorName);
		divideParms.batchDivide = gd.getNextBoolean();
		Prefs.set("BRETa.batchDivide", divideParms.batchDivide);
		return true;
	}
	
	public static String replaceLast(String string, String substring, String replacement) {
		int index = string.lastIndexOf(substring);
		if (index == -1) {
			return "";
		} else {
			return string.substring(0, index) + replacement + string.substring(index+substring.length());
		}
	}
	
	public void showAtLoc(ImagePlus imp, double normalizedX, double normalizedY) {
		ImageWindow.setNextLocation((int)(normalizedX*screenWidth), (int)(normalizedY*screenHeight));
		imp.show();
	}
	
	public void windowOpened(WindowEvent e) {}
	public void windowClosing(WindowEvent e) {
		framePosX = frame.getLocation().getX();
		framePosY = frame.getLocation().getY();
		Prefs.set("BRETa.framePosX", framePosX);
		Prefs.set("BRETa.framePosY", framePosY);
		frameSizeX = frame.getSize().getWidth();
		frameSizeY = frame.getSize().getHeight();
		Prefs.set("BRETa.globalFrameSizeX", frameSizeX);
		Prefs.set("BRETa.globalFrameSizeY", frameSizeY);
		frame.dispose();
		frame = null;
	}
	public void windowClosed(WindowEvent e) {}
	public void windowIconified(WindowEvent e) {}
	public void windowDeiconified(WindowEvent e) {}
	public void windowActivated(WindowEvent e) {}
	public void windowDeactivated(WindowEvent e) {}
}

class CleanParameters {
	public boolean batchClean;
	public boolean subtractAreaMedian;
	public boolean subtractBlackImage;
	public boolean divideByWhiteImage;
	public boolean alignStacks;
	CleanParameters() {
		batchClean = Prefs.get("BRETa.batchClean", false);
		subtractAreaMedian = Prefs.get("BRETa.subtractAreaMedian", true);
		subtractBlackImage = Prefs.get("BRETa.subtractBlackImage", false);
		divideByWhiteImage = Prefs.get("BRETa.divideByWhiteImage", false);
		alignStacks = Prefs.get("BRETa.alignStacks", true);
	}
}

class CropParameters {
	public boolean batchCrop;
	public boolean nameCROPs;
	CropParameters() {
		batchCrop = Prefs.get("BRETa.batchCrop", false);
		nameCROPs = Prefs.get("BRETa.nameCROPs", true);
	}
}

class DivideParameters {
	public boolean batchDivide;
	public String thresholdMethod;
	public double coefMultMeanROI;
	public double localThParm1;
	public double localThParm2;
	public double radiusLocalTh;
	public double chastagnierGaussianLow;
	public double chastagnierGaussianHigh;
	public double overallMinThreshold;
	public double rangeMin;
	public double rangeMax;
	DivideParameters(String[] thresholdMethodList) {
		batchDivide = Prefs.get("BRETa.batchDivide", false);
		thresholdMethod = Prefs.get("BRETa.thresholdMethod", thresholdMethodList[Math.min(3,thresholdMethodList.length-1)]);
		coefMultMeanROI = Prefs.get("BRETa.coefMultMeanROI", 1);
		localThParm1 = Prefs.get("BRETa.localThParm1", 0);
		localThParm2 = Prefs.get("BRETa.localThParm2", 0);
		radiusLocalTh = Prefs.get("BRETa.radiusLocalTh", 10);
		chastagnierGaussianLow = Prefs.get("BRETa.chastagnierGaussianLow", 5);
		chastagnierGaussianHigh = Prefs.get("BRETa.chastagnierGaussianHigh", 15);
		overallMinThreshold = Prefs.get("BRETa.overallMinThreshold", 0);
		rangeMin = Prefs.get("BRETa.rangeMin", 0.1);
		rangeMax = Prefs.get("BRETa.rangeMax", 1);
	}
}

class BWImps {
	public boolean subtractBlack;
	public boolean divideByWhite;
	public ImagePlus donorBlack;
	public ImagePlus acceptorBlack;
	public ImagePlus donorWhite;
	public ImagePlus acceptorWhite;
	BWImps() {
		subtractBlack = false;
		divideByWhite = false;
	}
	BWImps(String donorBlackPath, String acceptorBlackPath) {
		subtractBlack = true;
		divideByWhite = false;
		setBlack(donorBlackPath, acceptorBlackPath);
	}
	BWImps(String donorBlackPath, String acceptorBlackPath, String donorWhitePath, String acceptorWhitePath) {
		subtractBlack = true;
		divideByWhite = true;
		setBlack(donorBlackPath, acceptorBlackPath);
		setWhite(donorWhitePath, acceptorWhitePath);
	}
	
	private void setBlack(String donorBlackPath, String acceptorBlackPath) {
		ZProjector zp;
		donorBlack = IJ.openImage(donorBlackPath);
		acceptorBlack = IJ.openImage(acceptorBlackPath);
		if (donorBlack.getNSlices()>1) {
			zp = new ZProjector(donorBlack);
			zp.setMethod(ZProjector.MEDIAN_METHOD);
			zp.doProjection();
			donorBlack = zp.getProjection();
		}
		if (acceptorBlack.getNSlices()>1) {
			zp = new ZProjector(acceptorBlack);
			zp.setMethod(ZProjector.MEDIAN_METHOD);
			zp.doProjection();
			acceptorBlack = zp.getProjection();
		}
		//IJ.run(donorBlack, "Median...", "radius=10");
		//IJ.run(acceptorBlack, "Median...", "radius=10");
	}
	
	private void setWhite(String donorWhitePath, String acceptorWhitePath) {
		ZProjector zp;
		donorWhite = IJ.openImage(donorWhitePath);
		acceptorWhite = IJ.openImage(acceptorWhitePath);
		if (donorWhite.getNSlices()>1) {
			zp = new ZProjector(donorWhite);
			zp.setMethod(ZProjector.MEDIAN_METHOD);
			zp.doProjection();
			donorWhite = zp.getProjection();
		}
		if (acceptorWhite.getNSlices()>1) {
			zp = new ZProjector(acceptorWhite);
			zp.setMethod(ZProjector.MEDIAN_METHOD);
			zp.doProjection();
			acceptorWhite = zp.getProjection();
		}
		ImageCalculator ic = new ImageCalculator();
		ImageStatistics istat;
		ic.run("Subtract", donorWhite, donorBlack);
		ic.run("Subtract", acceptorWhite, acceptorBlack);
		IJ.run(donorWhite, "32-bit", "");
		IJ.run(acceptorWhite, "32-bit", "");
		istat = donorWhite.getStatistics(ImageStatistics.MEAN);
		IJ.run(donorWhite, "Divide...", "value="+istat.mean);
		istat = acceptorWhite.getStatistics(ImageStatistics.MEAN);
		IJ.run(acceptorWhite, "Divide...", "value="+istat.mean);
	}
}

class CleanProcess implements Runnable {
	private final Thread t;
	private final String donorName;
	private final String acceptorName;
	private double donorPosX = Prefs.get("BRETa.donorPosX", 100);
	private double donorPosY = Prefs.get("BRETa.donorPosY", 100);
	private double acceptorPosX = Prefs.get("BRETa.acceptorPosX", 500);
	private double acceptorPosY = Prefs.get("BRETa.acceptorPosY", 100);
	private double bgDiaPosX = Prefs.get("BRETa.bgDiaPosX", 400);
	private double bgDiaPosY = Prefs.get("BRETa.bgDiaPosY", 100);
	private final String[][] rawPaths;
	private final BWImps bwImps;
	private String donorCleanPath;
	private String acceptorCleanPath;
	private ImagePlus donorImg;
	private ImagePlus acceptorImg;
	private ImagePlus dBlack;
	private ImagePlus aBlack;
	private ImagePlus dWhite;
	private ImagePlus aWhite;
	private CleanParameters cleanParms;
	private ImageStatistics istat;
	
	public CleanProcess(
		String donorName,
		String acceptorName,
		String rawPaths[][], 
		BWImps bwImps,
		CleanParameters cleanParms
	){
		this.t = new Thread(this);
		this.donorName = donorName;
		this.acceptorName = acceptorName;
		this.rawPaths = rawPaths;
		this.bwImps = bwImps;
		this.cleanParms = cleanParms;
		if (bwImps.subtractBlack) {
			this.dBlack = bwImps.donorBlack.duplicate();
			this.aBlack = bwImps.acceptorBlack.duplicate();
			if (bwImps.divideByWhite) {
				this.dWhite = bwImps.donorWhite.duplicate();
				this.aWhite = bwImps.acceptorWhite.duplicate();
			}
		}
	}
	
	public Thread getThread() {
		return t;
	}
	
	public void run() {
		for (int n = 0; n < rawPaths[0].length; n++) {
			if (rawPaths[0].length>1) {IJ.log("Cleaning file "+(n+1)+" / "+rawPaths[0].length);}
			donorCleanPath = donorToCleanDonor(rawPaths[0][n], donorName);
			acceptorCleanPath = BRETAnalyzerProcess.replaceLast(donorCleanPath, donorName, acceptorName);
			donorImg = IJ.openImage(rawPaths[0][n]);
			acceptorImg = IJ.openImage(rawPaths[1][n]);
			if (donorImg.getNSlices()!=acceptorImg.getNSlices()) {
				IJ.log("The images don't have the same number of slices, clean operation canceled for the pair:\n"
					+rawPaths[0][n]+"\n"+rawPaths[1][n]);
				continue;
			}
			FileSaver fs;
			if (cleanParms.subtractAreaMedian) {
				Rectangle rect = getBGArea(donorImg);
				donorImg.setRoi(rect);
				if (!cleanParms.batchClean) {
					donorImg.setTitle(donorName);
					ImageWindow.setNextLocation((int)donorPosX, (int)donorPosY);
					donorImg.show();
					acceptorImg.setTitle(acceptorName);
					ImageWindow.setNextLocation((int)acceptorPosX, (int)acceptorPosY);
					acceptorImg.show();
					WaitForUserDialog.setNextLocation((int)bgDiaPosX, (int)bgDiaPosY);
					WaitForUserDialog wfud = new WaitForUserDialog("Background selection", "Select background area then click OK.");
					wfud.show();
					bgDiaPosX = wfud.getLocation().getX();
					bgDiaPosY = wfud.getLocation().getY();
					Prefs.set("BRETa.bgDiaPosX", bgDiaPosX);
					Prefs.set("BRETa.bgDiaPosY", bgDiaPosY);
					try {rect = IJ.getImage().getRoi().getBounds();}	// if there is an active window, use its ROI
					catch (java.lang.NullPointerException ex) {}		// else keep the current one
				}
				
				double donorBlackMedian = 0;
				double acceptorBlackMedian = 0;
				if (bwImps.subtractBlack) {
					dBlack.setRoi(rect);
					istat = dBlack.getStatistics(ImageStatistics.MEDIAN);
					donorBlackMedian = istat.median;
					dBlack.deleteRoi();
					aBlack.setRoi(rect);
					istat = aBlack.getStatistics(ImageStatistics.MEDIAN);
					acceptorBlackMedian = istat.median;
					aBlack.deleteRoi();
				}
	
				for (int i = 1; i <= donorImg.getNSlices(); i++) {
					donorImg.setSlice(i);
					donorImg.setRoi(rect);
					istat = donorImg.getStatistics(ImageStatistics.MEDIAN);
					donorImg.deleteRoi();
					IJ.run(donorImg, "Subtract...", "value="+Double.toString(istat.median-donorBlackMedian)+" slice");
				}
				for (int i = 1; i <= acceptorImg.getNSlices(); i++) {
					acceptorImg.setSlice(i);
					acceptorImg.setRoi(rect);
					istat = acceptorImg.getStatistics(ImageStatistics.MEDIAN);
					acceptorImg.deleteRoi();
					IJ.run(acceptorImg, "Subtract...", "value="+Double.toString(istat.median-acceptorBlackMedian)+" slice");
				}
			}
			
			if (bwImps.subtractBlack) {
				ImageCalculator ic = new ImageCalculator();
				ic.run("Subtract stack", donorImg, dBlack);
				ic.run("Subtract stack", acceptorImg, aBlack);
				if (bwImps.divideByWhite) {
					ic.run("Divide stack", donorImg, dWhite);
					ic.run("Divide stack", acceptorImg, aWhite);
				}
			}
			
			donorImg.setSlice(1);
			IJ.run(donorImg, "Enhance Contrast", "saturated=0.35");
			acceptorImg.setSlice(1);
			IJ.run(acceptorImg, "Enhance Contrast", "saturated=0.35");
			
			donorImg.deleteRoi();
			acceptorImg.deleteRoi();
			IJ.run(donorImg, "Median...", "radius=1 stack");
			IJ.run(acceptorImg, "Median...", "radius=1 stack");
			if (cleanParms.alignStacks) {
				ImagePlus[] imps = {donorImg, acceptorImg};
				alignImages(imps);
			}
			if (!cleanParms.batchClean) {
				donorImg.setTitle(donorName+"_clean");
				acceptorImg.setTitle(acceptorName+"_clean");
				donorImg.setProperty("Path", donorCleanPath);
				acceptorImg.setProperty("Path", acceptorCleanPath);
				if (cleanParms.subtractAreaMedian) {
					donorPosX = donorImg.getWindow().getLocation().getX();
					donorPosY = donorImg.getWindow().getLocation().getY();
					acceptorPosX = acceptorImg.getWindow().getLocation().getX();
					acceptorPosY = acceptorImg.getWindow().getLocation().getY();
					Prefs.set("BRETa.donorPosX", donorPosX);
					Prefs.set("BRETa.donorPosY", donorPosY);
					Prefs.set("BRETa.acceptorPosX", acceptorPosX);
					Prefs.set("BRETa.acceptorPosY", acceptorPosY);
				}
			}
			fs = new FileSaver(donorImg);
			fs.saveAsTiff(donorCleanPath);
			fs = new FileSaver(acceptorImg);
			fs.saveAsTiff(acceptorCleanPath);
		}
		IJ.showStatus("Clean operation complete");
		IJ.showProgress(1, 1);
		if (cleanParms.batchClean) {
			IJ.log("Clean operation complete");
		}
	}
	
	public void alignImages(ImagePlus[] imps) {
		if (imps.length == 0) {IJ.log("No stacks to align");return;}
		int nSlices = imps[0].getNSlices();
		if (nSlices < 2) {IJ.log("First stack needs at least 2 slices to be aligned");return;}
		// get translation coordinates to align the first stack
		double[] xTrans = new double[nSlices]; xTrans[0] = 0;
		double[] yTrans = new double[nSlices]; yTrans[0] = 0;
		double[][] mySourcePoints;
		double[][] myTargetPoints;
		int width = imps[0].getWidth();
		int height = imps[0].getHeight();
		String tmpDir = IJ.getDirectory("temp")+"turboRegAlign"+File.separator;
		File tmpFile = new File(tmpDir);
		if (!tmpFile.exists()) {tmpFile.mkdir();}
		IJ.run(imps[0], "Image Sequence... ", "format=TIFF name=a save="+tmpDir);
		tmpDir += "a";
		for (int i = 1; i < nSlices; i++) {
			IJ.showStatus("Computing translation coordinates for slice "+(i+1)+" / "+nSlices);
			String turboRegOptions = "-align -file "+tmpDir+IJ.pad(i-1,4)+".tif 0 0 "+(width-1)+" "+(height-1)+" -file "+tmpDir+IJ.pad(i,4)+".tif 0 0 "
					+(width-1)+" "+(height-1)+" -translation "+(width/2)+" "+(height/2)+" "+(width/2)+" "+(height/2)+" -hideOutput";
			try {
				Object turboReg = IJ.runPlugIn("TurboReg_", turboRegOptions);
				if (turboReg == null) {
					IJ.log("TurboReg plugin is not installed, please download it from http://bigwww.epfl.ch/thevenaz/turboreg/"
							+ "\nUnpack it and put file TurboReg_.jar in Fiji.app/plugins/\n"
							+ "Clean process resumed without alignment.");
					return;
				}
				Method method = turboReg.getClass().getMethod("getSourcePoints", (Class[])null);
			    mySourcePoints = (double[][])method.invoke(turboReg);
			    method = turboReg.getClass().getMethod("getTargetPoints", (Class[])null);
			    myTargetPoints = (double[][])method.invoke(turboReg);
			    xTrans[i] = mySourcePoints[0][0]-myTargetPoints[0][0]+xTrans[i-1];
			    yTrans[i] = mySourcePoints[0][1]-myTargetPoints[0][1]+yTrans[i-1];
			} catch (NoSuchMethodException e) {
				IJ.error("Unexpected NoSuchMethodException " + e);IJ.log("Clean process resumed without alignment.");
				return;
			} catch (IllegalAccessException e) {
				IJ.error("Unexpected IllegalAccessException " + e);IJ.log("Clean process resumed without alignment.");
				return;
			} catch (InvocationTargetException e) {
				IJ.error("Unexpected InvocationTargetException " + e);IJ.log("Clean process resumed without alignment.");
				return;
			}
		}
		double xMed = getMedian(xTrans);
		double yMed = getMedian(yTrans);
		// apply the translations to all the stacks
		for (int i = 0; i < imps.length; i++) {
			for (int j = 0; j < Math.min(imps[i].getNSlices(), nSlices); j++) {
				imps[i].setSlice(j+1);
				IJ.run(imps[i], "Translate...", "x="+Math.round(xTrans[j]-xMed)+" y="+Math.round(yTrans[j]-yMed)+" interpolation=None slice");
			}
		}
	}
	
	public double getMedian(double[] arr) {
		double[] array = Arrays.copyOf(arr, arr.length);
		Arrays.sort(array);
		double halfLen = array.length/2;
		return (array[(int)Math.floor(halfLen)]+array[(int)Math.ceil(halfLen)])/2;
	}
	
 	public static String donorToCleanDonor(String filePath, String donorName) {
		File file = new File(filePath);
		String parentFolder = file.getParent();
		String fileName = file.getName();
		String fileCleanName;
		int index = fileName.lastIndexOf(donorName);
		int indexExt = fileName.lastIndexOf(".");
		if (index == -1) {
			if (indexExt == -1) {
				fileName = fileName+"_";
			} else {
				fileName = fileName.substring(0, indexExt);
			}
			fileCleanName = fileName+donorName+"_clean.tif";
		} else {
			if (indexExt > index) {
				fileCleanName = fileName.substring(0, indexExt)+"_clean.tif";
				fileName = fileName.substring(0, index)+fileName.substring(index+donorName.length(), indexExt);
			} else {
				fileName = fileName.substring(0, indexExt);
				fileCleanName = fileName.substring(0, indexExt)+donorName+"_clean.tif";
			}
			if (fileName.length()==0) {fileName = "clean";}
		}
		file = new File(parentFolder+File.separator+fileName+File.separator);
		if (!file.exists()) {file.mkdir();}
		return parentFolder+File.separator+fileName+File.separator+fileCleanName;
	}
	
	private Rectangle getBGArea(ImagePlus imp) {
		double minVal = Double.MAX_VALUE;
		int x = 0;
		int y = 0;
		ImagePlus impproj;
		if (imp.getNSlices() > 1) {
			ZProjector zp = new ZProjector(imp);
			zp.setMethod(ZProjector.AVG_METHOD);
			zp.doProjection();
			impproj = zp.getProjection();
		} else {
			impproj = imp;
		}
		int projWidth = impproj.getWidth();
		int projHeight = impproj.getHeight();
		int areaWidth = java.lang.Math.min(32, projWidth);
		int areaHeight = java.lang.Math.min(32, projHeight);
		int stepWidth = java.lang.Math.min(8, areaWidth);
		int stepHeight = java.lang.Math.min(8, areaHeight);
		for (int i = 0; i < (int)(projWidth-areaWidth); i+=stepWidth) {
			for (int j = 0; j < (int)(projHeight-areaHeight); j+=stepHeight) {
				impproj.setRoi(i, j, areaWidth, areaHeight);
				istat = impproj.getStatistics(ImageStatistics.MEAN);
				if (minVal > istat.mean) {
					minVal = istat.mean;
					x = i;
					y = j;
				}
			}
		}
		return new Rectangle(x, y, areaWidth, areaHeight);
	}
}

class CropProcess implements Runnable {
	private final Thread t;
	private final String donorName;
	private final String acceptorName;
	private double donorPosX = Prefs.get("BRETa.donorPosX", 100);
	private double donorPosY = Prefs.get("BRETa.donorPosY", 100);
	private double acceptorPosX = Prefs.get("BRETa.acceptorPosX", 500);
	private double acceptorPosY = Prefs.get("BRETa.acceptorPosY", 100);
	private double roiSelDiaPosX = Prefs.get("BRETa.roiSelDiaPosX", 400);
	private double roiSelDiaPosY = Prefs.get("BRETa.roiSelDiaPosY", 100);
	private double cropDiaPosX = Prefs.get("BRETa.cropDiaPosX", 400);
	private double cropDiaPosY = Prefs.get("BRETa.cropDiaPosY", 100);
	private final boolean alreadyOpen;
	private final String[][] rawPaths;
	private String cropROIsPath;
	private String cropROIsNamePath;
	private CropParameters cropParms;
	private ImagePlus donorImg;
	private ImagePlus acceptorImg;
	private ImagePlus cropImg;
	
	public CropProcess(
		String donorName,
		String acceptorName,
		boolean alreadyOpen,
		String rawPaths[][], 
		CropParameters cropParms
	){
		this.t = new Thread(this);
		this.donorName = donorName;
		this.acceptorName = acceptorName;
		this.alreadyOpen = alreadyOpen;
		this.rawPaths = rawPaths;
		this.cropParms = cropParms;
	}
	
	public Thread getThread() {
		return t;
	}
	
	public void run() {
		File file;
		String directory;
		String donorFileName;
		String acceptorFileName;
		for (int n = 0; n < rawPaths[0].length; n++) {
			file = new File(rawPaths[0][n]);
			directory = file.getParent();
			donorFileName = file.getName();
			file = new File(rawPaths[1][n]);
			acceptorFileName = file.getName();
			if (rawPaths[0].length>1) {IJ.log("Cropping file "+(n+1)+" / "+rawPaths[0].length);}
			if (alreadyOpen) {
				donorImg = WindowManager.getImage(donorName+"_clean");
				acceptorImg = WindowManager.getImage(acceptorName+"_clean");
			} else {
				donorImg = IJ.openImage(rawPaths[0][n]);
				acceptorImg = IJ.openImage(rawPaths[1][n]);
			}
			if (donorImg.getNSlices()!=acceptorImg.getNSlices()) {
				IJ.log("The images don't have the same number of slices, cropping operation canceled for the pair:\n"
					+rawPaths[0][n]+"\n"+rawPaths[1][n]);
				continue;
			}
			getRM(true).reset();
			cropROIsPath = directory+File.separator+"cropAREAs.zip";
			cropROIsNamePath = directory+File.separator+"CROPs.txt";
			acceptorImg.setTitle(acceptorName+"_clean");
			ImageWindow.setNextLocation((int)acceptorPosX, (int)acceptorPosY);
			acceptorImg.show();
			donorImg.setTitle(donorName+"_clean");
			ImageWindow.setNextLocation((int)donorPosX, (int)donorPosY);
			donorImg.show();
			file = new File(cropROIsPath);
			if (file.exists()) {
				getRM(true).runCommand("Open", cropROIsPath);
			}
			WaitForUserDialog wfud = new WaitForUserDialog("ROI management", "Manage ROIs then click OK.");
			wfud.setLocation((int)roiSelDiaPosX, (int)roiSelDiaPosY);
			wfud.show();
			roiSelDiaPosX = wfud.getLocation().getX();
			roiSelDiaPosY = wfud.getLocation().getY();
			Prefs.set("BRETa.roiSelDiaPosX", roiSelDiaPosX);
			Prefs.set("BRETa.roiSelDiaPosY", roiSelDiaPosY);
			int nbCrops = getRM(true).getCount();
			if (cropParms.nameCROPs) {
				String[] namesManager = new String[nbCrops];
				String[] namesFile = new String[nbCrops];
				String[] lines = new String[0];
				String[] namesFileOld = new String[0];
				String[] namesFileParts = new String[0];
				file = new File(cropROIsNamePath);
				if (file.exists()) {
					lines = IJ.openAsString(cropROIsNamePath).split("\n");
					namesFileOld = new String[lines.length];
					for (int i = 0; i < lines.length; i++) {
						namesFileParts = lines[i].split(":");
						if (namesFileParts.length > 1) {
							if (namesFileParts[0].startsWith("CROP")) {
								String index = namesFileParts[0].replace("CROP", "");
								int indexx = Integer.parseInt(index)-1;
								if (indexx < lines.length) {
									namesFileOld[indexx] = lines[i].substring(6+index.length());
								}
							}
						}
					}
				}
				for (int i = 0; i < nbCrops; i++) {
					namesManager[i] = getRM(true).getName(i);
					if (namesManager[i].startsWith("CROP")) {
						int cropNb = Integer.parseInt(namesManager[i].replaceAll("CROP", ""))-1;
						if (cropNb < namesFileOld.length) {
							namesFile[i] = namesFileOld[cropNb];
						}
					}
					getRM(true).rename(i, "CROP"+(i+1));
				}
				getRM(true).runCommand("Associate", "false");
				getRM(true).runCommand("UseNames", "true");
				getRM(true).runCommand(donorImg, "Show all with labels");
				for (int i = 0; i < nbCrops; i = i+6) {
					GenericDialog gd = new GenericDialog("CROP names");
					for (int j = i; j < i+6 && j < nbCrops; j++) {
						gd.addStringField("CROP"+(j+1), namesFile[j]);
					}
					gd.setLocation((int)cropDiaPosX, (int)cropDiaPosY);
					gd.showDialog();
					cropDiaPosX = gd.getLocation().getX();
					cropDiaPosY = gd.getLocation().getY();
					Prefs.set("BRETa.cropDiaPosX", cropDiaPosX);
					Prefs.set("BRETa.cropDiaPosY", cropDiaPosY);
					for (int j = i; j < i+6 && j < nbCrops; j++) {
						namesFile[j] = gd.getNextString();
					}
				}
				PrintWriter writer;
				try {
					writer = new PrintWriter(cropROIsNamePath, "UTF-8");
					for (int i = 0; i < nbCrops; i++) {
						writer.println("CROP"+(i+1)+": "+namesFile[i]);
					}
					writer.close();
				} catch (FileNotFoundException e) {
					IJ.log("File not found, crop names not written");
				} catch (UnsupportedEncodingException e) {
					IJ.log("Unsupported encoding, crop names not written");
				}
			}
			getRM(true).setSelectedIndexes(getSequence(getRM(true).getCount()));
			getRM(true).runCommand("Save", cropROIsPath);
			int index = donorFileName.indexOf(donorName);
			if (index == -1) { index = 0; }
			String pre = directory+File.separator+donorFileName.substring(0, index)+"CROP";
			String donorPost = "_"+donorFileName.substring(index);
			String acceptorPost = "_"+acceptorFileName.substring(index);
			FileSaver crop;
			for (int i = 0; i < nbCrops; i++) {
				getRM(true).select(donorImg, i);
				cropImg = donorImg.duplicate();
				crop = new FileSaver(cropImg);
				crop.saveAsTiff(pre+(i+1)+donorPost);
				cropImg.close();
				getRM(true).select(acceptorImg, i);
				cropImg = acceptorImg.duplicate();
				crop = new FileSaver(cropImg);
				crop.saveAsTiff(pre+(i+1)+acceptorPost);
				cropImg.close();
			}
			donorPosX = donorImg.getWindow().getLocation().getX();
			donorPosY = donorImg.getWindow().getLocation().getY();
			acceptorPosX = acceptorImg.getWindow().getLocation().getX();
			acceptorPosY = acceptorImg.getWindow().getLocation().getY();
			Prefs.set("BRETa.donorPosX", donorPosX);
			Prefs.set("BRETa.donorPosY", donorPosY);
			Prefs.set("BRETa.acceptorPosX", acceptorPosX);
			Prefs.set("BRETa.acceptorPosY", acceptorPosY);
			donorImg.close();
			acceptorImg.close();
		}
		IJ.showStatus("Crop operation complete");
		IJ.showProgress(1, 1);
		if (cropParms.batchCrop) {
			IJ.log("Crop operation complete.");
		}
	}
	
	public static int[] getSequence(int n) {
		int[] res = new int[n];
		for (int i = 0; i < n; i++) {
			res[i] = i;
		}
		return res;
	}
	
	public static String getParent(String filePath) {
		File file = new File(filePath);
		return file.getParent();
	}
	
 	public static String cleanToCrop(String filePath, String donorName, int cropID) {
		File file = new File(filePath);
		String parentFolder = file.getParent();
		String fileName = file.getName();
		String fileCleanName;
		int index = fileName.lastIndexOf(donorName);
		int indexExt = fileName.lastIndexOf(".");
		if (index == -1) {
			if (indexExt == -1) {
				fileName = fileName+"_";
			} else {
				fileName = fileName.substring(0, indexExt);
			}
			fileCleanName = fileName+donorName+"_clean.tif";
		} else {
			if (indexExt > index) {
				fileCleanName = fileName.substring(0, indexExt)+"_clean.tif";
				fileName = fileName.substring(0, index)+fileName.substring(index+donorName.length(), indexExt);
			} else {
				fileName = fileName.substring(0, indexExt);
				fileCleanName = fileName.substring(0, indexExt)+donorName+"_clean.tif";
			}
			if (fileName.length()==0) {fileName = "clean";}
		}
		file = new File(parentFolder+File.separator+fileName+File.separator);
		if (!file.exists()) {file.mkdir();}
		return parentFolder+File.separator+fileName+File.separator+fileCleanName;
	}
 	
	private RoiManager getRM(boolean open) {
		RoiManager rm = RoiManager.getInstance();
		if (!open && rm != null) {
			rm.close();
		}
		if (open && rm == null) {
			rm = RoiManager.getRoiManager();
		}
		return rm;
	}
}

class DivideProcess implements Runnable, DialogListener {
	private final Thread t;
	private final String donorName;
	private final String acceptorName;
	private double donorPosX = Prefs.get("BRETa.donorPosX", 100);
	private double donorPosY = Prefs.get("BRETa.donorPosY", 100);
	private double acceptorPosX = Prefs.get("BRETa.acceptorPosX", 500);
	private double acceptorPosY = Prefs.get("BRETa.acceptorPosY", 100);
	private double donorThPosX = Prefs.get("BRETa.donorThPosX", 100);
	private double donorThPosY = Prefs.get("BRETa.donorThPosY", 400);
	private double ratioPosX = Prefs.get("BRETa.ratioPrePosX", 500);
	private double ratioPosY = Prefs.get("BRETa.ratioPrePosY", 400);
	private double divideDiaPosX = Prefs.get("BRETa.divideDiaPosX", 400);
	private double divideDiaPosY = Prefs.get("BRETa.divideDiaPosY", 150);
	private final boolean alreadyOpen;
	private final String[][] rawPaths;
	private final String[] thresholdMethodList;
	private String thUsed;
	private String thPath;
	private String ratioPath;
	private StringBuilder sb;
	private DivideParameters divideParms;
	private final String[] previewChoices = {"No", "Current donor slice", "Stack"};
	private String preview = previewChoices[0];
	private ImagePlus donorImg;
	private ImagePlus acceptorImg;
	private ImagePlus donorMaskImg;
	private ImagePlus donorThImg;
	private ImageWindow donorThWin = null;
	private ImagePlus ratioImg;
	private ImageWindow ratioWin = null;
	private ImageStatistics istat;
	private ImageCalculator ic = new ImageCalculator();
	private ImageProcessor ip;
	private NonBlockingGenericDialog gd;
	
	public DivideProcess(
		String donorName,
		String acceptorName,
		boolean alreadyOpen,
		String rawPaths[][], 
		DivideParameters divideParms,
		String[] thresholdMethodList
	){
		this.t = new Thread(this);
		this.donorName = donorName;
		this.acceptorName = acceptorName;
		this.alreadyOpen = alreadyOpen;
		this.rawPaths = rawPaths;
		this.divideParms = divideParms;
		this.thresholdMethodList = thresholdMethodList;
	}
	
	public Thread getThread() {
		return t;
	}
	
	public void run() {
		FileSaver fs;
		for (int n = 0; n < rawPaths[0].length; n++) {
			if (rawPaths[0].length>1) {IJ.log("Dividing file "+(n+1)+" / "+rawPaths[0].length);}
			ratioPath = donorToRatio(rawPaths[0][n], donorName);
			thPath = ratioPath.replace(".tif", "_thUsed.txt");
			if (alreadyOpen) {
				donorImg = WindowManager.getImage(donorName+"_clean");
				acceptorImg = WindowManager.getImage(acceptorName+"_clean");
			} else {
				donorImg = IJ.openImage(rawPaths[0][n]);
				acceptorImg = IJ.openImage(rawPaths[1][n]);
			}
			if (donorImg.getNSlices()!=acceptorImg.getNSlices()) {
				IJ.log("The images don't have the same number of slices, divide operation canceled for the pair:\n"
					+rawPaths[0][n]+"\n"+rawPaths[1][n]);
				continue;
			}
			donorMaskImg = new ImagePlus();
			donorThImg = new ImagePlus();
			ratioImg = new ImagePlus();
			if (!divideParms.batchDivide) {
				donorImg.setTitle(donorName+"_clean");
				ImageWindow.setNextLocation((int)donorPosX, (int)donorPosY);
				donorImg.show();
				IJ.run(donorImg, "Enhance Contrast", "saturated=0.35");
				acceptorImg.setTitle(acceptorName+"_clean");
				ImageWindow.setNextLocation((int)acceptorPosX, (int)acceptorPosY);
				acceptorImg.show();
				IJ.run(acceptorImg, "Enhance Contrast", "saturated=0.35");
				File f = new File(thPath);
				if (f.exists()) {
					String[] thParms = IJ.openAsString(thPath).split("\n");
					IJ.log("File "+ratioPath);
					IJ.log("was previously created using method: "+thParms[0]);
					if (thParms[0].endsWith("Chastagnier")) {
						IJ.log("Gaussian radius 1: "+thParms[1]);
						IJ.log("Gaussian radius 2: "+thParms[2]);
					} else if (thParms[0].equals("Mean x Coeff")) {
						IJ.log("Coefficient: "+thParms[3]);
					} else if (thParms[0].startsWith("AutoLocalTh-")) {
						IJ.log("Parameter1: "+thParms[1]);
						IJ.log("Parameter2: "+thParms[2]);
						IJ.log("AutoLocalTh radius: "+thParms[3]);
					}
					IJ.log("Minimum threshold: "+thParms[thParms.length-1]);
					if (thParms[0].equals("Mean x Coeff") || thParms[0].equals("Median")) {
						donorImg.setRoi(AnalyseProcess.getPolyROI(thParms[1], thParms[2])); 
					}
				}
			}
			if (n == 0) {
				gd = new NonBlockingGenericDialog("Divide");
				gd.addChoice("  Threshold method:", thresholdMethodList, divideParms.thresholdMethod);
				gd.addNumericField("Coefficient", divideParms.coefMultMeanROI, 2);
				gd.addNumericField("Parameter_1", divideParms.localThParm1, 2);
				gd.addNumericField("Parameter_2", divideParms.localThParm2, 2);
				gd.addNumericField("AutoLocalTh radius", divideParms.radiusLocalTh, 1);
				gd.addNumericField("Gaussian_radius_1", divideParms.chastagnierGaussianLow, 2);
				gd.addNumericField("Gaussian_radius_2", divideParms.chastagnierGaussianHigh, 2);
				gd.addNumericField("Minimum threshold", divideParms.overallMinThreshold, 0);
				gd.addNumericField("Ratio_range_min", divideParms.rangeMin, 2);
				gd.addNumericField("Ratio_range_max", divideParms.rangeMax, 2);
				gd.addChoice("Preview", previewChoices, preview);
				gd.setAlwaysOnTop(true);
				gd.addDialogListener(this);
				setVisibleItems(gd);
				gd.setLocation((int)divideDiaPosX, (int)divideDiaPosY);
				gd.showDialog();
				divideDiaPosX = gd.getLocation().getX();
				divideDiaPosY = gd.getLocation().getY();
				Prefs.set("BRETa.divideDiaPosX", divideDiaPosX);
				Prefs.set("BRETa.divideDiaPosY", divideDiaPosY);
				if (!gd.wasCanceled()) {
					threshold(false);
				}
				if (ratioWin != null && ratioWin.isVisible()) {
					ratioPosX = ratioWin.getLocation().getX();
					ratioPosY = ratioWin.getLocation().getY();
					Prefs.set("BRETa.ratioPrePosX", ratioPosX);
					Prefs.set("BRETa.ratioPrePosY", ratioPosY);
					ratioWin.close();
				}
				if (donorThWin != null && donorThWin.isVisible()) {
					donorThPosX = donorThWin.getLocation().getX();
					donorThPosY = donorThWin.getLocation().getY();
					Prefs.set("BRETa.donorThPosX", donorThPosX);
					Prefs.set("BRETa.donorThPosY", donorThPosY);
					donorThWin.close();
				}
				if (!divideParms.batchDivide) {
					donorPosX = donorImg.getWindow().getLocation().getX();
					donorPosY = donorImg.getWindow().getLocation().getY();
					acceptorPosX = acceptorImg.getWindow().getLocation().getX();
					acceptorPosY = acceptorImg.getWindow().getLocation().getY();
					Prefs.set("BRETa.donorPosX", donorPosX);
					Prefs.set("BRETa.donorPosY", donorPosY);
					Prefs.set("BRETa.acceptorPosX", acceptorPosX);
					Prefs.set("BRETa.acceptorPosY", acceptorPosY);
				}
				donorImg.close();
				acceptorImg.close();
				donorThImg.close();
				if (gd.wasCanceled()) {
					ratioImg.close();
					break;
				}
			} else {
				threshold(false);
			}
			IJ.saveString(thUsed, thPath);
			if (ratioImg.isStack()) {
				File file = new File(ratioPath);
				String fileName = file.getName();
				fileName = fileName.substring(0,  fileName.length()-4)+"_s";
				for (int i = 1; i <= ratioImg.getNSlices(); i++) {
					ratioImg.getStack().setSliceLabel(fileName+i, i);
				}
			}
			fs = new FileSaver(ratioImg);
			fs.saveAsTiff(ratioPath);
			ratioImg.close();
		}
		IJ.showStatus("Divide operation complete");
		IJ.showProgress(1, 1);
		if (divideParms.batchDivide) {
			IJ.log("Divide operation complete");
		}
	}
	
	public boolean dialogItemChanged(GenericDialog gd, AWTEvent e) {
		String oldMethod = divideParms.thresholdMethod;
		divideParms.thresholdMethod = gd.getNextChoice();
		if (!oldMethod.equals(divideParms.thresholdMethod)) {
			setVisibleItems(gd);
		}
		divideParms.coefMultMeanROI = (double)gd.getNextNumber();
		divideParms.localThParm1 = (double)gd.getNextNumber();
		divideParms.localThParm2 = (double)gd.getNextNumber();
		divideParms.radiusLocalTh = (double)gd.getNextNumber();
		divideParms.chastagnierGaussianLow = (double)gd.getNextNumber();
		divideParms.chastagnierGaussianHigh = (double)gd.getNextNumber();
		divideParms.overallMinThreshold = (double)gd.getNextNumber();
		divideParms.rangeMin = (double)gd.getNextNumber();
		divideParms.rangeMax = (double)gd.getNextNumber();
		preview = gd.getNextChoice();
		if (!preview.equals(previewChoices[0]) && !divideParms.batchDivide) {
			if (preview.equals(previewChoices[1])) {
				threshold(true);
			} else {
				threshold(false);
			}
			if (donorThWin == null) {
				ImageWindow.setNextLocation((int)donorThPosX, (int)donorThPosY);
				donorThImg.show();
				donorThWin = donorThImg.getWindow();
			} else {
				donorThWin.setImage(donorThImg);
				if (!donorThWin.isVisible()) {
					ImageWindow.setNextLocation((int)donorThPosX, (int)donorThPosY);
					donorThImg.show();
					donorThWin = donorThImg.getWindow();
				}
			}
			if (ratioWin == null) {
				ImageWindow.setNextLocation((int)ratioPosX, (int)ratioPosY);
				ratioImg.show();
				ratioWin = ratioImg.getWindow();
			} else {
				ratioWin.setImage(ratioImg);
				if (!ratioWin.isVisible()) {
					ImageWindow.setNextLocation((int)ratioPosX, (int)ratioPosY);
					ratioImg.show();
					ratioWin = ratioImg.getWindow();
				}
			}
		} else {
			if (ratioWin != null && ratioWin.isVisible()) {
				ratioPosX = ratioWin.getLocation().getX();
				ratioPosY = ratioWin.getLocation().getY();
				Prefs.set("BRETa.ratioPrePosX", ratioPosX);
				Prefs.set("BRETa.ratioPrePosY", ratioPosY);
				ratioWin.close();
			}
			if (donorThWin != null && donorThWin.isVisible()) {
				donorThPosX = donorThWin.getLocation().getX();
				donorThPosY = donorThWin.getLocation().getY();
				Prefs.set("BRETa.donorThPosX", donorThPosX);
				Prefs.set("BRETa.donorThPosY", donorThPosY);
				donorThWin.close();
			}
		}
		return true;
	}
	
	public void setVisibleItems(GenericDialog gd) {
		Component[] cp = gd.getComponents();
		if (divideParms.thresholdMethod.equals("Mean x Coeff")) {
			cp[2].setVisible(true);
			cp[3].setVisible(true);
			cp[4].setVisible(false);
			cp[5].setVisible(false);
			cp[6].setVisible(false);
			cp[7].setVisible(false);
			cp[8].setVisible(false);
			cp[9].setVisible(false);
			cp[10].setVisible(false);
			cp[11].setVisible(false);
			cp[12].setVisible(false);
			cp[13].setVisible(false);
		} else if (divideParms.thresholdMethod.startsWith("AutoLocalTh")) {
			cp[2].setVisible(false);
			cp[3].setVisible(false);
			cp[4].setVisible(true);
			cp[5].setVisible(true);
			cp[6].setVisible(true);
			cp[7].setVisible(true);
			cp[8].setVisible(true);
			cp[9].setVisible(true);
			cp[10].setVisible(false);
			cp[11].setVisible(false);
			cp[12].setVisible(false);
			cp[13].setVisible(false);
		} else if (divideParms.thresholdMethod.endsWith("Chastagnier")) {
			cp[2].setVisible(false);
			cp[3].setVisible(false);
			cp[4].setVisible(false);
			cp[5].setVisible(false);
			cp[6].setVisible(false);
			cp[7].setVisible(false);
			cp[8].setVisible(false);
			cp[9].setVisible(false);
			cp[10].setVisible(true);
			cp[11].setVisible(true);
			cp[12].setVisible(true);
			cp[13].setVisible(true);
		} else {
			cp[2].setVisible(false);
			cp[3].setVisible(false);
			cp[4].setVisible(false);
			cp[5].setVisible(false);
			cp[6].setVisible(false);
			cp[7].setVisible(false);
			cp[8].setVisible(false);
			cp[9].setVisible(false);
			cp[10].setVisible(false);
			cp[11].setVisible(false);
			cp[12].setVisible(false);
			cp[13].setVisible(false);
		}
		if (!divideParms.batchDivide) { // hide preview button in batch mode
			cp[20].setVisible(true);
		} else {
			cp[20].setVisible(false);
		}
		gd.pack();
	}
	
	private void threshold(boolean singleSlice) {
		sb = new StringBuilder();
		sb.append(divideParms.thresholdMethod+"\n");
		int currentSlice[] = {donorImg.getCurrentSlice(),donorThImg.getCurrentSlice(),ratioImg.getCurrentSlice()};
		Roi currentRoi = donorImg.getRoi();
		if (currentRoi != null) {
			donorImg.deleteRoi();
		}
		if (singleSlice) {
			donorMaskImg = donorImg.crop();
			donorThImg = donorImg.crop();
		} else {
			donorMaskImg = donorImg.duplicate();
			donorThImg = donorImg.duplicate();
		}
		if (currentRoi != null) {
			donorImg.restoreRoi();
		}
		ip = donorThImg.getProcessor();
		if (divideParms.thresholdMethod.startsWith("AutoTh")) {
			if (divideParms.thresholdMethod.endsWith("Chastagnier")) {
				ImagePlus gaussianLow = donorThImg.duplicate();
				IJ.run(gaussianLow, "Gaussian Blur...", "sigma="+divideParms.chastagnierGaussianLow+" stack");
				gaussianLow = ic.run("Subtract create stack", donorImg, gaussianLow);
				IJ.run(gaussianLow, BRETAnalyzerProcess.autoThCmd, "method=Li white stack");
				ImagePlus gaussianHigh = donorThImg.duplicate();
				IJ.run(gaussianHigh, "Gaussian Blur...", "sigma="+divideParms.chastagnierGaussianHigh+" stack");
				gaussianHigh = ic.run("Subtract create stack", donorImg, gaussianHigh);
				IJ.run(gaussianHigh, BRETAnalyzerProcess.autoThCmd, "method=Li white stack");
				ic.run("AND stack", gaussianLow, gaussianHigh);
				IJ.run(donorMaskImg, BRETAnalyzerProcess.autoThCmd, "method=Otsu ignore_black ignore_white white stack");
				ic.run("OR stack", donorMaskImg, gaussianLow);
				sb.append(divideParms.chastagnierGaussianLow+"\n"+divideParms.chastagnierGaussianHigh+"\n");
			} else {
				String method = divideParms.thresholdMethod.substring(7);
				Double minSlice, maxSlice;
				for (int iSlice = 1; iSlice <= donorMaskImg.getNSlices(); iSlice++) {
					donorMaskImg.setSlice(iSlice);
					IJ.resetMinAndMax(donorMaskImg);
					IJ.run(donorMaskImg, "Enhance Contrast", "saturated=0.35");
					minSlice = donorMaskImg.getDisplayRangeMin();
					maxSlice = donorMaskImg.getDisplayRangeMax();
					IJ.run(donorMaskImg, "Subtract...", "value="+minSlice+" slice");
					IJ.run(donorMaskImg, "Divide...", "value="+(maxSlice-minSlice)/255+" slice");
				}
				donorMaskImg.setDisplayRange(0, 255);
				IJ.run(donorMaskImg, "8-bit", "");
				IJ.run(donorMaskImg, BRETAnalyzerProcess.autoThCmd, "method="+method+" ignore_black ignore_white white stack");
			}
			IJ.run(donorMaskImg, "Divide...", "value=255 stack");
			if (singleSlice) {
				if (currentRoi != null) donorImg.deleteRoi();
				donorThImg = ic.run("Multiply create", donorImg.crop(), donorMaskImg);
				if (currentRoi != null) donorImg.restoreRoi();
			} else {
				donorThImg = ic.run("Multiply create stack", donorImg, donorMaskImg);
			}
		} else if (divideParms.thresholdMethod.startsWith("AutoLocalTh")) {
			String method = divideParms.thresholdMethod.substring(12);
			Double minSlice, maxSlice;
			for (int iSlice = 1; iSlice <= donorMaskImg.getNSlices(); iSlice++) {
				donorMaskImg.setSlice(iSlice);
				IJ.resetMinAndMax(donorMaskImg);
				IJ.run(donorMaskImg, "Enhance Contrast", "saturated=0.35");
				minSlice = donorMaskImg.getDisplayRangeMin();
				maxSlice = donorMaskImg.getDisplayRangeMax();
				IJ.run(donorMaskImg, "Subtract...", "value="+minSlice+" slice");
				IJ.run(donorMaskImg, "Divide...", "value="+(maxSlice-minSlice)/255+" slice");
			}
			donorMaskImg.setDisplayRange(0, 255);
			IJ.run(donorMaskImg, "8-bit", "");
			IJ.run(donorMaskImg, BRETAnalyzerProcess.autoLocThCmd, "method="+method+" radius="+divideParms.radiusLocalTh
					+" parameter_1="+divideParms.localThParm1+" parameter_2="+divideParms.localThParm2+" white stack");
			IJ.run(donorMaskImg, "Divide...", "value=255 stack");
			if (singleSlice) {
				if (currentRoi != null) donorImg.deleteRoi();
				donorThImg = ic.run("Multiply create", donorImg.crop(), donorMaskImg);
				if (currentRoi != null) donorImg.restoreRoi();
			} else {
				donorThImg = ic.run("Multiply create stack", donorImg, donorMaskImg);
			}
			sb.append(divideParms.localThParm1+"\n"+divideParms.localThParm2+"\n"+divideParms.radiusLocalTh+"\n");
		} else {
			ip = donorThImg.getProcessor();
			FloatPolygon fp;
			if (donorImg.getRoi() != null) {
				fp = donorImg.getRoi().getFloatPolygon();
			} else {
				fp = new FloatPolygon(new float[]{0, donorImg.getWidth(), donorImg.getWidth(), 0}, 
									new float[] {0, 0, donorImg.getHeight(), donorImg.getHeight()});
			}
			sb.append(Arrays.toString(fp.xpoints).replace("[", "").replace("]", "")+"\n");
			sb.append(Arrays.toString(fp.ypoints).replace("[", "").replace("]", "")+"\n");
			if (divideParms.thresholdMethod.equals("Median")) {
				for (int i = 1; i <= donorImg.getNSlices(); i++) {
					donorImg.setSliceWithoutUpdate(i);
					donorThImg.setSliceWithoutUpdate(i);
					istat = donorImg.getStatistics(ImageStatistics.MEDIAN);
					for (int j = 0; j < donorThImg.getWidth(); j++) {
						for (int k = 0; k < donorThImg.getHeight(); k++) {
							if (ip.getPixelValue(j, k) < istat.median) { 
								ip.set(j, k, 0);
							}
						}
					}
				}
			} else if (divideParms.thresholdMethod.equals("Mean x Coeff")) {
				sb.append(divideParms.coefMultMeanROI+"\n");
				for (int i = 1; i <= donorImg.getNSlices(); i++) {
					donorImg.setSliceWithoutUpdate(i);
					donorThImg.setSliceWithoutUpdate(i);
					istat = donorImg.getStatistics(ImageStatistics.MEAN);
					double meanXCoeff = istat.mean * divideParms.coefMultMeanROI;
					for (int j = 0; j < donorThImg.getWidth(); j++) {
						for (int k = 0; k < donorThImg.getHeight(); k++) {
							if (ip.getPixelValue(j, k) < meanXCoeff) { 
								ip.set(j, k, 0);
							}
						}
					}
				}
			}
		}
		// set to 0 all pixels below Minimum threshold
		sb.append(divideParms.overallMinThreshold);
		ip = donorThImg.getProcessor();
		for (int i = 1; i <= donorThImg.getNSlices(); i++) {
			donorThImg.setSlice(i);
			for (int j = 0; j < donorThImg.getWidth(); j++) {
				for (int k = 0; k < donorThImg.getHeight(); k++) {
					if (ip.getPixelValue(j, k) < divideParms.overallMinThreshold) { 
						ip.set(j, k, 0);
					}
				}
			}
		}
		if (singleSlice) {
			donorImg.setSlice(currentSlice[0]);
			acceptorImg.setSlice(currentSlice[0]);
			ratioImg = ic.run("Divide create 32-bit stack", acceptorImg.crop(), donorThImg);
		} else {
			donorImg.setSliceWithoutUpdate(currentSlice[0]);
			donorThImg.setSliceWithoutUpdate(currentSlice[1]);
			ratioImg = ic.run("Divide create 32-bit stack", acceptorImg, donorThImg);
		}
		ratioImg.setTitle("Ratio");
		ip = ratioImg.getProcessor();
		float v;
		for (int z=1; z<=ratioImg.getStackSize();z++) {
			ratioImg.setSliceWithoutUpdate(z);
			for (int y=0; y<ratioImg.getHeight(); y++) {
				for (int x=0; x<ratioImg.getWidth(); x++) {
					v = ip.getPixelValue(x,y);
					if (v>=1000 || v<=0.01) {
						ip.putPixelValue(x, y, Float.NaN);
					}
				}
			}
		}
		ratioImg.setLut(LutLoader.openLut(IJ.getDirectory("luts")+"16_colors.lut"));
		if (!singleSlice) {
			ratioImg.setSliceWithoutUpdate(currentSlice[2]);
		}
		IJ.setMinAndMax(ratioImg, divideParms.rangeMin, divideParms.rangeMax);
		Prefs.set("BRETa.rangeMin", divideParms.rangeMin);
		Prefs.set("BRETa.rangeMax", divideParms.rangeMax);
		thUsed = sb.toString();
	}
	
 	public static String donorToRatio(String filePath, String donorName) {
		File file = new File(filePath);
		String parentFolder = file.getParent();
		String fileName = file.getName();
		int index = fileName.lastIndexOf(".");
		if (index != -1) {
			fileName = fileName.substring(0, index); // remove extension
		}
		index = fileName.lastIndexOf("_clean");
		if (index != -1) {
			fileName = fileName.substring(0, index)+fileName.substring(index+6, fileName.length()); // remove "_clean"
		}
		index = fileName.lastIndexOf(donorName);
		if (index == -1) {
			fileName = fileName+"_Ratio";
		} else {
			fileName = BRETAnalyzerProcess.replaceLast(fileName, donorName, "Ratio"); // replace donor by "Ratio"
		}
		return parentFolder+File.separator+fileName+".tif";
	}
}

class AnalyseProcess implements Runnable, ActionListener, TextListener, ItemListener, WindowListener {
	private static AnalyseProcess instance = null;
	private double framePosX = Prefs.get("BRETa.analyseFramePosX", 0);
	private double framePosY = Prefs.get("BRETa.analyseFramePosY", 0);
	private double frameSizeX = Prefs.get("BRETa.analyseFrameSizeX", 658);
	private double frameSizeY = Prefs.get("BRETa.analyseFrameSizeY", 320);
	private double ratioPosX = Prefs.get("BRETa.ratioPosX", 100);
	private double ratioPosY = Prefs.get("BRETa.ratioPosY", 100);
	private double meansPlotPosX = Prefs.get("BRETa.meansPlotPosX", 100);
	private double meansPlotPosY = Prefs.get("BRETa.meansPlotPosY", 100);
	private double sdPlotPosX = Prefs.get("BRETa.sdPlotPosX", 100);
	private double sdPlotPosY = Prefs.get("BRETa.sdPlotPosY", 500);
	private double resultsPosX = Prefs.get("BRETa.resultsPosX", 400);
	private double resultsPosY = Prefs.get("BRETa.resultsPosY", 200);
	private Window meansPlotWin, sdPlotWin, resultsWin;
	protected Thread t = new Thread(this);
	private ImageCalculator ic = new ImageCalculator();
	private static String donorName = null;
	private static String acceptorName = null;
	private double period_sec = Prefs.get("BRETa.period_sec", 60);
	//private int normalizeSlice = (int)Prefs.get("BRETa.normalizeSlice", 1);
	private String dataFolderName = Prefs.get("BRETa.dataFolderName", "data");
	private final String[] ratioVsIntensityChoices = {"vs intensity", "vs intensity ratio"};
	private String ratioVsIntensityChoice = Prefs.get("BRETa.ratioVsIntensityChoice", "vs intensity");
	private ResultsTable[] rt, rt2;
	//private ImageStatistics istat;
	private Plot means, stdDevs;
	private final String[] plotColors = {"black","blue","green","magenta","orange","red","yellow","gray","cyan","pink"};
	
	private LinkedList<ImagePlus> impList = new LinkedList<ImagePlus>();
	
	private Frame frame;
	private Button addImage, removeImage, clearImageList, showWeighted, plotVsIntensity, doAnalysis, addTag, setTags;
	private List imageList;
	private JList<String> tagList;
	private DefaultListModel<String> tagListModel;
	private Label periodSecLabel, folderNameLabel; // normalizeSliceLabel
	private TextField periodSecField, folderName; // normalizeSliceField
	private int currentSelection = -1;
	
	private final int verticalOffset;
	private final boolean isWindows;
	private OpenDialog od;
	private GenericDialog gd;
	
	protected AnalyseProcess() {
		isWindows = System.getProperty("os.name").startsWith("Windows");
		if (isWindows) {
			verticalOffset = 0;
		} else {
			verticalOffset = 21;
		}
	}
	
	public static AnalyseProcess getInstance() {
		if (instance == null) {
			instance = new AnalyseProcess();
		}
		return instance;
	}
	
	public void update(String donorName, String acceptorName) {
		AnalyseProcess.donorName = donorName;
		AnalyseProcess.acceptorName = acceptorName;
	}
	
	public void run() {
		if (frame == null) {
			frame = new Frame("Analyse");
			frame.setLayout(new GridBagLayout());
			periodSecLabel = new Label("Image period (s)", Label.CENTER);
			//normalizeSliceLabel = new Label("Normalize slice", Label.CENTER);
			folderNameLabel = new Label("Folder name", Label.CENTER);
			folderName = new TextField(dataFolderName, 12);
			folderName.addTextListener(this);
			Panel folderNamePanel = new Panel();
			folderNamePanel.setLayout(new GridLayout(1,2));
			folderNamePanel.add(folderNameLabel);
			folderNamePanel.add(folderName);
			periodSecField = new TextField(String.valueOf(period_sec));
			periodSecField.addTextListener(this);
			//normalizeSliceField = new TextField(String.valueOf(normalizeSlice));
			//normalizeSliceField.addTextListener(this);
			addImage = new Button("Add image");
			addImage.addActionListener(this);
			removeImage = new Button("Remove selected");
			removeImage.addActionListener(this);
			clearImageList = new Button("Remove all");
			clearImageList.addActionListener(this);
			showWeighted = new Button("Display weighted ratio");
			showWeighted.addActionListener(this);
			plotVsIntensity = new Button("Plot ratio vs intensity");
			plotVsIntensity.addActionListener(this);
			doAnalysis = new Button("Do analysis");
			doAnalysis.addActionListener(this);
			imageList = new List(12, false);
			imageList.addItemListener(this);
			imageList.addActionListener(this);
			addTag = new Button("Tag selected ROI(s)");
			addTag.addActionListener(this);
			setTags = new Button("Set ROI tags");
			setTags.addActionListener(this);
			tagList = new JList<String>(Prefs.get("BRETa.tagList", "soma;dendrite;spine").split(";"));
			tagList.setVisibleRowCount(0);
			tagList.setSelectionMode(ListSelectionModel.SINGLE_SELECTION);
			tagList.setLayoutOrientation(JList.HORIZONTAL_WRAP);
			tagList.setBorder(BorderFactory.createLineBorder(Color.gray));
			DefaultListCellRenderer renderer = (DefaultListCellRenderer)tagList.getCellRenderer();  
			renderer.setHorizontalAlignment(JLabel.CENTER);  
			setTagList(Prefs.get("BRETa.tagList", "soma;dendrite;spine"));
			Panel lists = new Panel();
			lists.setLayout(new GridBagLayout());
			addThingContainer(lists, imageList,				0, 0,	1, 1,	1, 1,	0, 0);
			addThingContainer(lists, tagList,				0, 1,	1, 1,	1, 0,	0, 0);
			addThingContainer(frame, lists,					2, 0,	1, 20,	2000, 1,	300, 0);
			addThingContainer(frame, addImage,				0, 1,	2, 1,	1, 1,	0, 0);
			addThingContainer(frame, removeImage,			0, 2,	2, 1,	1, 1,	0, 0);
			addThingContainer(frame, clearImageList,		0, 3,	2, 1,	1, 1,	0, 0);
			addThingContainer(frame, showWeighted,			0, 4,	2, 1,	1, 1,	0, 0);
			addThingContainer(frame, plotVsIntensity,		0, 5,	2, 1,	1, 1,	0, 0);
			addThingContainer(frame, periodSecLabel,		0, 6,	1, 1,	2, 1,	0, 0);
			addThingContainer(frame, periodSecField,		1, 6,	1, 1,	1, 1,	0, 0);
			//addThingContainer(frame, normalizeSliceLabel,	0, 7,	1, 1,	2, 1,	0, 0);
			//addThingContainer(frame, normalizeSliceField,	1, 7,	1, 1,	1, 1,	0, 0);
			addThingContainer(frame, folderNamePanel, 		0, 8,	2, 1,	1, 1,	0, 0);
			addThingContainer(frame, doAnalysis,			0, 9,	2, 1,	1, 1,	0, 0);
			addThingContainer(frame, addTag, 				0, 10,	2, 1,	1, 1, 	0, 0);
			addThingContainer(frame, setTags, 				0, 11,	2, 1,	1, 1, 	0, 0);
			frame.setLocation((int)framePosX, (int)framePosY+verticalOffset);
	        frame.pack();
			frame.setSize((int)frameSizeX, (int)frameSizeY);
	        frame.setVisible(true);
	        frame.addWindowListener(this);
		} else {
			frame.toFront();
		}
	}
	
	private void addThingContainer(
		Container f, 
		Component b, 
		int gridx, 
		int gridy, 
		int gridwidth, 
		int gridheight, 
		int weightx, 
		int weighty, 
		int ipadx,
		int ipady
	){
		GridBagConstraints c = new GridBagConstraints();
		c.fill = GridBagConstraints.BOTH;
		c.gridx = gridx;
		c.gridy = gridy;
		c.gridwidth = gridwidth;
		c.gridheight = gridheight;
		c.weightx = weightx;
		c.weighty = weighty;
		c.ipadx = ipadx;
		c.ipady = ipady;
		f.add(b, c);
	}
	
	public void actionPerformed(ActionEvent e) {
		Object b = e.getSource();
		if (b == addImage) { // add an image to the list if not already there
			IJ.showStatus("Select ratio image to open.");
			od = new OpenDialog("Select ratio image to open.");
			String newPath = od.getPath();
			if (newPath != null) {
				if (newPath.endsWith(".txt")) {
					String[] pathList = IJ.openAsString(newPath).split("\n");
					for (int i = 0; i < pathList.length-1; i++) {
						String pathToOpen = buildPathFromTxt(pathList[i], pathList[pathList.length-1], newPath);
						addImage(pathToOpen);
					}
				} else {
					addImage(newPath);
				}
			}
		} else if (b == removeImage) { // remove currently selected image from the list
			int index = imageList.getSelectedIndex();
			closeCurrentImage();
			if (index != -1) {
				impList.remove(index);
				imageList.remove(index);
			}
		} else if (b == clearImageList) { // empty the list of images
			closeCurrentImage();
			closeAllImages();
			getRM(true).reset();
		} else if (b == showWeighted) { // display the weighting of current selection
			if (currentSelection != -1) {
				saveROIs(currentSelection);
				impList.get(currentSelection).deleteRoi();
				WeightAction wa = new WeightAction(impList.get(currentSelection), imageList.getItem(currentSelection), donorName);
				wa.getThread().start();
			}
		} else if (b == plotVsIntensity) { // plot ratio vs intensity of current selection
			if (currentSelection != -1) {
				closeCurrentImage();
			}
			if (impList.size() > 0) {
				PlotVsIntensity pvi = new PlotVsIntensity();
				pvi.getThread().start();
			}
		} else if (b == doAnalysis) { // compute and display the analysis
			closeCurrentImage();
			analysis();
		} else if (b == imageList) { // when double clicking on an item of the list, it is closed (if open) and displayed back
			int n = currentSelection;
			closeCurrentImage();
			currentSelection = n;
			selectImage(currentSelection);
		} else if (b == setTags) { // manage the tags list
			String tags = getTagList();
			gd = new GenericDialog("Tag list");
			gd.addStringField("Tags separated by ;", tags, 42);
			gd.showDialog();
			tags = gd.getNextString();
			setTagList(tags);
		} else if (b == addTag) { // add currently selected tag to currently selected ROI(s)
			String tag = tagList.getSelectedValue();
			int[] indexes = getRM(true).getSelectedIndexes();
			for (int i : indexes) {
				getRM(true).rename(i, tag);
			}
		}
	}
	
	public void textValueChanged(TextEvent e) {
		Object b = e.getSource();
		try {
			if (b == periodSecField) {
				period_sec = Double.parseDouble(periodSecField.getText());
				Prefs.set("BRETa.period_sec", period_sec);
			//} else if (b == normalizeSliceLabel) {
			//	normalizeSlice = Integer.parseInt(normalizeSliceLabel.getText());
			//	Prefs.set("BRETa.normalizeSlice", normalizeSlice);
			} else if (b == folderName) {
				dataFolderName = folderName.getText();
				Prefs.set("BRETa.dataFolderName", dataFolderName);
			}
		} catch (NumberFormatException n) {}
	}
	
	public void itemStateChanged(ItemEvent e) {
		if (e.getStateChange() == ItemEvent.SELECTED) {
			closeCurrentImage();
			int index = imageList.getSelectedIndex();
			selectImage(index);
			currentSelection = index;
			frame.toFront();
		}
	}
	
	private void addImage(String newPath) {
		closeCurrentImage();
		if (newPath != null) {
			currentSelection = pathIndex(newPath);
			if (currentSelection == -1) {
				ImagePlus imp = IJ.openImage(newPath);
				if (imp != null) {
					impList.add(imp);
					imageList.add(newPath);
					currentSelection = imageList.getItemCount()-1;
				}
			}
			selectImage(currentSelection);
		}
	}
	
	private void closeAllImages() {
		imageList.removeAll();
		for (ImagePlus imageplus : impList) {
			imageplus.close();
		}
		impList.clear();
	}
	
	private void analysis() {
		if (impList.size() > 0) {
			int[] nbROIs = new int[impList.size()+1];
			int totROIs;
			int maxSlices = 0;
			getRM(true).reset();
			int impIndex = 0;
			for (final ImagePlus imp : impList) {
				if (maxSlices < imp.getNSlices()) {
					maxSlices = imp.getNSlices();
				}
				loadROIs(impIndex);
				nbROIs[impIndex+1] = getRM(true).getCount();
				impIndex++;
			}
			if (getRM(true).getCount() > 0) {
				// Prepare results folder
				String resultsFolder = savePaths();
				File f = new File(resultsFolder);
				if (f.exists()) {
					gd = new GenericDialog("Folder name");
					gd.addMessage("The folder in which results will be saved already exists.\nChange it to save in a new one. Keep it to overwrite results."+
								"\nChanging to an existing one will overwrite it without checking again.");
					gd.addStringField("Folder name", dataFolderName, 42);
					gd.showDialog();
					if (gd.wasCanceled()) {
						return;
					}
					dataFolderName = gd.getNextString();
					Prefs.set("BRETa.dataFolderName", dataFolderName);
					folderName.setText(dataFolderName);
					resultsFolder = savePaths();
					f = new File(resultsFolder);
				}
				// Init variables
				totROIs = nbROIs[nbROIs.length-1];
				int[] nSlices = new int[totROIs];
				int[] imageID = new int[totROIs];
				double[][] results = new double[2*totROIs][maxSlices];
				double[][] results2 = new double[2*totROIs][maxSlices];
				double[] meanLinePlot = new double[maxSlices];
				double[] stdDevLinePlot = new double[maxSlices];
				double[] timingPlot = new double[maxSlices];
				int roiIndex;
				int[] tagIndexes = new int[totROIs];
				int[] imgROIIndexes = new int[totROIs];
				int nbTags = tagListModel.getSize();
				String[] shortTags = getShortTags();
				rt = new ResultsTable[nbTags+1];
				rt2 = new ResultsTable[nbTags+1];
				String titleCol,titleCol2;
				for (int i = 0; i < nbTags+1; i++) {
					rt[i] = new ResultsTable();
					rt[i].setPrecision(6);
					rt[i].showRowNumbers(false);
					rt2[i] = new ResultsTable();
					rt2[i].setPrecision(6);
					rt2[i].showRowNumbers(false);
				}
				// recover timings
				if (period_sec == 0) {
					IJ.showStatus("Select txt file containing timings in seconds, one value per line");
					od = new OpenDialog("Select txt file containing timings in seconds, one value per line");
					String path = od.getPath();
					if (path == null) { // Dialog canceled
						IJ.log("Timings file dialog selection cancelled -> Do analysis cancelled.");
						return;
					}
					String[] timings = IJ.openAsString(path).split("\n");
					int offset = 0;
					for (int slice = 0; slice < Math.min(maxSlices+offset, timings.length); slice++) {
						try {
							Double.parseDouble(timings[slice]);
						} catch(NumberFormatException e) {
							offset++;
							continue;
						}
						for (int i = 0; i <= nbTags; i++) {
							rt[i].setValue("t(mn)", slice-offset, Double.parseDouble(timings[slice])/60);
							rt2[i].setValue("t(mn)", slice-offset, Double.parseDouble(timings[slice])/60);
						}
					}
				} else {
					for (int slice = 0; slice < maxSlices; slice++) {
						for (int i = 0; i <= nbTags; i++) {
							rt[i].setValue("t(mn)", slice, slice*period_sec/60);
							rt2[i].setValue("t(mn)", slice, slice*period_sec/60);
						}
					}
				}
				impIndex = 0;
				// Do measures
				double thMin = 0.01, thMax = 65535;
				for (final ImagePlus imp : impList) {
					LUT lut = imp.getProcessor().getLut();
					imp.getProcessor().setThreshold(thMin, thMax, ImageProcessor.NO_LUT_UPDATE);
					
					// Measure mean and sd of ratios
					IJ.run("Set Measurements...", "mean standard limit redirect=None decimal=3");
					ResultsTable rtx = ResultsTable.getResultsTable();
					for (roiIndex = nbROIs[impIndex]; roiIndex < nbROIs[impIndex+1]; roiIndex++) {
						tagIndexes[roiIndex] = getTagIndex(getRM(true).getName(roiIndex));
						imgROIIndexes[roiIndex] = roiIndex-nbROIs[impIndex]+1;
						getRM(true).select(imp, roiIndex);
						nSlices[roiIndex] = imp.getNSlices();
						imageID[roiIndex] = impIndex+1;
						for (int i = 0; i < nSlices[roiIndex]; i++) {
							imp.setSliceWithoutUpdate(i+1);
							IJ.run(imp, "Measure", "");
							results[roiIndex][i] = rtx.getValue("Mean", rtx.size()-1);
							results[roiIndex+totROIs][i] = rtx.getValue("StdDev", rtx.size()-1);
						}
					}
					imp.getProcessor().setLut(lut); // forced to set back LUT because setThreshold started removing it in ImageJ 1.52e.
					// and pushed after the measurements, because setLUT cancels the setThreshold...
					
					// Measure ratio of means and nPixels
					String[] donorAcceptor = ratioToDonorAcceptor(imageList.getItem(impIndex));
					File f1 = new File(donorAcceptor[0]), f2 = new File(donorAcceptor[1]);
					boolean measureRatioOfMeans = f1.exists() && f2.exists();
					if (measureRatioOfMeans) {
						IJ.run("Set Measurements...", "mean integrated redirect=None decimal=3");
						imp.killRoi();
						ImagePlus mask = imp.duplicate(), donorImp, acceptorImp;
						ImageProcessor ip1, ip2;
						float value;
						int width = mask.getWidth();
				        int height = mask.getHeight();
						int size = width*height;
						ImageStack stack1 = mask.getStack();
						ImageStack stack2 = new ImageStack(width, height);
				        for (int i=1; i<=mask.getNSlices(); i++) {
				            IJ.showProgress(i, mask.getNSlices());
				            String label = stack1.getSliceLabel(i);
				            ip1 = stack1.getProcessor(i);
				            ip2 = new ByteProcessor(width, height);
				            for (int j=0; j<size; j++) {
				                value = ip1.getf(j);
				                if (value>=thMin && value<=thMax)
				                    ip2.set(j, 1);
				                else
				                    ip2.set(j, 0);
				            }
				            stack2.addSlice(label, ip2);
				        }
				        mask.setStack(null, stack2);
				        donorImp = IJ.openImage(donorAcceptor[0]);
				        ic.run("Multiply stack", donorImp, mask);
				        acceptorImp = IJ.openImage(donorAcceptor[1]);
				        ic.run("Multiply stack", acceptorImp, mask);
				        double intDenDonor, intDenAcceptor, intDenMask;
				        for (roiIndex = nbROIs[impIndex]; roiIndex < nbROIs[impIndex+1]; roiIndex++) {
				        	getRM(true).select(donorImp, roiIndex);
				        	getRM(true).select(acceptorImp, roiIndex);
				        	getRM(true).select(mask, roiIndex);
				        	for (int i = 0; i < nSlices[roiIndex]; i++) {
				        		donorImp.setSliceWithoutUpdate(i+1);
				        		IJ.run(donorImp, "Measure", "");
				        		intDenDonor = rtx.getValue("IntDen", rtx.size()-1);
				        		acceptorImp.setSliceWithoutUpdate(i+1);
				        		IJ.run(acceptorImp, "Measure", "");
				        		intDenAcceptor = rtx.getValue("IntDen", rtx.size()-1);
				        		mask.setSliceWithoutUpdate(i+1);
				        		IJ.run(mask, "Measure", "");
				        		intDenMask = rtx.getValue("IntDen", rtx.size()-1);
				        		results2[roiIndex][i] = intDenAcceptor / intDenDonor;
								results2[roiIndex+totROIs][i] = intDenMask;
				        	}
				        }
				        donorImp.changes = false;
				        donorImp.close();
				        acceptorImp.changes = false;
				        acceptorImp.close();
				        mask.close();
					}
					impIndex++;
				}
		        ResultsTable.getResultsWindow().close(false);
				// Save results in files
				for (int col = 0; col < totROIs; col++) {
					titleCol = "mean"+imageID[col]+shortTags[tagIndexes[col]]+imgROIIndexes[col];
					for (int slice = 0; slice < nSlices[col]; slice++) {
						rt[nbTags].setValue(titleCol, slice, results[col][slice]);
						rt[tagIndexes[col]].setValue(titleCol, slice, results[col][slice]); // add to tag specific table or overwrite if no tag
						rt2[nbTags].setValue(titleCol, slice, results2[col][slice]);
						rt2[tagIndexes[col]].setValue(titleCol, slice, results2[col][slice]); // add to tag specific table or overwrite if no tag
					}
				}
				for (int col = 0; col < totROIs; col++) {
					titleCol = "sd"+imageID[col]+shortTags[tagIndexes[col]]+imgROIIndexes[col];
					titleCol2 = "area"+imageID[col]+shortTags[tagIndexes[col]]+imgROIIndexes[col];
					for (int slice = 0; slice < nSlices[col]; slice++) {
						rt[nbTags].setValue(titleCol, slice, results[col+totROIs][slice]);
						rt[tagIndexes[col]].setValue(titleCol, slice, results[col+totROIs][slice]); // add to tag specific table or overwrite if no tag
						rt2[nbTags].setValue(titleCol2, slice, results2[col+totROIs][slice]);
						rt2[tagIndexes[col]].setValue(titleCol2, slice, results2[col+totROIs][slice]); // add to tag specific table or overwrite if no tag
					}
				}
				if (!f.exists()) {f.mkdirs();}
				rt[nbTags].save(resultsFolder+dataFolderName+"_MeanOfRatios.csv");
				rt[nbTags].save(resultsFolder+dataFolderName+"_MeanOfRatios.xls");
				rt2[nbTags].save(resultsFolder+dataFolderName+"_RatioOfMeans.csv");
				rt2[nbTags].save(resultsFolder+dataFolderName+"_RatioOfMeans.xls");
				ImageWindow.setNextLocation((int)resultsPosX, (int)resultsPosY);
				rt[nbTags].show("Analyse results means of ratio");
				ImageWindow.setNextLocation((int)resultsPosX, (int)resultsPosY);
				rt2[nbTags].show("Analyse results ratio of means");
				resultsWin = WindowManager.getWindow("Analyse results means of ratio");
				resultsWin.setVisible(true);
				resultsWin.addWindowListener(this);
				for (int i = 0; i < nbTags; i++) {
					if (rt[i].getLastColumn() > 1) {
						rt[i].save(resultsFolder+dataFolderName+"_"+tagListModel.getElementAt(i)+"_MeanOfRatios.csv");
						rt[i].save(resultsFolder+dataFolderName+"_"+tagListModel.getElementAt(i)+"_MeanOfRatios.xls");
						rt2[i].save(resultsFolder+dataFolderName+"_"+tagListModel.getElementAt(i)+"_RatioOfMeans.csv");
						rt2[i].save(resultsFolder+dataFolderName+"_"+tagListModel.getElementAt(i)+"_RatioOfMeans.xls");
					}
				}
				// Display plots
				String legend = "";
				for (int i = 0; i < maxSlices; i++) {
					timingPlot[i] = rt[nbTags].getValue("t(mn)", i);
				}
				means = new Plot("Means","t (mn)","Mean");
				stdDevs = new Plot("Standard deviations","t (mn)","Standard deviation");
				for (int i = 0; i < totROIs; i++) {
					for (int j = 0; j < maxSlices; j++) {
						meanLinePlot[j] = results[i][j];
						stdDevLinePlot[j] = results[i+totROIs][j];
					}
					legend = legend+imageID[i]+shortTags[tagIndexes[i]]+imgROIIndexes[i]+"\n";
					means.setColor(plotColors[i%plotColors.length]);
					means.add("line", timingPlot, meanLinePlot);
					stdDevs.setColor(plotColors[i%plotColors.length]);
					stdDevs.add("line", timingPlot, stdDevLinePlot);
				}
				means.setColor("black");
				means.setLegend(legend, Plot.AUTO_POSITION);
				if (meansPlotWin != null) {
					meansPlotWin.dispose();
				}
				ImageWindow.setNextLocation((int)meansPlotPosX, (int)meansPlotPosY);
				meansPlotWin = means.show();
				means.setLimitsToFit(true);
				meansPlotWin.addWindowListener(this);
				stdDevs.setColor("black");
				stdDevs.setLegend(legend, Plot.AUTO_POSITION);
				if (sdPlotWin != null) {
					sdPlotWin.dispose();
				}
				ImageWindow.setNextLocation((int)sdPlotPosX, (int)sdPlotPosY);
				sdPlotWin = stdDevs.show();
				stdDevs.setLimitsToFit(true);
				sdPlotWin.addWindowListener(this);
				// Save images with ROIs
				impIndex = 0;
				roiIndex = 0;
				FileSaver fs;
				Overlay over;
				Roi roi;
				for (final ImagePlus imp : impList) {
					over = new Overlay();
					for (; roiIndex < nbROIs[impIndex+1]; roiIndex++) {
						roi = getRM(true).getRoi(roiIndex);
						roi.setPosition(0);
						roi.setStrokeWidth(2);
						over.add(roi, shortTags[tagIndexes[roiIndex]]+imgROIIndexes[roiIndex]);
					}
					over.drawLabels(true);
					over.drawNames(true);
					over.drawBackgrounds(true);
					over.setLabelColor(new Color(0, 0, 255));
					over.setStrokeColor(new Color(0, 0, 255));
					over.setLabelFont(new Font("Helvetica Bold", Font.BOLD, 12));
					//imp.setSliceWithoutUpdate(normalizeSlice);
					imp.setOverlay(over);
					fs = new FileSaver(imp.flatten());
					imp.setOverlay(null);
					impIndex++;
					fs.saveAsPng(resultsFolder+"Image"+impIndex+".png");
				}
				getRM(true).reset();
				IJ.log("Results saved in folder "+resultsFolder);
			} else {
				IJ.log("No regions to do analysis on");
			}
		} else {
			IJ.log("No images to do analysis on");
		}
	}
	
	private String savePaths() {
		String[] paths = imageList.getItems();
		String folderName = getCommonAncestorFolder(paths)+dataFolderName;
		String path = folderName+"_paths.txt";
		String res = "";
		for (String str : paths) {res += str+"\n";}
		res += path;
		IJ.saveString(res, path);
		return folderName+File.separator;
	}
	
	public static String getCommonAncestorFolder(String[] pathList) {
		// I don't check for case pathList.length == 0 because it is called only by "Do Analysis" which runs only for at least one image.
		String res = "";
		File f = new File(pathList[0]);
		if (pathList.length == 1) {
			res = f.getParent()+File.separator;
		} else {
			String[] partsToCompare;
			String[] parts = pathList[0].replace('\\', '/').split("/");
			int commonParts = parts.length;
			for (int i = 1; i < pathList.length; i++) {
				partsToCompare = pathList[i].replace('\\', '/').split("/");
				int limit = Math.min(commonParts, partsToCompare.length);
				for (int j = 0; j < limit; j++) {
					if (!parts[j].equals(partsToCompare[j])) {
						System.out.println("\""+parts[j]+"\" doesn't match \""+partsToCompare[j]+"\"");
						commonParts = j;
						break;
					}
				}
			}
			if (commonParts == 0) {
				res = f.getParent()+File.separator;
			} else {
				for (int i = 0; i < commonParts; i++) {
					res += parts[i]+File.separator;
				}
			}
		}
		return res;
	}
	
	private String buildPathFromTxt(String imgPath, String txtPath, String txtActualPath) {
		String res = "";
		String[] imgParts = imgPath.replace('\\', '/').split("/");
		String[] txtParts = txtPath.replace('\\', '/').split("/");
		String[] actualParts = txtActualPath.replace('\\', '/').split("/");
		int commonLength = 0;
		for (int i = 0; i < Math.min(imgParts.length, txtParts.length); i++) {
			if (imgParts[i].equals(txtParts[i])) {
				commonLength++;
			} else {
				break;
			}
		}
		for (int i = 0; i < actualParts.length-(txtParts.length-commonLength); i++) {
			res += actualParts[i] + File.separator;
		}
		for (int i = commonLength; i < imgParts.length-1; i++) {
			res += imgParts[i] + File.separator;
		}
		res += imgParts[imgParts.length-1];
		try {
			File f = new File(res);
			res = f.getCanonicalPath();
		} catch (IOException e) {
		}
		return res;
	}
	
	class PlotVsIntensity implements Runnable {
		private Thread t;
		String logSuffix, directory, nameWithoutExt, logPath;
		File log;
		double vsIntaPosX = Prefs.get("BRETa.vsIntaPosX", 100);
		double vsIntaPosY = Prefs.get("BRETa.vsIntaPosY", 400);
		double vsIntbPosX = Prefs.get("BRETa.vsIntbPosX", 100);
		double vsIntbPosY = Prefs.get("BRETa.vsIntbPosY", 700);
		double vsIntDiaPosX = Prefs.get("BRETa.vsIntDiaPosX", 700);
		double vsIntDiaPosY = Prefs.get("BRETa.vsIntDiaPosY", 240);
		boolean single, logExists, changeImage;
		int nbROIs, logIndex;
		String[] oldLogLines, newLogLines;
		String[] imgPaths = new String[2];
		ImagePlus[] intensities = new ImagePlus[2];
		PrintWriter writer;
		FloatPolygon fp;
		LinkedList<double[]> data = new LinkedList<double[]>();
		double[] dataChunk;
		ImageStatistics istat;
		public Thread getThread() {
			return t;
		}
		public PlotVsIntensity() {
			this.t = new Thread(this);
		}
		public void run() {
			gd = new GenericDialog("Plot 3D options");
			gd.addChoice("Plot data", ratioVsIntensityChoices, ratioVsIntensityChoices[0]);
			gd.showDialog();
			if (gd.wasCanceled()) {
				return;
			}
			ratioVsIntensityChoice = gd.getNextChoice();
			Prefs.set("BRETa.ratioVsIntensityChoice", ratioVsIntensityChoice);
			single = ratioVsIntensityChoice.equals(ratioVsIntensityChoices[0]);
			if (single) {
				logSuffix = "_vsInt.txt";
			} else {
				logSuffix = "_vsIntRatio.txt";
			}
			for (int i = 0; i < impList.size(); i++) {
				LUT lut = impList.get(i).getProcessor().getLut();
				selectImage(i);
				nbROIs = getRM(true).getCount();
				directory = impList.get(i).getOriginalFileInfo().directory;
				nameWithoutExt = impList.get(i).getOriginalFileInfo().fileName;
				int extIndex = nameWithoutExt.lastIndexOf('.');
				if (extIndex > 0) {
					nameWithoutExt = nameWithoutExt.substring(0, extIndex);
				}
				logPath = directory + nameWithoutExt + logSuffix;
				log = new File(logPath);
				logExists = false;
				oldLogLines = new String[0];
				if (log.exists()) {
					logExists = true;
					oldLogLines = IJ.openAsString(logPath).split("\n");
					imgPaths[0] = buildAbsolutePath(logPath, oldLogLines[0]);
					File imageLogged = new File(imgPaths[0]);
					if (!imageLogged.exists()) {
						logExists = false;
					}
					if (!single) {
						imgPaths[1] = buildAbsolutePath(logPath, oldLogLines[1]);
						imageLogged = new File(imgPaths[1]);
						if (!imageLogged.exists()) {
							logExists = false;
						}
					}
				}
				if (!logExists) {
					imgPaths = getImgPaths(single);
					if (imgPaths == null) {
						IJ.log("Plot vs intensity canceled");
						return;
					}
				}
				intensities = openVsIntensity(single, imgPaths);
				ImageWindow.setNextLocation((int)vsIntaPosX, (int)vsIntaPosY);
				intensities[0].show();
				if (!single) {
					ImageWindow.setNextLocation((int)vsIntbPosX, (int)vsIntbPosY);
					intensities[1].show();
					newLogLines = new String[2+6*nbROIs];
				} else {
					newLogLines = new String[1+3*nbROIs];
				}
				for (int j = 0; j < nbROIs; j++) {
					WindowManager.setCurrentWindow(impList.get(i).getWindow());
					getRM(true).select(impList.get(i), j);
					if (logExists) {
						if (!placeROIsFromLog(single, oldLogLines, j, intensities)) {
							copyROIs(single, intensities, j);
						}
					} else {
						copyROIs(single, intensities, j);
					}
					changeImage = true;
					while (changeImage) {
						//gd = new NonBlockingGenericDialog("Regions adjustment");
						//gd.addMessage("Make sure that the regions are well placed then click OK."
						//		+"\nCheck \"Change image(s)\" to place regions on newly selected image(s).");
						//gd.addCheckbox("Change image(s)", false);
						////gd.setModalityType(ModalityType.DOCUMENT_MODAL);
						//gd.setAlwaysOnTop(true);
						//gd.setLocation((int)vsIntDiaPosX, (int)vsIntDiaPosY);
						//gd.showDialog();
						//changeImage = gd.getNextBoolean();
						//vsIntDiaPosX = gd.getX();
						//vsIntDiaPosY = gd.getY()+verticalOffset;
						//Prefs.set("BRETa.vsIntDiaPosX", vsIntDiaPosX);
						//Prefs.set("BRETa.vsIntDiaPosY", vsIntDiaPosY);
						
						WaitForUserDialog.setNextLocation((int)vsIntDiaPosX, (int)vsIntDiaPosY);
						WaitForUserDialog wfud = new WaitForUserDialog("Regions adjustment", "Check regions then click OK.\nPress escape to change image.");
						wfud.show();
						vsIntDiaPosX = wfud.getLocation().getX();
						vsIntDiaPosY = wfud.getLocation().getY();
						Prefs.set("BRETa.vsIntDiaPosX", vsIntDiaPosX);
						Prefs.set("BRETa.vsIntDiaPosY", vsIntDiaPosY);
						changeImage = wfud.escPressed();
						
						vsIntaPosX = intensities[0].getWindow().getLocation().getX();
						vsIntaPosY = intensities[0].getWindow().getLocation().getY();
						Prefs.set("BRETa.vsIntaPosX", vsIntaPosX);
						Prefs.set("BRETa.vsIntaPosY", vsIntaPosY);
						if (!single) {
							vsIntbPosX = intensities[1].getWindow().getLocation().getX();
							vsIntbPosY = intensities[1].getWindow().getLocation().getY();
							Prefs.set("BRETa.vsIntbPosX", vsIntbPosX);
							Prefs.set("BRETa.vsIntbPosY", vsIntbPosY);
						}
						//if (gd.wasCanceled()) {
						//	intensities[0].close();
						//	if (!single) {
						//		intensities[1].close();
						//	}
						//	return;
						//}
						if (changeImage) {
							intensities[0].close();
							if (!single) {
								intensities[1].close();
							}
							imgPaths = getImgPaths(single);
							if (imgPaths == null) {
								IJ.log("Plot vs intensity canceled");
								return;
							}
							intensities = openVsIntensity(single, imgPaths);
							ImageWindow.setNextLocation((int)vsIntaPosX, (int)vsIntaPosY);
							intensities[0].show();
							if (!single) {
								ImageWindow.setNextLocation((int)vsIntbPosX, (int)vsIntbPosY);
								intensities[1].show();
							}
							copyROIs(single, intensities, j);
						} else {
							impList.get(i).getProcessor().setThreshold(0.01, 65535, ImageProcessor.NO_LUT_UPDATE);
							dataChunk = new double[impList.get(i).getNSlices()+1];
							WindowManager.setCurrentWindow(impList.get(i).getWindow());
							getRM(true).select(impList.get(i), j);
							for (int k = 1; k <= impList.get(i).getNSlices(); k++) {
								impList.get(i).setSlice(k);
								istat = impList.get(i).getStatistics(ImageStatistics.MEAN+ImageStatistics.LIMIT);
								dataChunk[k] = istat.mean;
							}
							WindowManager.setCurrentWindow(intensities[0].getWindow());
							istat = intensities[0].getStatistics(ImageStatistics.MEAN+ImageStatistics.LIMIT);
							dataChunk[0] = istat.mean;
							newLogLines[0] = buildRelativePath(logPath, intensities[0].getOriginalFileInfo().directory+intensities[0].getOriginalFileInfo().fileName);
							logIndex = 1+j*3;
							if (!single) {
								WindowManager.setCurrentWindow(intensities[1].getWindow());
								istat = intensities[1].getStatistics(ImageStatistics.MEAN+ImageStatistics.LIMIT);
								dataChunk[0] = dataChunk[0] / istat.mean;
								newLogLines[1] = buildRelativePath(logPath, intensities[1].getOriginalFileInfo().directory+intensities[1].getOriginalFileInfo().fileName);
								logIndex = logIndex * 2;
								fp = intensities[1].getRoi().getFloatPolygon();
								newLogLines[logIndex+3] = Integer.toString(intensities[1].getCurrentSlice());
								newLogLines[logIndex+4] = Arrays.toString(fp.xpoints).replace("[", "").replace("]", "");
								newLogLines[logIndex+5] = Arrays.toString(fp.ypoints).replace("[", "").replace("]", "");
								WindowManager.setCurrentWindow(intensities[0].getWindow());
							}
							fp = intensities[0].getRoi().getFloatPolygon();
							newLogLines[logIndex] = Integer.toString(intensities[0].getCurrentSlice());
							newLogLines[logIndex+1] = Arrays.toString(fp.xpoints).replace("[", "").replace("]", "");
							newLogLines[logIndex+2] = Arrays.toString(fp.ypoints).replace("[", "").replace("]", "");
							data.add(dataChunk);
							impList.get(i).getProcessor().setLut(lut); // forced to set back LUT because setThreshold started removing it in ImageJ 1.52e.
						}
					}
				}
				try {
					writer = new PrintWriter(log, "UTF-8");
					for (int j = 0; j < newLogLines.length; j++) {
						writer.println(newLogLines[j]);
					}
					writer.close();
				} catch (FileNotFoundException e) {
					IJ.log("File not found, intensity regions not written");
				} catch (UnsupportedEncodingException e) {
					IJ.log("Unsupported encoding, intensity regions not written");
				}
				try {
					intensities[0].close();
				} catch (java.lang.NullPointerException ex) {}
				if (!single) {
					try {
						intensities[1].close();
					} catch (java.lang.NullPointerException ex) {}
				}
				closeCurrentImage();
			}
			if (data.size() > 0) {
				ListIterator<double[]> it = data.listIterator(0);
				double minIntensity = Double.MAX_VALUE, maxIntensity = Double.MIN_VALUE, minValue = Double.MAX_VALUE, maxValue = Double.MIN_VALUE;
				int nbValMax = Integer.MIN_VALUE;
				double[] xValues = new double[data.size()];
				double[] yValues = new double[data.size()];
				int index = 0;
				while (it.hasNext()) {
					dataChunk = it.next();
					minIntensity = Math.min(minIntensity, dataChunk[0]);
					maxIntensity = Math.max(maxIntensity, dataChunk[0]);
					nbValMax = Math.max(nbValMax, dataChunk.length);
					xValues[index] = dataChunk[0];
					yValues[index] = dataChunk[1];
					index++;
				}
				StringBuilder sb = new StringBuilder();
				if (nbValMax == 2) { // trace plot
					Plot plot;
					if (single) {
						plot = new Plot("BRET Ratio vs intensity", "Intensity", "BRET Ratio");
					} else {
						plot = new Plot("BRET Ratio vs intensity ratio", "Intensity ratio", "BRET Ratio");
					}
					plot.setColor("red");
					plot.add("x", xValues, yValues);
					plot.show();
					for (int i = 0; i < xValues.length; i++) {
						sb.append(xValues[i]+","+yValues[i]+"\n");
					}
				} else { // trace 3D plot
					ImagePlus imp = IJ.createImage("3Dplot_"+minIntensity+"_"+maxIntensity, "32-bit black", nbValMax-1, 256, 1);
					ImageProcessor ip = imp.getProcessor();
					it = data.listIterator(0);
					while (it.hasNext()) {
						dataChunk = it.next();
						sb.append(dataChunk[0]);
						index = (int)((dataChunk[0]-minIntensity)/(maxIntensity-minIntensity)*255);
						for (int j = 1; j < dataChunk.length; j++) {
							sb.append(","+dataChunk[j]);
							ip.putPixelValue(j-1, index, dataChunk[j]);
							minValue = Math.min(minValue, dataChunk[j]);
							maxValue = Math.max(maxValue, dataChunk[j]);
						}
						sb.append("\n");
					}
					ip.setMinAndMax(minValue-0.1*(maxValue-minValue), maxValue+0.1*(maxValue-minValue));
					IJ.run(imp, BRETAnalyzerProcess.surfPlotCmd, "");
					//imp.show();
				}
				String resultsFolder = savePaths();
				File f = new File(resultsFolder);
				if (!f.exists()) {f.mkdirs();}
				String vsIntPath = resultsFolder+logSuffix.substring(1, logSuffix.length()-4)+".csv";
				IJ.saveString(sb.toString(), vsIntPath);
				IJ.log("Data saved in "+vsIntPath);
			} else {
				IJ.log("No region to save data for");
			}
		}
	}
	
	private String buildAbsolutePath(String logPath, String relative) {
		return logPath.substring(0, logPath.lastIndexOf(File.separator))+relative;
	}
	
	private String buildRelativePath(String logPath, String absolute) {
		String res = "";
		String commonPart = getCommonAncestorFolder(new String[]{logPath, absolute});
		String[] logEndParts = logPath.substring(commonPart.length()).replace('\\', '/').split("/");
		String[] absoluteEndParts = absolute.substring(commonPart.length()).replace('\\', '/').split("/");
		for (int i = 0; i < logEndParts.length-1; i++) {
			res += File.separator+"..";
		}
		for (int i = 0; i < absoluteEndParts.length; i++) {
			res += File.separator+absoluteEndParts[i];
		}
		return res;
	}
	
	private ImagePlus[] openVsIntensity(boolean single, String[] imgPaths) {
		ImagePlus[] res = new ImagePlus[2];
		res[0] = IJ.openImage(imgPaths[0]);
		if (!single) {
			res[1] = IJ.openImage(imgPaths[1]);
		}
		return res;
	}
	
	private String[] getImgPaths(boolean single) {
		String[] res = new String[2];
		IJ.showStatus("Select intensity image 1.");
		OpenDialog od = new OpenDialog("Select intensity image 1.");
		res[0] = od.getPath();
		if (res[0] == null) {
			return null;
		}
		if (!single) {
			IJ.showStatus("Select intensity image 2.");
			od = new OpenDialog("Select intensity image 2.");
			res[1] = od.getPath();
			if (res[1] == null) {
				return null;
			}
		}
		return res;
	}
	
	private boolean placeROIsFromLog(boolean single, String[] logLines, int roiIndex, ImagePlus[] imps) {
		boolean res = true;
		if (single) {
			if (logLines.length >= roiIndex*3+3) {
				WindowManager.setCurrentWindow(imps[0].getWindow());
				imps[0].setSlice(Integer.parseInt(logLines[roiIndex*3+1]));
				imps[0].setRoi(getPolyROI(logLines[roiIndex*3+2], logLines[roiIndex*3+3]));
			} else {
				res = false;
			}
		} else {
			if (logLines.length >= roiIndex*6+7) {
				WindowManager.setCurrentWindow(imps[0].getWindow());
				imps[0].setSlice(Integer.parseInt(logLines[roiIndex*6+2]));
				imps[0].setRoi(getPolyROI(logLines[roiIndex*6+3], logLines[roiIndex*6+4]));
				WindowManager.setCurrentWindow(imps[1].getWindow());
				imps[1].setSlice(Integer.parseInt(logLines[roiIndex*6+5]));
				imps[1].setRoi(getPolyROI(logLines[roiIndex*6+6], logLines[roiIndex*6+7]));
			} else {
				res = false;
			}
		}
		return res;
	}
	
	public static PolygonRoi getPolyROI(String xStr, String yStr) {
		return new PolygonRoi(new FloatPolygon(strToFloatArray(xStr, ","), strToFloatArray(yStr, ",")), Roi.POLYGON);		
	}
	
	public static float[] strToFloatArray(String str, String delimiter) {
		String[] strArray = str.split(delimiter);
		float[] floatArray = new float[strArray.length];
		for (int i = 0; i < strArray.length; i++) {
			floatArray[i] = Float.parseFloat(strArray[i]);
		}
		return floatArray;
	}
	
	private void copyROIs(boolean single, ImagePlus[] imps, int roiIndex) {
		getRM(true).select(imps[0], roiIndex);
		if (!single) {
			getRM(true).select(imps[1], roiIndex);
		}
	}
	
	private void closeCurrentImage() {
		if (currentSelection != -1) {
			saveROIs(currentSelection);
			if (impList.get(currentSelection).getProcessor() == null) {
				impList.set(currentSelection, IJ.openImage(imageList.getItem(currentSelection)));
			} else {
				ratioPosX = impList.get(currentSelection).getWindow().getLocation().getX();
				ratioPosY = impList.get(currentSelection).getWindow().getLocation().getY();
				Prefs.set("BRETa.ratioPosX", ratioPosX);
				Prefs.set("BRETa.ratioPosY", ratioPosY);
				impList.get(currentSelection).hide();
			}
			getRM(true).reset();
			imageList.deselect(currentSelection);
			currentSelection = -1;
		}
	}
	
	private void selectImage(int n) {
		if (n >= 0 && n < impList.size()) {
			currentSelection = n;
			imageList.select(n);
			ImageWindow.setNextLocation((int)ratioPosX, (int)ratioPosY);
			impList.get(n).show();
			loadROIs(n);
		}
	}
	
	private int pathIndex(String path) {
		int res = -1;
		path = path.replace('\\', '/');
		for (int i = 0; i < imageList.getItemCount(); i++) {
			if (path.equals(imageList.getItem(i).replace('\\', '/'))) {
				res = i;
			}
		}
		return res;
	}
	
	private void saveROIs(int n) {
		String path = getROIsFilePath(n);
		if (getRM(true).getCount() > 0) {
			getRM(true).runCommand("Save", path);
		} else {
			File f = new File(path);
			if (f.exists()) {
				f.delete();
			}
		}
	}
	
	private void loadROIs(int n) {
		if (!getRM(true).isVisible()) {
			getRM(true).setVisible(true);
		}
		String path = getROIsFilePath(n);
		File f = new File(path);
		if (f.exists()) {
			getRM(true).runCommand("Open", path);
		}
	}
	
	private String getROIsFilePath(int n) {
		String path = imageList.getItem(n);
		int indexSep = path.lastIndexOf(File.separator);
		int indexExt = path.lastIndexOf(".");
		if (indexExt > indexSep) {path = path.substring(0, indexExt);}
		return path+"_ROIs.zip";
	}
	
	private void setTagList(String str) {
		String[] tags = str.split(";");
		tagList.removeAll();
		tagListModel = new DefaultListModel<String>();
		for (int i = 0; i < tags.length; i++) {
			tagListModel.addElement(tags[i]);
		}
		tagList.setModel(tagListModel);
		tagList.setSelectedIndex(0);
	}
	
	private String getTagList() {
		String tags = "";
		int i;
		for (i = 0; i < tagListModel.getSize(); i++) {
			tags += tagListModel.getElementAt(i)+";";
		}
		tags = tags.substring(0, tags.length()-1);
		return tags;
	}
	
	private String[] getShortTags() {
		String[] res = new String[tagListModel.getSize()+1];
		for (int i = 0; i < res.length-1; i++) {
			res[i] = tagListModel.getElementAt(i);
		}
		res[res.length-1] = "_";
		for (int i = 0; i < res.length-1; i++) {
			int index = 1;
			int count = 2;
			while (count > 1 && index <= res[i].length()) {
				count = 0;
				for (String r : res) {
					if (r.startsWith(res[i].substring(0, index))) {
						count++;
					}
				}
				index++;
			}
			res[i] = res[i].substring(0, index-1);
		}
		return res;
	}
	
	private int getTagIndex(String name) {
		String[] parts = name.split("-");
		name = parts[0];
		int res = tagListModel.getSize();
		for (int i = 0; i < tagListModel.getSize(); i++) {
			if (name.equals(tagListModel.getElementAt(i))) {
				res = i;
				break;
			}
		}
		return res;
	}
	
	private RoiManager getRM(boolean open) {
		RoiManager rm = RoiManager.getInstance();
		if (!open && rm != null) {
			rm.close();
		}
		if (open && rm == null) {
			rm = RoiManager.getRoiManager();
		}
		return rm;
	}
	
 	public static String[] ratioToDonorAcceptor(String filePath) {
 		String[] strRes = new String[2];
		File file = new File(filePath);
		String parentFolder = file.getParent()+File.separator;
		String fileName = file.getName();
		int index = fileName.lastIndexOf("Ratio");
		if (index != -1) {
			strRes[0] = parentFolder+fileName.substring(0, index)+donorName+fileName.substring(index+5, fileName.length()-4)+"_clean.tif";
			strRes[1] = parentFolder+fileName.substring(0, index)+acceptorName+fileName.substring(index+5, fileName.length()-4)+"_clean.tif";
		}
		return strRes;
	}
 	
	public void windowOpened(WindowEvent e) {}
	public void windowClosing(WindowEvent e) {
		if (e.getSource() == meansPlotWin) {
			meansPlotPosX = meansPlotWin.getLocation().getX();
			meansPlotPosY = meansPlotWin.getLocation().getY();
			Prefs.set("BRETa.meansPlotPosX", meansPlotPosX);
			Prefs.set("BRETa.meansPlotPosY", meansPlotPosY);
		} else if (e.getSource() == sdPlotWin) {
			sdPlotPosX = sdPlotWin.getLocation().getX();
			sdPlotPosY = sdPlotWin.getLocation().getY();
			Prefs.set("BRETa.sdPlotPosX", sdPlotPosX);
			Prefs.set("BRETa.sdPlotPosY", sdPlotPosY);
		} else if (e.getSource() == resultsWin) {
			resultsPosX = resultsWin.getLocation().getX();
			resultsPosY = resultsWin.getLocation().getY();
			Prefs.set("BRETa.resultsPosX", resultsPosX);
			Prefs.set("BRETa.resultsPosY", resultsPosY);
		} else {
			framePosX = frame.getLocation().getX();
			framePosY = frame.getLocation().getY();
			frameSizeX = frame.getSize().getWidth();
			frameSizeY = frame.getSize().getHeight();
			Prefs.set("BRETa.analyseFramePosX", framePosX);
			Prefs.set("BRETa.analyseFramePosY", framePosY);
			Prefs.set("BRETa.analyseFrameSizeX", frameSizeX);
			Prefs.set("BRETa.analyseFrameSizeY", frameSizeY);
			closeAllImages();
			getRM(false);
			frame.dispose();
			frame = null;
			instance = null;
		}
	}
	public void windowClosed(WindowEvent e) {}
	public void windowIconified(WindowEvent e) {}
	public void windowDeiconified(WindowEvent e) {}
	public void windowActivated(WindowEvent e) {}
	public void windowDeactivated(WindowEvent e) {}
}

class WeightAction implements ActionListener, AdjustmentListener, Runnable, ItemListener {
	private double weightPosX = Prefs.get("BRETa.weightPosX", 100);
	private double weightPosY = Prefs.get("BRETa.weightPosY", 400);
	private double weightedPosX = Prefs.get("BRETa.weightedPosX", 500);
	private double weightedPosY = Prefs.get("BRETa.weightedPosY", 100);
	private double weightDiaPosX = Prefs.get("BRETa.weightDiaPosX", 400);
	private double weightDiaPosY = Prefs.get("BRETa.weightDiaPosY", 100);
	private String donorName;
	private Thread t;
	private ImagePlus ratioImg, weightImg, weightedImg;
	private ImageWindow weightedWin = null;
	private String ratioPath;
	private String donorPath;
	private Label lSlice, lLow, lHigh;
	private Scrollbar sSlice, sLow, sHigh;
	private Choice weightMethod;
	private Button butOk, butCancel;
	private Frame f;
	private int nbPixels, nbSlices;
	private long[] stackHisto;
	private ImageStatistics stats;
	
	public WeightAction(ImagePlus ratioImg, String ratioPath, String donorName) {
		this.t = new Thread(this);
		this.donorName = donorName;
		this.ratioImg = ratioImg;
		this.ratioPath = ratioPath;
	}
	
	public Thread getThread() {
		return t;
	}
	
	public void run() {
		donorPath = getCleanDonorPath(ratioPath);
		File donor = new File(donorPath);
		if (!donor.exists()) {
			IJ.showStatus("Select weight image.");
			OpenDialog od = new OpenDialog("Select weight image.");
			donorPath = od.getPath();
			if (donorPath == null) {return;} // user canceled, exit weighting
		}
		weightImg = IJ.openImage(donorPath);
		if (!Arrays.equals(weightImg.getDimensions(), ratioImg.getDimensions())) {
			IJ.log("Weight image has not the same dimensions as ratio image, weighting canceled");
			return;
		}
		ImageWindow.setNextLocation((int)weightPosX, (int)weightPosY);
		weightImg.show();
		stats = new StackStatistics(weightImg);
		stackHisto = stats.getHistogram();
		nbSlices = ratioImg.getNSlices();
		nbPixels = ratioImg.getWidth()*ratioImg.getHeight();
		lSlice = new Label("Current slice");
		sSlice = new Scrollbar(Scrollbar.HORIZONTAL, 1, 1, 1, nbSlices+1);
		sSlice.addAdjustmentListener(this);
		lLow = new Label("Low threshold");
		sLow = new Scrollbar(Scrollbar.HORIZONTAL, 0, 1, 0, nbPixels);
		sLow.addAdjustmentListener(this);
		lHigh = new Label("High threshold");
		sHigh = new Scrollbar(Scrollbar.HORIZONTAL, nbPixels, 1, 0, nbPixels);
		sHigh.setUnitIncrement((int)(Math.sqrt(nbPixels)));
		sHigh.addAdjustmentListener(this);
		weightMethod = new Choice();
		weightMethod.add("Weight on image histogram");
		weightMethod.add("Weight on stack histogram");
		weightMethod.addItemListener(this);
		butCancel = new Button("Cancel");
		butCancel.addActionListener(this);
		butOk = new Button("   OK   ");
		butOk.addActionListener(this);
		f = new Frame("Ratio weighting");
		f.setLayout(new GridBagLayout());
		addThingFrame(f, lSlice,		0, 0, 1, 1, 1, 1, 0, 0);
		addThingFrame(f, lLow,			0, 1, 1, 1, 1, 1, 0, 0);
		addThingFrame(f, lHigh,			0, 2, 1, 1, 1, 1, 0, 0);
		addThingFrame(f, sSlice,		1, 0, 2, 1, 3, 1, 30, 6);
		addThingFrame(f, sLow,			1, 1, 2, 1, 3, 1, 30, 6);
		addThingFrame(f, sHigh,			1, 2, 2, 1, 3, 1, 30, 6);
		addThingFrame(f, weightMethod,	1, 3, 2, 1, 3, 1, 0, 0);
		addThingFrame(f, butCancel,		1, 4, 1, 1, 3, 1, 0, 0);
		addThingFrame(f, butOk,			2, 4, 1, 1, 3, 1, 0, 0);
		f.setAlwaysOnTop(true);
		f.setResizable(true);
		f.pack();
		f.setLocation((int)weightDiaPosX, (int)weightDiaPosY);
		f.setVisible(true);
		doWeighting(1);
		f.requestFocus();
	}
	
	private void addThingFrame(
		Frame f, 
		Component b, 
		int gridx, 
		int gridy, 
		int gridwidth, 
		int gridheight, 
		int weightx, 
		int weighty, 
		int ipadx,
		int ipady
		){
		GridBagConstraints c = new GridBagConstraints();
		c.fill = GridBagConstraints.BOTH;
		c.gridx = gridx;
		c.gridy = gridy;
		c.gridwidth = gridwidth;
		c.gridheight = gridheight;
		c.weightx = weightx;
		c.weighty = weighty;
		c.ipadx = ipadx;
		c.ipady = ipady;
		f.add(b, c);
	}
	
	public void adjustmentValueChanged(AdjustmentEvent e) {
		int sliceNb = sSlice.getValue();
		if (sLow.getValue() >= sHigh.getValue()) {
			sHigh.setValue(sLow.getValue()+1);
		}
		doWeighting(sliceNb);
		ratioImg.setSlice(sliceNb);
	}
	
	public void itemStateChanged(ItemEvent e) {
		int sliceNb = sSlice.getValue();
		doWeighting(sliceNb);
		ratioImg.setSlice(sliceNb);
	}
	
	public void actionPerformed(ActionEvent e) {
		weightedPosX = weightedWin.getLocation().getX();
		weightedPosY = weightedWin.getLocation().getY();
		Prefs.set("BRETa.weightedPosX", weightedPosX);
		Prefs.set("BRETa.weightedPosY", weightedPosY);
		if (weightImg.getWindow() != null) {
			weightPosX = weightImg.getWindow().getLocation().getX();
			weightPosY = weightImg.getWindow().getLocation().getY();
			Prefs.set("BRETa.weightPosX", weightPosX);
			Prefs.set("BRETa.weightPosY", weightPosY);
		}
		if (e.getSource() == butOk) {
			doWeighting(0);
			weightImg.close();
		} else {
			weightImg.close();
			weightedImg.close();
		}
		weightDiaPosX = f.getLocation().getX();
		weightDiaPosY = f.getLocation().getY();
		Prefs.set("BRETa.weightDiaPosX", weightDiaPosX);
		Prefs.set("BRETa.weightDiaPosY", weightDiaPosY);
		f.dispose();
	}
	
	private void doWeighting(int sliceNb) {
		int stopSlice, offset;
		if (sliceNb < 1) {
			weightedImg.getWindow().close();
			weightedWin = null;
			weightedImg = ratioImg.duplicate();
			String title = weightMethod.getSelectedIndex()==0?"_sliceWeighted":"_stackWeighted";
			weightedImg.setTitle(ratioImg.getTitle()+title);
			stopSlice = nbSlices;
			offset = 1;
		} else {
			ratioImg.setSlice(sliceNb);
			weightedImg = ratioImg.crop();
			stopSlice = 1;
			offset = sliceNb;
		}
		
		int index;
		int[] lowVal = new int[stopSlice];
		int[] highVal = new int[stopSlice];
		if (weightMethod.getSelectedIndex() == 0) { // weight on each frame histogram
			int[] histo;
			int cumul;
			for (int i = 0; i < stopSlice; i++) {
				weightImg.setSliceWithoutUpdate(i+offset);
				histo = weightImg.getProcessor().getHistogram();
				cumul = 0; index = -1;
				while (cumul < sLow.getValue()) {
					index++;
					cumul += histo[index];
				}
				lowVal[i] = index;
				cumul = nbPixels; index = histo.length;
				while (cumul > sHigh.getValue()) {
					index--;
					cumul -= histo[index];
				}
				highVal[i] = index;
			}
		} else { // weight on stack histogram
			long cumul;
			cumul = 0; index = -1;
			while (cumul < nbSlices*sLow.getValue()) {
				index++;
				cumul += stackHisto[index];
			}
			lowVal[0] = (int)(stats.histMin+stats.binSize*index);
			cumul = nbSlices*nbPixels; index = stackHisto.length;
			while (cumul > nbSlices*sHigh.getValue()) {
				index--;
				cumul -= stackHisto[index];
			}
			highVal[0] = (int)(stats.histMin+stats.binSize*index);
			for (int i = 1; i < stopSlice; i++) {
				lowVal[i] = lowVal[0];
				highVal[i] = highVal[0];
			}
		}
		IJ.run(weightedImg, "RGB Color", "");
		ColorProcessor ip = (ColorProcessor)weightedImg.getProcessor().convertToRGB();
		ImageProcessor ip2 = weightImg.getProcessor();
		int pxVal;
		int[] pxColors = {0, 0, 0};
		for (int i = 0; i < stopSlice; i++) {
			int interval = highVal[i] - lowVal[i];
			weightedImg.setSlice(i+offset);
			weightImg.setSlice(i+offset);
			for (int x = 0; x < weightedImg.getWidth(); x++) {
				for (int y = 0; y < weightedImg.getHeight(); y++) {
					pxVal = ip2.get(x, y);
					if (pxVal < lowVal[i]) {
						ip.set(x, y, 0);
					} else if (pxVal < highVal[i]) {
						double coef = ((pxVal-lowVal[i])/(double)interval);
						pxColors = ip.getPixel(x, y, pxColors);
						pxColors[0] = (int)(pxColors[0]*coef);
						pxColors[1] = (int)(pxColors[1]*coef);
						pxColors[2] = (int)(pxColors[2]*coef);
						ip.putPixel(x, y, pxColors);
					}
				}
			}
		}
		weightedImg.setProcessor(ip);
		if (weightedWin == null) {
			ImageWindow.setNextLocation((int)weightedPosX, (int)weightedPosY);
			weightedImg.show();
			weightedWin = weightedImg.getWindow();
		} else {
			weightedWin.setImage(weightedImg);
		}
		weightedImg.changes = false;
		weightedImg.setSlice(sSlice.getValue());
	}
	
	private String getCleanDonorPath(String ratioPath) {
		File file = new File(ratioPath);
		String parentFolder = file.getParent();
		String fileName = file.getName();
		int index = fileName.lastIndexOf(".");
		if (index != -1) {
			fileName = fileName.substring(0, index); // remove extension
		}
		fileName += "_clean.tif";
		index = fileName.lastIndexOf("Ratio");
		if (index != -1) {
			fileName = BRETAnalyzerProcess.replaceLast(fileName, "Ratio", donorName); // replace "Ratio" by donor
		}
		return parentFolder+File.separator+fileName;
	}

}




