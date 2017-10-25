#import "JVPythonChatPlugin.h"
#import "JVChatWindowController.h"
#import "JVChatMessage.h"
#import "JVChatRoomPanel.h"
#import "JVChatRoomMember.h"
#import "JVToolbarItem.h"
#import "JVChatController.h"
#import "JVNotificationController.h"
#import "MVApplicationController.h"
#import <ChatCore/NSStringAdditions.h>
#import <ChatCore/MVChatConnection.h>
#import "pyobjc-api.h"

@interface JVPythonChatPlugin () <MVChatPluginCommandSupport, MVChatPluginContextualMenuSupport, MVChatPluginToolbarSupport, MVChatPluginNotificationSupport, MVChatPluginConnectionSupport, MVChatPluginRoomSupport, MVChatPluginDirectChatSupport, MVChatPluginLinkClickSupport>

@end

static PyObject *LoadArbitraryPythonModule( const char *name, const char *directory, const char *newname ) {
	if( ! name || ! directory ) return NULL;
	if( ! newname ) newname = name;

	PyObject *impModule = PyImport_ImportModule( (char *) "imp" );
	if( ! impModule ) return NULL;

	PyObject *result = PyObject_CallMethod( impModule, (char *) "find_module", (char *) "s[s]", name, directory );
	if( ! result || PyTuple_Size( result ) != 3 ) return NULL;

	PyObject *ret = PyObject_CallMethod( impModule, (char *) "load_module", (char *) "sOOO", newname, PyTuple_GetItem( result, 0 ), PyTuple_GetItem( result, 1 ), PyTuple_GetItem( result, 2 ) );

	Py_DECREF( result );
	Py_DECREF( impModule );

	return ret;
}

NSString *JVPythonErrorDomain = @"JVPythonErrorDomain";

@implementation JVPythonChatPlugin
@synthesize scriptFilePath = _path;
@synthesize pluginManager = _manager;

+ (void) initialize {
	static BOOL tooLate = NO;
	if( ! tooLate ) {
		Py_Initialize();
		PyObjC_ImportAPI( Py_None );
		tooLate = YES;
	}
}

- (instancetype) initWithManager:(MVChatPluginManager *) manager {
	if( ( self = [self init] ) ) {
		_manager = manager;
		_path = nil;
		_modDate = [NSDate date];
	}

	return self;
}

