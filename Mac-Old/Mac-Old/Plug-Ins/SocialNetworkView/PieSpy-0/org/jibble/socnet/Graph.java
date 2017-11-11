/* 
Copyright Paul James Mutton, 2001-2004, http://www.jibble.org/

This file is part of PieSpy.

This software is dual-licensed, allowing you to choose between the GNU
General Public License (GPL) and the www.jibble.org Commercial License.
Since the GPL may be too restrictive for use in a proprietary application,
a commercial license is also provided. Full license information can be
found at http://www.jibble.org/licenses/

$Author: pjm2 $
$Id: Graph.java,v 1.25 2004/03/13 09:57:05 pjm2 Exp $

*/

package org.jibble.socnet;

import java.util.*;
import java.io.*;
import java.awt.*;
import java.awt.image.*;

public class Graph implements java.io.Serializable {
    
    public Graph(String label, Configuration config) {
        _label = label;
        this.config = config;
    }
    
    public void addNode(Node node) {
        if (_nodes.containsKey(node)) {
            node = (Node) _nodes.get(node);
        }
        else {
            _nodes.put(node, node);
            _allSeenNodes.add(node);
        }
        node.setWeight(node.getWeight() + 1);
    }
    
    public boolean addEdge(Node source, Node target) {
        if (source.equals(target)) {
            return false;
        }
        
        addNode(source);
        addNode(target);
        Edge edge = new Edge(source, target);
        if (_edges.containsKey(edge)) {
            edge = (Edge) _edges.get(edge);
        }
        else {
            source = (Node) _nodes.get(source);
            target = (Node) _nodes.get(target);
            edge = new Edge(source, target);
            _edges.put(edge, edge);
        }
        edge.setWeight(edge.getWeight() + 1);
        
        // The graph has changed in structure. Let's make everything else
        // decay slightly.
        decay(config.temporalDecayAmount);
        
        // The graph has changed.
        _frameCount++;
        return true;
    }
    
    public boolean removeNode(Node node) {
        if (_nodes.containsKey(node)) {
            _nodes.remove(node);
            Iterator edgeIt = _edges.keySet().iterator();
            while (edgeIt.hasNext()) {
                Edge edge = (Edge) edgeIt.next();
                if (edge.getSource().equals(node) || edge.getTarget().equals(node)) {
                    edgeIt.remove();
                }
            }
            // The graph has changed.
            _frameCount++;
            return true;
        }
        return false;
    }
    
    public boolean contains(Node node) {
        //return _nodes.containsKey(node);
        return _allSeenNodes.contains(node);
    }
    
    public boolean contains(Edge edge) {
        return _edges.containsKey(edge);
    }
    
    public Node get(Node node) {
        return (Node) _nodes.get(node);
    }
    
    public Edge get(Edge edge) {
        return (Edge) _edges.get(edge);
    }
    
    public String toString() {
        return "Graph: " + _nodes.size() + " nodes and " + _edges.size() + " edges.";
    }

    public String toString2() {
        StringBuffer buffer = new StringBuffer();
        Iterator nodeIt = _nodes.keySet().iterator();
        while (nodeIt.hasNext()) {
            Node node = (Node) nodeIt.next();
            buffer.append(node.toString() + " ");
        }
        return buffer.toString();
    }
    
    public void decay(double amount) {
        
        Iterator edgeIt = _edges.keySet().iterator();
        while (edgeIt.hasNext()) {
            Edge edge = (Edge) edgeIt.next();
            edge.setWeight(edge.getWeight() - amount);
            if (edge.getWeight() <= 0) {
                edgeIt.remove();
            }
        }
        
        Iterator nodeIt = _nodes.keySet().iterator();
        while (nodeIt.hasNext()) {
            Node node = (Node) nodeIt.next();
            node.setWeight(node.getWeight() - amount);
            if (node.getWeight() < 0) {
                node.setWeight(0);
            }
        }
        
    }
    
