/* 
Copyright Paul James Mutton, 2001-2004, http://www.jibble.org/

This file is part of PieSpy.

This software is dual-licensed, allowing you to choose between the GNU
General Public License (GPL) and the www.jibble.org Commercial License.
Since the GPL may be too restrictive for use in a proprietary application,
a commercial license is also provided. Full license information can be
found at http://www.jibble.org/licenses/

$Author: pjm2 $
$Id: SocialNetworkBot.java,v 1.27 2004/03/09 12:23:28 pjm2 Exp $

*/

package org.jibble.socnet;

import org.jibble.pircbot.*;

import java.util.*;
import java.awt.image.BufferedImage;
import javax.imageio.ImageIO;
import java.io.*;
import java.text.*;

public class SocialNetworkBot extends PircBot {

    public static final String VERSION = "PieSpy 0.2.4";

    public SocialNetworkBot(Configuration config) throws IOException {
        this.config = config;
        
        _outputDirectory = new File(config.outputDirectory);
        if (!_outputDirectory.exists() || !_outputDirectory.isDirectory()) {
            throw new IOException("Output directory (" + _outputDirectory + ") does not exist.");
        }
        
        _nf = NumberFormat.getIntegerInstance();
        _nf.setMinimumIntegerDigits(8);
        _nf.setGroupingUsed(false);
    }
    
    private void addToHistory(String channel, String nick) {
        
        if (config.ignoreSet.contains(nick.toLowerCase())) {
            return;
        }
        
        channel = channel.toLowerCase();
        LinkedList nickList = (LinkedList) _nickHistory.get(channel);
        if (nickList == null) {
            nickList = new LinkedList();
            _nickHistory.put(channel, nickList);
        }
        
        nickList.add(nick);
        if (nickList.size() > config.temporalProximityDistance) {
            nickList.removeFirst();
            Iterator nickIt = nickList.iterator();
            HashSet uniqueNicks = new HashSet();
            while (nickIt.hasNext()) {
                uniqueNicks.add(nickIt.next());
            }
            if (uniqueNicks.size() == 2) {
                // This means only two people were seen chatting over the
                // last n lines in this channel, so we can assume they
                // we talking to each other.
                Iterator setIt = uniqueNicks.iterator();
                String nick1 = (String) setIt.next();
                String nick2 = (String) setIt.next();
                add(channel, nick1);
                add(channel, nick2);
                Graph graph = (Graph) _graphs.get(channel);
                addEdge(graph, new Node(nick1), new Node(nick2));
                nickList.clear();
            }
        }
    }
    
    public void onMessage(String channel, String sender, String login, String hostname, String message) {
        
        if (config.ignoreSet.contains(sender.toLowerCase())) {
            return;
        }
        
        Node source = new Node(sender);
        add(channel, sender);
        Graph graph = (Graph) _graphs.get(channel.toLowerCase());
        StringTokenizer tokenizer = new StringTokenizer(message, " \t\n\r\f:,-./&!?()<>");
        while (tokenizer.hasMoreTokens()) {
            Node target = new Node(tokenizer.nextToken());
            if (graph.contains(target)) {
                addEdge(graph, source, target);
                break;
            }
        }

        addToHistory(channel, sender);
    }
    
