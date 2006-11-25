// called on load and reload
function load( scriptFilePath ) {
}

// called on unload and relead
function unload() {
}

// return an array of NSMenuItems that should be dispalyed for 'item' associated with 'view'
function contextualMenuItems( item, view ) {
}

// process the command and return true if you handle it or false to pass on to another plugin
function processUserCommand( command, arguments, connection, view ) {
	// return true if the command was handled or to prevent other plugins or Colloquy from handling it
	return false;
}

// handle a ctcp request and return true if you handle it or false to pass on to another plugin
function processSubcodeRequest( command, arguments, user ) {
	// return true if the command was handled or to prevent other plugins or Colloquy from handling it
	return false;
}

// handle a ctcp reply and return true if you handle it or false to pass on to another plugin
function processSubcodeReply( command, arguments, user ) {
	// return true if the command was handled or to prevent other plugins or Colloquy from handling it
	return false;
}

// called when 'connection' connects
function connected( connection ) {
}

// called when 'connection' is disconnecting
function disconnecting( connection ) {
}

// perform a notification
function performNotification( identifier, context, preferences ) {
}

// called when an unhandled URL scheme is clicked in 'view'
function handleClickedLink( url, view ) {
	// return true if the link was handled or to prevent other plugins or Colloquy from handling it
	return false;
}

// called for each incoming message, the message is mutable
function processIncomingMessage( message, view ) {
}

// called for each outgoing message, the message is mutable
function processOutgoingMessage( message, view ) {
}

// called when a member joins 'room'
function memberJoined( member, room ) {
}

// called when a member parts 'room'
function memberParted( member, room ) {
}

// called when a member is kicked from 'room' for 'reason'
function memberKicked( member, room, by, reason ) {
}

// called when the local user joins 'room'
function joinedRoom( room ) {
}

// called when the local user is parting 'room'
function partingFromRoom( room ) {
}

// called when the local user is kicked from 'room' for 'reason'
function kickedFromRoom( room, by, reason ) {
}

// called when the topic changes in 'room' by 'user'
function topicChanged( topic, room, user ) {
}