    // Returns the set of all nodes that have emanating edges.
    private HashSet getConnectedNodes() {
        HashSet connectedNodes = new HashSet();
        Iterator edgeIt = _edges.keySet().iterator();
        while (edgeIt.hasNext()) {
            Edge edge = (Edge) edgeIt.next();
            connectedNodes.add(edge.getSource());
            connectedNodes.add(edge.getTarget());
        }
        return connectedNodes;
    }

    // Applies the spring embedder.
    public void doLayout(int iterations) {
        
        // For performance, copy each set into an array.
        HashSet visibleNodes = getConnectedNodes();
        Node[] nodes = (Node[]) visibleNodes.toArray(new Node[visibleNodes.size()]);
        Edge[] edges = (Edge[]) _edges.keySet().toArray(new Edge[_edges.size()]);
        
        double k = config.k;
        double c = config.c;
        // Repulsive forces between nodes that are further apart than this are ignored.
        double maxRepulsiveForceDistance = config.maxRepulsiveForceDistance;
                
        // For each iteration...
        for (int it = 0; it < iterations; it++) {
            
            // Calculate forces acting on nodes due to node-node repulsions...
            
            for (int a = 0; a < nodes.length; a++) {
                for (int b = a + 1; b < nodes.length; b++) {
                    Node nodeA = nodes[a];
                    Node nodeB = nodes[b];
                    
                    double deltaX = nodeB.getX() - nodeA.getX();
                    double deltaY = nodeB.getY() - nodeA.getY();
                    
                    double distanceSquared = deltaX * deltaX + deltaY * deltaY;
                    
                    if (distanceSquared < 0.01) {
                        deltaX = Math.random() / 10 + 0.1;
                        deltaY = Math.random() / 10 + 0.1;
                        distanceSquared = deltaX * deltaX + deltaY * deltaY;
                    }
                    
                    double distance = Math.sqrt(distanceSquared);
                    
                    if (distance < maxRepulsiveForceDistance) {
                        double repulsiveForce = (k * k / distance);
                        
                        nodeB.setFX(nodeB.getFX() + (repulsiveForce * deltaX / distance));
                        nodeB.setFY(nodeB.getFY() + (repulsiveForce * deltaY / distance));
                        nodeA.setFX(nodeA.getFX() - (repulsiveForce * deltaX / distance));
                        nodeA.setFY(nodeA.getFY() - (repulsiveForce * deltaY / distance));
                    }
                }
            }
            
            // Calculate forces acting on nodes due to edge attractions.
            
            for (int e = 0; e < edges.length; e++) {
                Edge edge = edges[e];
                Node nodeA = edge.getSource();
                Node nodeB = edge.getTarget();
                
                double deltaX = nodeB.getX() - nodeA.getX();
                double deltaY = nodeB.getY() - nodeA.getY();
                
                double distanceSquared = deltaX * deltaX + deltaY * deltaY;
    
                // Avoid division by zero error or Nodes flying off to
                // infinity.  Pretend there is an arbitrary distance between
                // the Nodes.
                if (distanceSquared < 0.01) {
                    deltaX = Math.random() / 10 + 0.1;
                    deltaY = Math.random() / 10 + 0.1;
                    distanceSquared = deltaX * deltaX + deltaY * deltaY;
                }
                
                double distance = Math.sqrt(distanceSquared);
                
                if (distance >  maxRepulsiveForceDistance) {
                    distance = maxRepulsiveForceDistance;
                }
                
                distanceSquared = distance * distance;
                
                double attractiveForce = (distanceSquared - k * k) / k;
                
                // Make edges stronger if people know each other.
                double weight = edge.getWeight();
                if (weight < 1) {
                    weight = 1;
                }
                attractiveForce *= (Math.log(weight) * 0.5) + 1;
            
                nodeB.setFX(nodeB.getFX() - attractiveForce * deltaX / distance);
                nodeB.setFY(nodeB.getFY() - attractiveForce * deltaY / distance);
                nodeA.setFX(nodeA.getFX() + attractiveForce * deltaX / distance);
                nodeA.setFY(nodeA.getFY() + attractiveForce * deltaY / distance);
                
            }
            
            // Now move each node to its new location...
            
            for (int a = 0; a < nodes.length; a++) {
                Node node = nodes[a];
                
                double xMovement = c * node.getFX();
                double yMovement = c * node.getFY();
                
                // Limit movement values to stop nodes flying into oblivion.
                double max = config.maxNodeMovement;
                if (xMovement > max) {
                    xMovement = max;
                }
                else if (xMovement < -max) {
                    xMovement = -max;
                }
                if (yMovement > max) {
                    yMovement = max;
                }
                else if (yMovement < -max) {
                    yMovement = -max;
                }
                
                node.setX(node.getX() + xMovement);
                node.setY(node.getY() + yMovement);
                
                // Reset the forces
                node.setFX(0);
                node.setFY(0);
            }
            
        }
        
    }