    protected void onPrivateMessage(String sender, String login, String hostname, String message) {
        if (!message.startsWith(config.password)) {
            sendMessage(sender, "Incorrect password.");
            return;
        }
        
        message = message.substring(config.password.length()).trim();
        String messageLc = message.toLowerCase();
        
        if (messageLc.equals("stats")) {
            Iterator keyIt = _graphs.keySet().iterator();
            while (keyIt.hasNext()) {
                String key = (String) keyIt.next();
                Graph graph = (Graph) _graphs.get(key);
                sendMessage(sender, key + ": " + graph.toString());
            }
        }
        else if (messageLc.startsWith("raw ")) {
            sendRawLine(message.substring(4));
        }
        else if (messageLc.startsWith("join ")) {
            joinChannel(message.substring(5));
        }
        else if (messageLc.startsWith("part ")) {
            String channel = message.substring(5);
            partChannel(channel);
            _channelSet.remove(channel.toLowerCase());
        }
        else if (messageLc.startsWith("ignore ") || messageLc.startsWith("remove ")) {
            String nick = message.substring(7);
            config.ignoreSet.add(nick.toLowerCase());
            Iterator graphIt = _graphs.values().iterator();
            while (graphIt.hasNext()) {
                Graph g = (Graph) graphIt.next();
                boolean changed = g.removeNode(new Node(nick));
                if (changed) {
                    makeNextImage(g.getLabel());
                }
            }
        }
        else if (messageLc.startsWith("draw ")) {
            StringTokenizer tokenizer = new StringTokenizer(message.substring(5));
            if (tokenizer.countTokens() >= 1) {
                String channel = tokenizer.nextToken();

                Graph graph = (Graph) _graphs.get(channel.toLowerCase());
                if (graph != null) {
                    try {
                        File file = (File) _lastFiles.get(channel.toLowerCase());
                        if (file != null) {
                            sendMessage(sender, "Trying to send \"" + file.getName() + "\"... If you have difficultly in recieving this file via DCC, there may be a firewall between us.");
                            dccSendFile(file, sender, 120000);
                        }
                        else {
                            sendMessage(sender, "I do not have enough information to draw a network for " + channel + " at the moment.");
                        }
                    }
                    catch (Exception e) {
                        sendMessage(sender, "Sorry, mate: " + e.toString());
                    }
                }
                else {
                    sendMessage(sender, "Sorry, I don't know much about that channel yet.");
                }
            }
            else {
                sendMessage(sender, "Example of correct use is \"draw <#channel> [weight threshold]\"");
            }
        }
        else {
            sendMessage(sender, "Sorry, I don't support that command yet.");
        }
    }
    
    protected void onAction(String sender, String login, String hostname, String target, String action) {
        if ("#&!+".indexOf(target.charAt(0)) >= 0) {
            onMessage(target, sender, login, hostname, action);
        }
    }
    
    protected void onJoin(String channel, String sender, String login, String hostname) {

        add(channel, sender);
        
        if (sender.equalsIgnoreCase(getNick())) {
            // Remember that we're meant to be in this channel
            _channelSet.add(channel.toLowerCase());
        }
    }
    
    protected void onUserList(String channel, User[] users) {
        for (int i = 0; i < users.length; i++) {
            add(channel, users[i].getNick());
        }
    }
    
    protected void onKick(String channel, String kickerNick, String kickerLogin, String kickerHostname, String recipientNick, String reason) {
        add(channel, kickerNick);
        add(channel, recipientNick);
        
        if (recipientNick.equalsIgnoreCase(getNick())) {
            joinChannel(channel);
        }
    }
    
    protected void onMode(String channel, String sourceNick, String sourceLogin, String sourceHostname, String mode) {
        add(channel, sourceNick);
    }
    
    protected void onNickChange(String oldNick, String login, String hostname, String newNick) {
        addToAll(oldNick);
        addToAll(newNick);
    }
    
    public void onDisconnect() {
        while (!isConnected()) {
            try {
                reconnect();
            }
            catch (Exception e) {
                try {
                    Thread.sleep(10*60*1000);
                }
                catch (InterruptedException ie) {
                    // do nothing
                }
            }
        }
        
        // We are now connected
        // Rejoin all channels
        Iterator it = _channelSet.iterator();
        while (it.hasNext()) {
            joinChannel((String) it.next());
        }
    }
    
    private void add(String channel, String nick) {

        if (config.ignoreSet.contains(nick.toLowerCase())) {
            return;
        }

        Node node = new Node(nick);
        channel = channel.toLowerCase();
        Graph graph = (Graph) _graphs.get(channel);
        if (graph == null) {
            if (config.createRestorePoints) {
                graph = readGraph(channel);
            }
            if (graph == null) {
                graph = new Graph(channel, config);
            }
            _graphs.put(channel, graph);
        }
        graph.addNode(node);
    }

    private void addToAll(String nick) {

        if (config.ignoreSet.contains(nick.toLowerCase())) {
            return;
        }

        Iterator graphIt = _graphs.values().iterator();
        while (graphIt.hasNext()) {
            Graph graph = (Graph) graphIt.next();
            graph.addNode(new Node(nick));
        }
    }
    
    private void addEdge(Graph graph, Node source, Node target) {
        boolean changed = graph.addEdge(source, target);
        if (changed) {
            makeNextImage(graph.getLabel());
        }
    }
    
