/* 
Copyright Paul James Mutton, 2001-2004, http://www.jibble.org/

This file is part of PieSpy.

This software is dual-licensed, allowing you to choose between the GNU
General Public License (GPL) and the www.jibble.org Commercial License.
Since the GPL may be too restrictive for use in a proprietary application,
a commercial license is also provided. Full license information can be
found at http://www.jibble.org/licenses/

$Author: pjm2 $
$Id: Configuration.java,v 1.5 2004/03/13 09:57:05 pjm2 Exp $

*/

package org.jibble.socnet;

import java.awt.Color;
import java.util.*;

public class Configuration implements java.io.Serializable {
    
    public String server;
    public int port;
    public String serverPassword;
    public String nick;
    public HashSet channelSet;
    
    public int outputWidth;
    public int outputHeight;
    public String outputDirectory;
    public boolean createCurrent;
    public boolean createArchive;
    public boolean createRestorePoints;
    
    public Color backgroundColor;
    public Color channelColor;
    public Color labelColor;
    public Color titleColor;
    public Color nodeColor;
    public Color edgeColor;
    public Color borderColor;
    
    public String password;
    
    public HashSet ignoreSet;
    
    public int temporalProximityDistance;
    public double temporalDecayAmount;
    public int springEmbedderIterations;
    public double k;
    public double c;
    public double maxRepulsiveForceDistance;
    public double maxNodeMovement;
    public double minDiagramSize;
    public int borderSize;
    public int nodeRadius;
    public double edgeThreshold;
    public boolean showEdges;
    public boolean verbose;
    public String encoding;
    
    private Properties properties;
    
    public Configuration(Properties p) throws NoSuchElementException {
        properties = p;
        
        server = getString("Server");
        port = getInt("Port");
        serverPassword = getString("ServerPassword");
        nick = getString("Nick");
        channelSet = getSet("ChannelSet");
        
        outputWidth = getInt("OutputWidth");
        outputHeight = getInt("OutputHeight");
        outputDirectory = getString("OutputDirectory");
        createCurrent = getBoolean("CreateCurrent");
        createArchive = getBoolean("CreateArchive");
        createRestorePoints = getBoolean("CreateRestorePoints");
        
        backgroundColor = getColor("BackgroundColor");
        channelColor = getColor("ChannelColor");
        labelColor = getColor("LabelColor");
        titleColor = getColor("TitleColor");
        nodeColor = getColor("NodeColor");
        edgeColor = getColor("EdgeColor");
        borderColor = getColor("BorderColor");
        
        password = getString("Password");
        
        ignoreSet = getSet("IgnoreSet");
        
        temporalProximityDistance = getInt("TemporalProximityDistance");
        temporalDecayAmount = getDouble("TemporalDecayAmount");
        springEmbedderIterations = getInt("SpringEmbedderIterations");
        k = getDouble("K");
        c = getDouble("C");
        maxRepulsiveForceDistance = getDouble("MaxRepulsiveForceDistance");
        maxNodeMovement = getDouble("MaxNodeMovement");
        minDiagramSize = getDouble("MinDiagramSize");
        borderSize = getInt("BorderSize");
        nodeRadius = getInt("NodeRadius");
        edgeThreshold = getDouble("EdgeThreshold");
        showEdges = getBoolean("ShowEdges");
        verbose = getBoolean("Verbose");
        encoding = getString("Encoding");
        
    }
    
    private int getInt(String label) throws NoSuchElementException {
        String value = getString(label);
        return Integer.parseInt(value);
    }
    
    private double getDouble(String label) throws NoSuchElementException {
        String value = getString(label);
        return Double.parseDouble(value);
    }
    
    private boolean getBoolean(String label) {
        String value = getString(label);
        return Boolean.valueOf(value).booleanValue();
    }
    
    private Color getColor(String label) {
        String value = getString(label);
        Color color = Color.decode(value);
        return color;
    }
    
    private HashSet getSet(String label) {
        String values = getString(label);
        String[] tokens = values.split(",");
        HashSet set = new HashSet();
        for (int i = 0; i < tokens.length; i++) {
            set.add(tokens[i].trim().toLowerCase());
        }
        return set;
    }
    
    private String getString(String label) throws NoSuchElementException {
        String value = properties.getProperty(label);
        if (value == null) {
            throw new NoSuchElementException("Config did not contain: " + label);
        }
        return value;
    }
    
    
}