    // Work out the drawing boundaries...
    public void calcBounds(int width, int height) {
        
        minX = Double.POSITIVE_INFINITY;
        maxX = Double.NEGATIVE_INFINITY;
        minY = Double.POSITIVE_INFINITY;
        maxY = Double.NEGATIVE_INFINITY;
        maxWeight = 0;
        
        HashSet nodes = getConnectedNodes();
        Iterator nodeIt = nodes.iterator();
        while (nodeIt.hasNext()) {
            Node node = (Node) nodeIt.next();
            
            if (node.getX() > maxX) {
                maxX = node.getX();
            }
            if (node.getX() < minX) {
                minX = node.getX();
            }
            if (node.getY() > maxY) {
                maxY = node.getY();
            }
            if (node.getY() < minY) {
                minY = node.getY();
            }
        }
        
        // Increase size if too small.
        double minSize = config.minDiagramSize;
        if (maxX - minX < minSize) {
            double midX = (maxX + minX) / 2;
            minX = midX - (minSize / 2);
            maxX = midX + (minSize / 2);
        }
        if (maxY - minY < minSize) {
            double midY = (maxY + minY) / 2;
            minY = midY - (minSize / 2);
            maxY = midY + (minSize / 2);
        }
        
        // Work out the maximum weight.
        Iterator edgeIt = _edges.keySet().iterator();
        while (edgeIt.hasNext()) {
            Edge edge = (Edge) edgeIt.next();
            if (edge.getWeight() > maxWeight) {
                maxWeight = edge.getWeight();
            }
        }
        
        // Jibble the boundaries to maintain the aspect ratio.
        double xyRatio = ((maxX - minX) / (maxY - minY)) / (width / height);
        if (xyRatio > 1) {
            // diagram is wider than it is high.
            double dy = maxY - minY;
            dy = dy * xyRatio - dy;
            minY = minY - dy / 2;
            maxY = maxY + dy / 2;
        }
        else if (xyRatio < 1) {
            // Diagram is higher than it is wide.
            double dx = maxX - minX;
            dx = dx / xyRatio - dx;
            minX = minX - dx / 2;
            maxX = maxX + dx / 2;
        }
        
    }
    
