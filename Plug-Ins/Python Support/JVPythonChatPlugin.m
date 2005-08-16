#import "JVPythonChatPlugin.h"
#import "JVChatWindowController.h"
#import "JVChatMessage.h"
#import "JVChatRoomPanel.h"
#import "JVChatRoomMember.h"
#import "NSStringAdditions.h"

static PyObject *LoadArbitraryPythonModule( const char *name, const char *directory, const char *newname ) {
	if( ! name || ! directory ) return NULL;
	if( ! newname ) newname = name;

	PyObject *impModule = PyImport_ImportModule( "imp" );
	if( ! impModule ) return NULL;

	PyObject *result = PyObject_CallMethod( impModule, "find_module", "s[s]", name, directory );
	if( ! result || PyTuple_GET_SIZE( result ) != 3 ) return NULL;

	PyObject *ret = PyObject_CallMethod( impModule, "load_module", "sOOO", newname, PyTuple_GetItem( result, 0 ), PyTuple_GetItem( result, 1 ), PyTuple_GetItem( result, 2 ) );

	Py_DECREF( result );
	Py_DECREF( impModule );

	return ret;
}

NSString *JVPythonErrorDomain = @"JVPythonErrorDomain";

@implementation JVPythonChatPlugin
+ (void) initialize {
	static tooLate = NO;
	if( ! tooLate ) {
		Py_Initialize();
		PyObjC_ImportAPI( Py_None );
		tooLate = YES;
	}
}

- (id) initWithManager:(MVChatPluginManager *) manager {
	if( self = [self init] ) {
		_manager = manager;
		_path = nil;
		_modDate = [[NSDate date] retain];
	}

	return self;
}

- (id) initWithScriptAtPath:(NSString *) path withManager:(MVChatPluginManager *) manager {
	if( self = [self initWithManager:manager] ) {
		_path = [path copyWithZone:[self zone]];

		NSString *moduleName = [[path lastPathComponent] stringByDeletingPathExtension];
		NSString *moduleFolder = [path stringByDeletingLastPathComponent];
		_uniqueModuleName = [[NSString locallyUniqueString] retain];

		_scriptModule = LoadArbitraryPythonModule( [moduleName fileSystemRepresentation], [moduleFolder fileSystemRepresentation], [_uniqueModuleName UTF8String] );

		if( ! _scriptModule ) {
			PyErr_Print();
			PyErr_Clear();
			NSRunCriticalAlertPanel( NSLocalizedStringFromTableInBundle( @"Python Script Error", nil, [NSBundle bundleForClass:[self class]], "Python plugin error title" ), NSLocalizedStringFromTableInBundle( @"The Python script \"%@\" had an error while loading.", nil, [NSBundle bundleForClass:[self class]], "Python plugin error message" ), nil, nil, nil, [[path lastPathComponent] stringByDeletingPathExtension] );
			[self release];
			return nil;
		}

		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( checkForModifications: ) name:NSApplicationWillBecomeActiveNotification object:[NSApplication sharedApplication]];
	}

	return self;
}

- (void) dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];

	Py_XDECREF( _scriptModule );
	_scriptModule = NULL;

	[_path release];
	[_uniqueModuleName release];
	[_modDate release];

	_path = nil;
	_uniqueModuleName = nil;
	_manager = nil;
	_modDate = nil;

	[super dealloc];
}

#pragma mark -

- (MVChatPluginManager *) pluginManager {
	return _manager;
}

- (NSString *) scriptFilePath {
	return _path;
}

- (void) reloadFromDisk {
	[self performSelector:@selector( unload )];

	NSString *moduleName = [[[self scriptFilePath] lastPathComponent] stringByDeletingPathExtension];
	NSString *moduleFolder = [[self scriptFilePath] stringByDeletingLastPathComponent];

	Py_XDECREF( _scriptModule );
	_scriptModule = LoadArbitraryPythonModule( [moduleName fileSystemRepresentation], [moduleFolder fileSystemRepresentation], [_uniqueModuleName UTF8String] );

	if( ! _scriptModule ) {
		PyErr_Print();
		PyErr_Clear();
		NSRunCriticalAlertPanel( NSLocalizedStringFromTableInBundle( @"Python Script Error", nil, [NSBundle bundleForClass:[self class]], "Python plugin error title" ), NSLocalizedStringFromTableInBundle( @"The Python script \"%@\" had an error while loading.", nil, [NSBundle bundleForClass:[self class]], "Python plugin error message" ), nil, nil, nil, [[[self scriptFilePath] lastPathComponent] stringByDeletingPathExtension] );
		return;
	}

	[self performSelector:@selector( load )];
}

#pragma mark -