    public boolean makeNextImage(String channel) {
        String strippedChannel = channel.substring(1);
        Graph g = (Graph) _graphs.get(channel.toLowerCase());
        
        File dir = new File(_outputDirectory, strippedChannel);
        dir.mkdir();
        
        if (g != null) {
            
            g.doLayout(config.springEmbedderIterations);
            g.calcBounds(config.outputWidth, config.outputHeight);
            
            try {
                
                int frameCount = g.getFrameCount();
                
                BufferedImage image = g.drawImage(channel, config.outputWidth, config.outputHeight, config.borderSize, config.nodeRadius, config.edgeThreshold, config.showEdges);

                // Write the archive image.
                File file = new File(dir, strippedChannel + "-" + _nf.format(frameCount) + ".png");
                if (config.createArchive) {
                    ImageIO.write(image, "png", file);
                }

                // Also save an image as channel-current.png.
                File current = new File(dir, strippedChannel + "-current.png");
                if (config.createCurrent) {
                    ImageIO.write(image, "png", current);
                }
                
                // Also serialize the graph object for later retrieval.
                if (config.createRestorePoints) {
                    writeGraph(channel, g);
                }
                
                _lastFiles.put(channel.toLowerCase(), file);
            }
            catch (Exception e) {
                System.out.println("PieSpy has gone wibbly: " + e);
                e.printStackTrace();
            }
        }
        
        return g != null;
    }
    
    private Graph readGraph(String channel) {
        Graph g = null;
        // Try and see if the graph can be restored from file.
        try {
            String strippedChannel = channel.toLowerCase().substring(1);
            
            File dir = new File(_outputDirectory, strippedChannel);
            File file = new File(dir, strippedChannel + "-restore.dat");
            ObjectInputStream ois = new ObjectInputStream(new FileInputStream(file));
            String version = (String) ois.readObject();
            if (version.equals(SocialNetworkBot.VERSION)) {
                g = (Graph) ois.readObject();
            }
            ois.close();
        }
        catch (Exception e) {
            // Do nothing?
        }
        return g;
    }
    
    public void writeGraph(String channel, Graph g) {
        try {
            String strippedChannel = channel.toLowerCase().substring(1);
            File dir = new File(_outputDirectory, strippedChannel);
            File file = new File(dir, strippedChannel + "-restore.dat");
            ObjectOutputStream oos = new ObjectOutputStream(new FileOutputStream(file));
            oos.writeObject(SocialNetworkBot.VERSION);
            oos.writeObject(g);
            oos.flush();
            oos.close();
        }
        catch (Exception e) {
            // Do nothing?
        }
    }
    
    public Configuration getConfig() {
        return config;
    }
    
    public void setCaption(String channel, String caption) {
        channel = channel.toLowerCase();
        Graph graph = (Graph) _graphs.get(channel);
        if (graph != null) {
            graph.setCaption(caption);
        }
    }

    public static void main(String[] args) throws Exception {
        
        Properties p = new Properties();
        String configFile = "./config.ini";
        if (args.length > 0) {
            configFile = args[0];
        }
        p.load(new FileInputStream(configFile));
        Configuration config = new Configuration(p);
        
        SocialNetworkBot bot = new SocialNetworkBot(config);
        bot.setVerbose(config.verbose);
        bot.setName(config.nick);
        bot.setLogin("piespy");
        bot.setVersion(VERSION + " http://www.jibble.org/piespy/");
        
        try {
            bot.setEncoding(config.encoding);
        }
        catch (UnsupportedEncodingException e) {
            // Stick with the platform default.
        }
        
        bot.connect(config.server, config.port, config.serverPassword);
        Iterator channelIt = config.channelSet.iterator();
        while (channelIt.hasNext()) {
            String channel = (String) channelIt.next();
            bot.joinChannel(channel);
        }
    }
    
    private HashMap _graphs = new HashMap();
    private HashMap _nickHistory = new HashMap();
    private File _outputDirectory;

    private HashMap _lastFiles = new HashMap();
    
    // Used to remember which channels we should be in
    private HashSet _channelSet = new HashSet();
    
    NumberFormat _nf;
    
    private Configuration config;
    
}