/* 
Copyright Paul James Mutton, 2001-2004, http://www.jibble.org/

This file is part of PieSpy.

This software is dual-licensed, allowing you to choose between the GNU
General Public License (GPL) and the www.jibble.org Commercial License.
Since the GPL may be too restrictive for use in a proprietary application,
a commercial license is also provided. Full license information can be
found at http://www.jibble.org/licenses/

$Author: pjm2 $
$Id: Node.java,v 1.8 2004/03/09 12:22:50 pjm2 Exp $

*/

package org.jibble.socnet;

public class Node implements java.io.Serializable {
    
    public Node(String nick) {
        _nick = nick;
        _lowerCaseNick = _nick.toLowerCase();
        _weight = 0;
        _x = Math.random() * 2;
        _y = Math.random() * 2;
        _fx = 0;
        _fy = 0;
    }
    
    public void setX(double x) {
        _x = x;
    }
    
    public void setY(double y) {
        _y = y;
    }

    public void setFX(double fx) {
        _fx = fx;
    }
    
    public void setFY(double fy) {
        _fy = fy;
    }
    
    public double getX() {
        return _x;
    }
    
    public double getY() {
        return _y;
    }
    
    public double getFX() {
        return _fx;
    }
    
    public double getFY() {
        return _fy;
    }
    
    public String toString() {
        return _nick;
    }

    public void setWeight(double weight) {
        _weight = weight;
    }

    public double getWeight() {
        return _weight;
    }
    
    public boolean equals(Object o) {
        if (o instanceof Node) {
            Node other = (Node) o;
            return _lowerCaseNick.equals(other._lowerCaseNick);
        }
        return false;
    }
    
    public int hashCode() {
        return _lowerCaseNick.hashCode();
    }
    
    private String _nick;
    private String _lowerCaseNick;
    private double _weight;
    private double _x;
    private double _y;
    private double _fx;
    private double _fy;
    
}