- (void) promptForReload {
	if( NSRunInformationalAlertPanel( NSLocalizedStringFromTableInBundle( @"Python Script Changed", nil, [NSBundle bundleForClass:[self class]], "Python script file changed dialog title" ), NSLocalizedStringFromTableInBundle( @"The Python script \"%@\" has changed on disk. Any script variables will reset if reloaded.", nil, [NSBundle bundleForClass:[self class]], "Python plugin changed on disk message" ), NSLocalizedStringFromTableInBundle( @"Reload", nil, [NSBundle bundleForClass:[self class]], "reload button title" ), NSLocalizedStringFromTableInBundle( @"Keep Previous Version", nil, [NSBundle bundleForClass:[self class]], "keep previous version button title" ), nil, [[[self scriptFilePath] lastPathComponent] stringByDeletingPathExtension] ) == NSOKButton ) {
		[self reloadFromDisk];
	}
}

- (void) checkForModifications:(NSNotification *) notification {
	if( ! [[self scriptFilePath] length] ) return;

	NSFileManager *fm = [NSFileManager defaultManager];
	NSString *path = [self scriptFilePath];

	// if we didn't originally load with a human editable file path,
	// try to find the human editable version and check it for changes
	if( ! [[path pathExtension] isEqualToString:@"py"] ) {
		path = [[self scriptFilePath] stringByDeletingPathExtension];
		path = [path stringByAppendingPathExtension:@"py"];
		if( ! [fm fileExistsAtPath:path] ) path = [self scriptFilePath];
	}

	if( [fm fileExistsAtPath:path] ) {
		NSDictionary *info = [fm fileAttributesAtPath:path traverseLink:YES];
		NSDate *fileModDate = [info fileModificationDate];
		if( [fileModDate compare:_modDate] == NSOrderedDescending && [fileModDate compare:[NSDate date]] == NSOrderedAscending ) { // newer script file
			[_modDate autorelease];
			_modDate = [[NSDate date] retain];
			[self performSelector:@selector( promptForReload ) withObject:nil afterDelay:0.];
		}
	}
}

#pragma mark -

- (id) callScriptFunctionNamed:(NSString *) functionName withArguments:(NSArray *) arguments forSelector:(SEL) selector {
	if( ! _scriptModule ) return nil;

	PyObject *dict = PyModule_GetDict( _scriptModule );
	if( ! dict ) return nil;

	PyObject *func = PyDict_GetItemString( dict, [functionName UTF8String] );

	if( func && PyCallable_Check( func ) ) {
		unsigned i = 0, count = [arguments count];
		PyObject *args = PyTuple_New( count );

		for( i = 0; i < count; i++ )
			PyTuple_SetItem( args, i, PyObjC_IdToPython( [arguments objectAtIndex:i] ) );

		PyObject *ret = PyObject_CallObject( func, args );

		id realRet = nil;
		if( ret ) realRet = PyObjC_PythonToId( ret );

        Py_XDECREF( ret );
        Py_DECREF( args );

		return realRet;
	}

	NSDictionary *error = [NSDictionary dictionaryWithObject:[NSString stringWithFormat:@"Function named \"%@\" could not be found or is not callable", functionName] forKey:NSLocalizedDescriptionKey];
	return [NSError errorWithDomain:JVPythonErrorDomain code:-1 userInfo:error];
}

#pragma mark -

- (void) load {
	NSArray *args = [NSArray arrayWithObjects:[self scriptFilePath], nil];
	[self callScriptFunctionNamed:@"load" withArguments:args forSelector:_cmd];
}

- (void) unload {
	[self callScriptFunctionNamed:@"unload" withArguments:nil forSelector:_cmd];
}

- (NSArray *) contextualMenuItemsForObject:(id) object inView:(id <JVChatViewController>) view {
	NSArray *args = [NSArray arrayWithObjects:object, view, nil];
	id result = [self callScriptFunctionNamed:@"contextualMenuItems" withArguments:args forSelector:_cmd];
	return ( [result isKindOfClass:[NSArray class]] ? result : nil );
}

- (void) performNotification:(NSString *) identifier withContextInfo:(NSDictionary *) context andPreferences:(NSDictionary *) preferences {
	NSArray *args = [NSArray arrayWithObjects:identifier, context, preferences, nil];
	[self callScriptFunctionNamed:@"performNotification" withArguments:args forSelector:_cmd];
}

- (BOOL) processUserCommand:(NSString *) command withArguments:(NSAttributedString *) arguments toConnection:(MVChatConnection *) connection inView:(id <JVChatViewController>) view {
	NSArray *args = [NSArray arrayWithObjects:command, arguments, connection, view, nil];
	id result = [self callScriptFunctionNamed:@"processUserCommand" withArguments:args forSelector:_cmd];
	return ( [result isKindOfClass:[NSNumber class]] ? [result boolValue] : NO );
}

