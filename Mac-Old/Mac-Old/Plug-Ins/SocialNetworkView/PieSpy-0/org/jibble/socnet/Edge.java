/* 
Copyright Paul James Mutton, 2001-2004, http://www.jibble.org/

This file is part of PieSpy.

This software is dual-licensed, allowing you to choose between the GNU
General Public License (GPL) and the www.jibble.org Commercial License.
Since the GPL may be too restrictive for use in a proprietary application,
a commercial license is also provided. Full license information can be
found at http://www.jibble.org/licenses/

$Author: pjm2 $
$Id: Edge.java,v 1.5 2004/02/18 15:06:17 pjm2 Exp $

*/

package org.jibble.socnet;

public class Edge implements java.io.Serializable {
    
    public Edge(Node source, Node target) {
        // Note that this graph is actually undirected.
        _source = source;
        _target = target;
        _weight = 0;
    }
    
    public void setWeight(double weight) {
        _weight = weight;
    }
    
    public double getWeight() {
        return _weight;
    }
    
    public Node getSource() {
        return _source;
    }
    
    public Node getTarget() {
        return _target;
    }
    
    public boolean equals(Object o) {
        if (o instanceof Edge) {
            Edge other = (Edge) o;
            return (_source.equals(other._source) && _target.equals(other._target)) || (_source.equals(other._target) && _target.equals(other._source));
        }
        return false;
    }
    
    public int hashCode() {
        return _source.hashCode() + _target.hashCode();
    }
    
    private Node _source;
    private Node _target;
    private double _weight;
    
}