- (instancetype) initWithScriptAtPath:(NSString *) path withManager:(MVChatPluginManager *) manager {
	if( ( self = [self initWithManager:manager] ) ) {
		_path = [path copy];
		_uniqueModuleName = [NSString locallyUniqueString];
		_firstLoad = YES;

		[self reloadFromDisk];

		_firstLoad = NO;

		if( ! _scriptModule ) {
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


	_path = nil;
	_uniqueModuleName = nil;
	_manager = nil;
	_modDate = nil;

}

#pragma mark -

- (void) reloadFromDisk {
	[self unload];

	NSString *moduleName = [[[self scriptFilePath] lastPathComponent] stringByDeletingPathExtension];
	NSString *moduleFolder = [[self scriptFilePath] stringByDeletingLastPathComponent];

	Py_XDECREF( _scriptModule );
	_scriptModule = LoadArbitraryPythonModule( [moduleName fileSystemRepresentation], [moduleFolder fileSystemRepresentation], [_uniqueModuleName UTF8String] );

	if( [self reportErrorIfNeededInFunction:nil] || ! _scriptModule )
		return;

	if( ! _firstLoad ) [self load];
}

#pragma mark -

- (void) promptForReload {
	NSAlert *alert = [[NSAlert alloc] init];
	alert.messageText = NSLocalizedStringFromTableInBundle( @"Python Script Changed", nil, [NSBundle bundleForClass:[self class]], "Python script file changed dialog title" );
	alert.informativeText = [NSString stringWithFormat:NSLocalizedStringFromTableInBundle( @"The Python script \"%@\" has changed on disk. Any script variables will reset if reloaded.", nil, [NSBundle bundleForClass:[self class]], "Python script changed on disk message" ), [[[self scriptFilePath] lastPathComponent] stringByDeletingPathExtension]];
	alert.alertStyle = NSAlertStyleInformational;
	[alert addButtonWithTitle:NSLocalizedStringFromTableInBundle( @"Reload", nil, [NSBundle bundleForClass:[self class]], "reload button title" )];
	[alert addButtonWithTitle:NSLocalizedStringFromTableInBundle( @"Keep Previous Version", nil, [NSBundle bundleForClass:[self class]], "keep previous version button title" )];
	NSModalResponse response = [alert runModal];
	
	if( response == NSAlertFirstButtonReturn ) {
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
		NSDictionary *info = [fm attributesOfItemAtPath:[self scriptFilePath] error:nil];
		NSDate *fileModDate = [info fileModificationDate];
		if( [fileModDate compare:_modDate] == NSOrderedDescending && [fileModDate compare:[NSDate date]] == NSOrderedAscending ) { // newer script file
			_modDate = [NSDate date];
			[self performSelector:@selector( promptForReload ) withObject:nil afterDelay:0.];
		}
	}
}

#pragma mark -

- (BOOL) reportErrorIfNeededInFunction:(NSString *) functionName {
	if( PyErr_Occurred() ) {
		PyObject *errType = NULL, *errValue = NULL, *errTrace = NULL;
		PyErr_Fetch( &errType, &errValue, &errTrace );
		if( ! errType ) return NO;

		PyErr_NormalizeException( &errType, &errValue, &errTrace );

		NSMutableString *errorDesc = [[NSMutableString alloc] initWithCapacity:64];

		PyObject *message = errValue;
		char *filename = NULL;
		int line = -1;

		if( PyErr_GivenExceptionMatches( errType, PyExc_SyntaxError ) ) {
			if( PyTuple_Check( errValue ) ) {
				// old style tuple errors
				PyArg_Parse( errValue, (char *) "(O(zi))", &message, &filename, &line );
			} else {
				// new style errors
				PyObject *value = NULL;
				if( ( value = PyObject_GetAttrString( errValue, (char *) "msg" ) ) )
					message = value;

				if( ( value = PyObject_GetAttrString( errValue, (char *) "filename" ) ) ) {
					if( value == Py_None )
						filename = NULL;
					else filename = PyString_AsString( value );
					Py_DECREF( value );
				}

				if( ( value = PyObject_GetAttrString( errValue, (char *) "lineno" ) ) && value != Py_None ) {
					long hold = PyInt_AsLong( value );
					Py_DECREF( value );

					if( ! ( hold == -1 && PyErr_Occurred() ) )
						line = (int) hold;
				}
			}
		} else if( errTrace ) {
			PyObject *errFrame = PyObject_GetAttrString( errTrace, (char *) "tb_frame" );
			if( errFrame && errFrame != Py_None ) {
				PyObject *value = NULL;

				PyObject *code = PyObject_GetAttrString( errFrame, (char *) "f_code" );
				if( code && code != Py_None && ( value = PyObject_GetAttrString( code, (char *) "co_filename" ) ) ) {
					if( value == Py_None )
						filename = NULL;
					else filename = PyString_AsString( value );
					Py_DECREF( value );
				}

				if( ( value = PyObject_GetAttrString( errFrame, (char *) "f_lineno" ) ) && value != Py_None ) {
					long hold = PyInt_AsLong( value );
					Py_DECREF( value );

					if( ! ( hold == -1 && PyErr_Occurred() ) )
						line = (int) hold;
				}
			}
		}

		char *str = NULL;
		PyObject *strObj = PyObject_Str( errType );
		if( strObj && ( str = PyString_AsString( strObj ) ) ) {
			NSString *errorName = @(str);
			if( [errorName hasPrefix:@"exceptions."] )
				errorName = [errorName substringFromIndex:[@"exceptions." length]];
			[errorDesc appendString:errorName];
			Py_DECREF( strObj );
		} else [errorDesc appendString:NSLocalizedStringFromTableInBundle( @"Unknown Error", nil, [NSBundle bundleForClass:[self class]], "unknown error" )];

		if( message && ( strObj = PyObject_Str( message ) ) && ( str = PyString_AsString( strObj ) ) ) {
			[errorDesc appendString:NSLocalizedStringFromTableInBundle( @": ", nil, [NSBundle bundleForClass:[self class]], "error reason prefix" )];
			[errorDesc appendString:@(str)];
			Py_DECREF( strObj );
		}

		if( line != -1 ) {
			[errorDesc appendString:@"\n"];
			[errorDesc appendFormat:NSLocalizedStringFromTableInBundle( @"Line number: %d", nil, [NSBundle bundleForClass:[self class]], "error line number" ), line];
		}

		NSString *scriptTitle = [[[self scriptFilePath] lastPathComponent] stringByDeletingPathExtension];
		
		NSString *informativeText;
		if( functionName ) {
			informativeText = [NSString stringWithFormat:NSLocalizedStringFromTableInBundle( @"The Python script \"%@\" had an error while calling the \"%@\" function.\n\n%@", nil, [NSBundle bundleForClass:[self class]], "Python script plugin error message" ), scriptTitle, functionName, errorDesc];
		} else {
			informativeText = [NSString stringWithFormat:NSLocalizedStringFromTableInBundle( @"The Python script \"%@\" had an error while loading.\n\n%@", nil, [NSBundle bundleForClass:[self class]], "Python script error message" ), scriptTitle, errorDesc];
		}
		
		_errorShown = YES;
		
		NSAlert *alert = [[NSAlert alloc] init];
		alert.messageText = NSLocalizedStringFromTableInBundle( @"Python Script Error", nil, [NSBundle bundleForClass:[self class]], "Python script error title" );
		alert.informativeText = informativeText;
		alert.alertStyle = NSAlertStyleInformational;
		[alert addButtonWithTitle:NSLocalizedString( @"OK", @"OK button title" )];
		if (filename != NULL) {
			[alert addButtonWithTitle:NSLocalizedStringFromTableInBundle( @"Edit...", nil, [NSBundle bundleForClass:[self class]], "edit button title" )];
		}
		NSModalResponse response = [alert runModal];
		
		_errorShown = NO;
		
		if( response == NSAlertSecondButtonReturn && filename ) {
			[[NSWorkspace sharedWorkspace] openFile:@(filename)];
		}
		
		NSLog(@"Python plugin script error in %@:", scriptTitle);
		PyErr_Restore( errType, errValue, errTrace );
		PyErr_Print();
		PyErr_Clear();

		if( message != errValue ) {
			Py_XDECREF( message );
		}

		Py_XDECREF(errType);
		Py_XDECREF(errValue);
		Py_XDECREF(errTrace);

		return YES;
	}

	return NO;
}

- (id) callScriptFunctionNamed:(NSString *) functionName withArguments:(NSArray *) arguments forSelector:(SEL) selector {
	if( ! _scriptModule ) return nil;

    PyGILState_STATE state;
	
	PyObject *dict = PyModule_GetDict( _scriptModule );
	if( ! dict ) return nil;

	PyObject *func = PyDict_GetItemString( dict, [functionName UTF8String] );

	if( func && PyCallable_Check( func ) ) {
		NSUInteger i = 0, count = [arguments count];
		PyObject *args = PyTuple_New( count );
		if( ! args ) return nil;

		for( i = 0; i < count; i++ ) {
			id object = arguments[i];
			if( [object isKindOfClass:[NSNull class]] ) {
				Py_INCREF( Py_None );
				PyTuple_SetItem( args, i, Py_None );
			} else PyTuple_SetItem( args, i, PyObjC_IdToPython( object ) );
		}

		state = PyGILState_Ensure();
		PyObject *ret = PyObject_CallObject( func, args );

		id realRet = nil;
		if( ret ) realRet = PyObjC_PythonToId( ret );

		Py_XDECREF( ret );
		Py_DECREF( args );
		
		[self reportErrorIfNeededInFunction:functionName];

		PyGILState_Release(state);

		return realRet;
	}

	NSDictionary *error = @{NSLocalizedDescriptionKey: [[NSString alloc] initWithFormat:@"Function named \"%@\" could not be found or is not callable", functionName]};
	return [NSError errorWithDomain:JVPythonErrorDomain code:-1 userInfo:error];
}

#pragma mark -

- (void) load {
	NSArray *args = @[[self scriptFilePath]];
	[self callScriptFunctionNamed:@"load" withArguments:args forSelector:_cmd];
}

- (void) unload {
	[self callScriptFunctionNamed:@"unload" withArguments:nil forSelector:_cmd];
}

- (NSArray *) contextualMenuItemsForObject:(id) object inView:(id <JVChatViewController>) view {
	NSArray *args = @[( object ? (id)object : (id)[NSNull null] ), ( view ? (id)view : (id)[NSNull null] )];
	id result = [self callScriptFunctionNamed:@"contextualMenuItems" withArguments:args forSelector:_cmd];
	return ( [result isKindOfClass:[NSArray class]] ? result : nil );
}

- (NSArray *) toolbarItemIdentifiersForView:(id <JVChatViewController>) view {
	NSArray *args = @[view];
	id result = [self callScriptFunctionNamed:@"toolbarItemIdentifiers" withArguments:args forSelector:_cmd];
	return ( [result isKindOfClass:[NSArray class]] ? result : nil );
}

- (NSToolbarItem *) toolbarItemForIdentifier:(NSString *) identifier inView:(id <JVChatViewController>) view willBeInsertedIntoToolbar:(BOOL) willBeInserted {
	NSArray *args = @[identifier, view, @(willBeInserted)];
	JVToolbarItem *result = [self callScriptFunctionNamed:@"toolbarItem" withArguments:args forSelector:_cmd];
	if( [result isKindOfClass:[JVToolbarItem class]] ) {
		[result setTarget:self];
		[result setAction:@selector( handleClickedToolbarItem: )];
		[result setRepresentedObject:view];
		return result;
	}

	return nil;
}

- (void) handleClickedToolbarItem:(JVToolbarItem *) sender {
	NSArray *args = @[sender, [sender representedObject]];
	[self callScriptFunctionNamed:@"handleClickedToolbarItem" withArguments:args forSelector:_cmd];
}

- (void) performNotification:(NSString *) identifier withContextInfo:(NSDictionary *) context andPreferences:(NSDictionary *) preferences {
	NSArray *args = @[identifier, ( context ? (id)context : (id)[NSNull null] ), ( preferences ? (id)preferences : (id)[NSNull null] )];
	[self callScriptFunctionNamed:@"performNotification" withArguments:args forSelector:_cmd];
}

- (BOOL) processUserCommand:(NSString *) command withArguments:(NSAttributedString *) arguments toConnection:(MVChatConnection *) connection inView:(id <JVChatViewController>) view {
	NSArray *args = @[command, ( arguments ? (id)arguments : (id)[NSNull null] ), ( connection ? (id)connection : (id)[NSNull null] ), ( view ? (id)view : (id)[NSNull null] )];
	id result = [self callScriptFunctionNamed:@"processUserCommand" withArguments:args forSelector:_cmd];
	if( [[result description] isEqualToString:@"True"] )
		return YES;
	return ( [result isKindOfClass:[NSNumber class]] ? [result boolValue] : NO );
}

- (BOOL) handleClickedLink:(NSURL *) url inView:(id <JVChatViewController>) view {
	NSArray *args = @[url, ( view ? (id)view : (id)[NSNull null] )];
	id result = [self callScriptFunctionNamed:@"handleClickedLink" withArguments:args forSelector:_cmd];
	if( [[result description] isEqualToString:@"True"] )
		return YES;
	return ( [result isKindOfClass:[NSNumber class]] ? [result boolValue] : NO );
}

- (void) processIncomingMessage:(JVMutableChatMessage *) message inView:(id <JVChatViewController>) view {
	NSArray *args = @[message, view];
	[self callScriptFunctionNamed:@"processIncomingMessage" withArguments:args forSelector:_cmd];
}

- (void) processOutgoingMessage:(JVMutableChatMessage *) message inView:(id <JVChatViewController>) view {
	NSArray *args = @[message, view];
	[self callScriptFunctionNamed:@"processOutgoingMessage" withArguments:args forSelector:_cmd];
}

- (void) memberJoined:(JVChatRoomMember *) member inRoom:(JVChatRoomPanel *) room {
	NSArray *args = @[member, room];
	[self callScriptFunctionNamed:@"memberJoined" withArguments:args forSelector:_cmd];
}

- (void) memberParted:(JVChatRoomMember *) member fromRoom:(JVChatRoomPanel *) room forReason:(NSAttributedString *) reason {
	NSArray *args = @[member, room, ( reason ? (id)reason : (id)[NSNull null] )];
	[self callScriptFunctionNamed:@"memberParted" withArguments:args forSelector:_cmd];
}

- (void) memberKicked:(JVChatRoomMember *) member fromRoom:(JVChatRoomPanel *) room by:(JVChatRoomMember *) by forReason:(NSAttributedString *) reason {
	NSArray *args = @[member, room, ( by ? (id)by : (id)[NSNull null] ), ( reason ? (id)reason : (id)[NSNull null] )];
	[self callScriptFunctionNamed:@"memberKicked" withArguments:args forSelector:_cmd];
}

- (void) joinedRoom:(JVChatRoomPanel *) room {
	NSArray *args = @[room];
	[self callScriptFunctionNamed:@"joinedRoom" withArguments:args forSelector:_cmd];
}

- (void) partingFromRoom:(JVChatRoomPanel *) room {
	NSArray *args = @[room];
	[self callScriptFunctionNamed:@"partingFromRoom" withArguments:args forSelector:_cmd];
}

- (void) kickedFromRoom:(JVChatRoomPanel *) room by:(JVChatRoomMember *) by forReason:(NSAttributedString *) reason {
	NSArray *args = @[room, ( by ? (id)by : (id)[NSNull null] ), ( reason ? (id)reason : (id)[NSNull null] )];
	[self callScriptFunctionNamed:@"kickedFromRoom" withArguments:args forSelector:_cmd];
}

- (void) topicChangedTo:(NSAttributedString *) topic inRoom:(JVChatRoomPanel *) room by:(JVChatRoomMember *) member {
	NSArray *args = @[topic, room, ( member ? (id)member : (id)[NSNull null] )];
	[self callScriptFunctionNamed:@"topicChanged" withArguments:args forSelector:_cmd];
}

- (BOOL) processSubcodeRequest:(NSString *) command withArguments:(NSString *) arguments fromUser:(MVChatUser *) user {
	NSArray *args = @[command, ( arguments ? (id)arguments : (id)[NSNull null] ), user];
	id result = [self callScriptFunctionNamed:@"processSubcodeRequest" withArguments:args forSelector:_cmd];
	if( [[result description] isEqualToString:@"True"] )
		return YES;
	return ( [result isKindOfClass:[NSNumber class]] ? [result boolValue] : NO );
}

- (BOOL) processSubcodeReply:(NSString *) command withArguments:(NSString *) arguments fromUser:(MVChatUser *) user {
	NSArray *args = @[command, ( arguments ? (id)arguments : (id)[NSNull null] ), user];
	id result = [self callScriptFunctionNamed:@"processSubcodeReply" withArguments:args forSelector:_cmd];
	if( [[result description] isEqualToString:@"True"] )
		return YES;
	return ( [result isKindOfClass:[NSNumber class]] ? [result boolValue] : NO );
}

- (void) connected:(MVChatConnection *) connection {
	NSArray *args = @[connection];
	[self callScriptFunctionNamed:@"connected" withArguments:args forSelector:_cmd];
}

- (void) disconnecting:(MVChatConnection *) connection {
	NSArray *args = @[connection];
	[self callScriptFunctionNamed:@"disconnecting" withArguments:args forSelector:_cmd];
}
@end
