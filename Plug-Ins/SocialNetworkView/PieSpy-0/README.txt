This is an IRC bot based on the PircBot
Java IRC Bot Framework (www.jibble.org)

PieSpy can be downloaded from
http://www.jibble.org/piespy/

PieSpy is used to automatically generate
Social Network Diagrams of user interaction
on one or more IRC channels.

The bot will automatically write a new
image to the output directory each time
the network changes. Each image is numbered
to assist with the generation of animations.

The bot will try to reconnect and rejoin
channels if it becomes disconnected from the
server.

PieSpy can be configured by editing config.ini

PieSpy may be controlled by sending private
messages to the bot. The correct password
must be specified:

  /msg PieSpy [password] stats
    Replies with statistics about the size
    of the graphs that have currently been
    generated for all channels.

  /msg PieSpy [password] join #channel
    Tells the bot to join the specified
    channel.

  /msg PieSpy [password] part #channel
    Tells the bot to part the specified
    channel.

  /msg PieSpy [password] ignore nick
    Tell the bot to ignore all messages
    from the specified nick. You may find
    this useful if the bot is being abused.
    If the nick is already in the graph,
    the node will be removed.

  /msg PieSpy [password] remove nick
    An alias for the ignore command.

  /msg PieSpy [password] draw #channel
    Instructs the bot to send the current
    drawing of the graph for this channel.
    This image is stored in the output
    directory and is DCC'd to
    the user issuing this command.

  /msg PieSpy [password] raw [command]
    Tells the bot to send a raw command
    to the server. For example, the
    command could be "PRIVMSG Nick :Hi".

Sub directories are made in the output
directory to contain each individual
frame that is created. In addition, each
latest frame will be saved as
<channel>-current.png.

If you choose to save restore points, the
bot will maintain a file <channel>-restore.dat
which is used to store the graph data. If
you have to restart the bot, it can use this
data to continue from where it left off.

Temporal decay has now been included, which
ensures that old relationships fade out of
existance. This helps to maintains the
accuracy of the system while naturally limiting
the size of the graphs.

If you run the bot in several extremely busy
channels, make sure your computer is fast
enough to keep drawing the images in realtime.

Copyright Paul Mutton, 2002-2004.
http://www.jibble.org/piespy/