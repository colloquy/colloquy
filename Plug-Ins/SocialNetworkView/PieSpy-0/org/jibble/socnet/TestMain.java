/* 
Copyright Paul James Mutton, 2001-2004, http://www.jibble.org/

This file is part of PieSpy.

This software is dual-licensed, allowing you to choose between the GNU
General Public License (GPL) and the www.jibble.org Commercial License.
Since the GPL may be too restrictive for use in a proprietary application,
a commercial license is also provided. Full license information can be
found at http://www.jibble.org/licenses/

$Author: pjm2 $
$Id: TestMain.java,v 1.3 2004/03/09 12:22:50 pjm2 Exp $

*/

package org.jibble.socnet;

import java.util.*;
import java.io.*;

public class TestMain {
    
    public static void main(String[] args) throws Exception {
        
        Random rand = new Random(1234);
        
        Properties p = new Properties();
        p.load(new FileInputStream("./config.ini"));
        SocialNetworkBot bot = new SocialNetworkBot(new Configuration(p));
        
        String[] nicks = {"a", "b", "c", "d", "e", "f", "g", "h", "i", "j"};
        
        for (int i = 0; i < 80; i++) {
            bot.onMessage("#static", nicks[rand.nextInt(nicks.length)], null, null, nicks[rand.nextInt(nicks.length)] + ": hi!");
        }
        
    }
    
}