- (BOOL) handleClickedLink:(NSURL *) url inView:(id <JVChatViewController>) view {
	NSArray *args = [NSArray arrayWithObjects:url, view, nil];
	id result = [self callScriptFunctionNamed:@"handleClickedLink" withArguments:args forSelector:_cmd];
	return ( [result isKindOfClass:[NSNumber class]] ? [result boolValue] : NO );
}

- (void) processIncomingMessage:(JVMutableChatMessage *) message inView:(id <JVChatViewController>) view {
	NSArray *args = [NSArray arrayWithObjects:message, view, nil];
	[self callScriptFunctionNamed:@"processIncomingMessage" withArguments:args forSelector:_cmd];
}

- (void) processOutgoingMessage:(JVMutableChatMessage *) message inView:(id <JVChatViewController>) view {
	NSArray *args = [NSArray arrayWithObjects:message, view, nil];
	[self callScriptFunctionNamed:@"processOutgoingMessage" withArguments:args forSelector:_cmd];
}

- (void) memberJoined:(JVChatRoomMember *) member inRoom:(JVChatRoomPanel *) room {
	NSArray *args = [NSArray arrayWithObjects:member, room, nil];
	[self callScriptFunctionNamed:@"memberJoined" withArguments:args forSelector:_cmd];
}

- (void) memberParted:(JVChatRoomMember *) member fromRoom:(JVChatRoomPanel *) room forReason:(NSAttributedString *) reason {
	NSArray *args = [NSArray arrayWithObjects:member, room, reason, nil];
	[self callScriptFunctionNamed:@"memberParted" withArguments:args forSelector:_cmd];
}

- (void) memberKicked:(JVChatRoomMember *) member fromRoom:(JVChatRoomPanel *) room by:(JVChatRoomMember *) by forReason:(NSAttributedString *) reason {
	NSArray *args = [NSArray arrayWithObjects:member, room, by, reason, nil];
	[self callScriptFunctionNamed:@"memberKicked" withArguments:args forSelector:_cmd];
}

- (void) joinedRoom:(JVChatRoomPanel *) room {
	NSArray *args = [NSArray arrayWithObject:room];
	[self callScriptFunctionNamed:@"joinedRoom" withArguments:args forSelector:_cmd];
}

- (void) partingFromRoom:(JVChatRoomPanel *) room {
	NSArray *args = [NSArray arrayWithObject:room];
	[self callScriptFunctionNamed:@"partingFromRoom" withArguments:args forSelector:_cmd];
}

- (void) kickedFromRoom:(JVChatRoomPanel *) room by:(JVChatRoomMember *) by forReason:(NSAttributedString *) reason {
	NSArray *args = [NSArray arrayWithObjects:room, by, reason, nil];
	[self callScriptFunctionNamed:@"kickedFromRoom" withArguments:args forSelector:_cmd];
}

- (void) topicChangedTo:(NSAttributedString *) topic inRoom:(JVChatRoomPanel *) room by:(JVChatRoomMember *) member {
	NSArray *args = [NSArray arrayWithObjects:topic, room, member, nil];
	[self callScriptFunctionNamed:@"topicChanged" withArguments:args forSelector:_cmd];
}

- (BOOL) processSubcodeRequest:(NSString *) command withArguments:(NSString *) arguments fromUser:(MVChatUser *) user {
	NSArray *args = [NSArray arrayWithObjects:command, arguments, user, nil];
	id result = [self callScriptFunctionNamed:@"processSubcodeRequest" withArguments:args forSelector:_cmd];
	return ( [result isKindOfClass:[NSNumber class]] ? [result boolValue] : NO );
}

- (BOOL) processSubcodeReply:(NSString *) command withArguments:(NSString *) arguments fromUser:(MVChatUser *) user {
	NSArray *args = [NSArray arrayWithObjects:command, arguments, user, nil];
	id result = [self callScriptFunctionNamed:@"processSubcodeReply" withArguments:args forSelector:_cmd];
	return ( [result isKindOfClass:[NSNumber class]] ? [result boolValue] : NO );
}

- (void) connected:(MVChatConnection *) connection {
	NSArray *args = [NSArray arrayWithObject:connection];
	[self callScriptFunctionNamed:@"connected" withArguments:args forSelector:_cmd];
}

- (void) disconnecting:(MVChatConnection *) connection {
	NSArray *args = [NSArray arrayWithObject:connection];
	[self callScriptFunctionNamed:@"disconnecting" withArguments:args forSelector:_cmd];
}
@end