    public BufferedImage drawImage(String channel, int width, int height, int borderSize, int nodeRadius, double edgeThreshold, boolean showEdges) {

        HashSet nodes = getConnectedNodes();
       
        // Now actually draw the thing...
    
        BufferedImage image = new BufferedImage(width, height, BufferedImage.TYPE_INT_ARGB);
        Graphics2D g = image.createGraphics();
        
        g.setColor(config.backgroundColor);
        g.fillRect(1, 1, width - 2, height - 2);
        
        g.setRenderingHint(RenderingHints.KEY_ANTIALIASING, RenderingHints.VALUE_ANTIALIAS_ON);

        g.setColor(config.borderColor);
        g.drawRect(0, 0, width - 1, height - 1);
        
        width = width - borderSize * 3;  // note the 3 (gives more border on right side)
        height = height - borderSize * 2;

        g.setColor(config.channelColor);
        g.setFont(new Font("SansSerif", Font.BOLD, 64));
        g.drawString(channel, borderSize + 20, 80);

        g.setColor(config.titleColor);
        g.setFont(new Font("SansSerif", Font.BOLD, 18));
        g.drawString("A Social Network Diagram for an IRC Channel", borderSize, borderSize - nodeRadius - 15);
        g.drawString(_caption, borderSize, height + borderSize * 2 - 5 - 50);
        g.setFont(new Font("SansSerif", Font.PLAIN, 12));
        g.drawString("Generated by " + config.nick + " on " + config.server + " using " + SocialNetworkBot.VERSION, borderSize, height + borderSize * 2 - 5 - 30);
        g.drawString("Blue edge thickness and shortness represents strength of relationship", borderSize, height + borderSize * 2 - 5 - 15);
        g.drawString("http://www.jibble.org/piespy/ - This frame was drawn at " + new Date(), borderSize, height + borderSize * 2 - 5);
        
        // Draw all edges...
        Iterator edgeIt = _edges.keySet().iterator();
        while (edgeIt.hasNext()) {
            Edge edge = (Edge) edgeIt.next();
            
            if (edge.getWeight() < edgeThreshold) {
                continue;
            }
            
            double weight = edge.getWeight();
            //if (weight < 1) {
            //    weight = 1;
            //}
            
            Node nodeA = edge.getSource();
            Node nodeB = edge.getTarget();
            int x1 = (int) (width * (nodeA.getX() - minX) / (maxX - minX)) + borderSize;
            int y1 = (int) (height * (nodeA.getY() - minY) / (maxY - minY)) + borderSize;
            int x2 = (int) (width * (nodeB.getX() - minX) / (maxX - minX)) + borderSize;
            int y2 = (int) (height * (nodeB.getY() - minY) / (maxY - minY)) + borderSize;
            g.setStroke(new BasicStroke((float) (Math.log(weight + 1) * 0.5) + 1));
            int alpha = 102 + (int) (153 * weight / maxWeight);
            g.setColor(new Color(config.edgeColor.getRed(), config.edgeColor.getGreen(), config.edgeColor.getBlue(), alpha));
            if (showEdges) {
                g.drawLine(x1, y1, x2, y2);
            }
        }
        
        // Draw all nodes...
        g.setStroke(new BasicStroke(2.0f));
        g.setFont(new Font("SansSerif", Font.PLAIN, 10));
        Iterator nodeIt = nodes.iterator();
        while (nodeIt.hasNext()) {
            Node node = (Node) nodeIt.next();
            int x1 = (int) (width * (node.getX() - minX) / (maxX - minX)) + borderSize;
            int y1 = (int) (height * (node.getY() - minY) / (maxY - minY)) + borderSize;
            //int newNodeRadius = (int) Math.log((node.getWeight() + 1) / 10) + nodeRadius;
            g.setColor(config.nodeColor);
            g.fillOval(x1 - nodeRadius, y1 - nodeRadius, nodeRadius * 2, nodeRadius * 2);
            g.setColor(config.edgeColor);
            g.drawOval(x1 - nodeRadius, y1 - nodeRadius, nodeRadius * 2, nodeRadius * 2);
            //g.setColor(Color.white);
            //g.drawString(node.toString(), x1 + nodeRadius + 1, y1 - nodeRadius);
            //g.drawString(node.toString(), x1 + nodeRadius - 1, y1 - nodeRadius);
            //g.drawString(node.toString(), x1 + nodeRadius, y1 - nodeRadius + 1);
            //g.drawString(node.toString(), x1 + nodeRadius, y1 - nodeRadius - 1);
            g.setColor(config.labelColor);
            g.drawString(node.toString(), x1 + nodeRadius, y1 - nodeRadius);
        }
        
        return image;
    }
    
    public int getFrameCount() {
        return _frameCount;
    }
    
    public String getLabel() {
        return _label;
    }
    
    public void setCaption(String caption) {
        _caption = caption;
    }
    
    private String _label;
    private String _caption = "";
    private HashMap _nodes = new HashMap();
    private HashMap _edges = new HashMap();
    private HashSet _allSeenNodes = new HashSet();
    
    private double minX = Double.POSITIVE_INFINITY;
    private double maxX = Double.NEGATIVE_INFINITY;
    private double minY = Double.POSITIVE_INFINITY;
    private double maxY = Double.NEGATIVE_INFINITY;
    private double maxWeight = 0;

    private Configuration config;
    private int _frameCount = 0;
    
}