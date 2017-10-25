#import "JVFScriptChatPlugin.h"
#import "JVChatWindowController.h"
#import "JVChatMessage.h"
#import "JVChatRoomPanel.h"
#import "JVChatRoomMember.h"
#import "JVChatController.h"
#import "JVNotificationController.h"
#import "MVApplicationController.h"
#import <ChatCore/MVChatConnection.h>

#import <FScript/FScript.h>

NSString *JVFScriptErrorDomain = @"JVFScriptErrorDomain";

@interface BlockStackElem : NSObject <NSCoding> {}
@property (readonly, copy) Block *block;
@property (readonly, copy) NSString *errorStr;
@property (readonly) int firstCharIndex;
@property (readonly) int lastCharIndex;
@end

@interface JVFScriptChatPlugin () <MVChatPluginCommandSupport, MVChatPluginContextualMenuSupport, MVChatPluginToolbarSupport, MVChatPluginNotificationSupport, MVChatPluginConnectionSupport, MVChatPluginRoomSupport, MVChatPluginDirectChatSupport, MVChatPluginLinkClickSupport>

@end

#pragma mark -

@implementation JVFScriptChatPlugin
- (instancetype) initWithManager:(MVChatPluginManager *) manager {
	if( ( self = [self init] ) ) {
		_manager = manager;
		_scriptInterpreter = nil;
		_path = nil;
		_modDate = [[NSDate date] retain];
	}

	return self;
}

- (instancetype) initWithScriptAtPath:(NSString *) path withManager:(MVChatPluginManager *) manager {
	if( ( self = [self initWithManager:manager] ) ) {
		_path = [path copyWithZone:[self zone]];
		_scriptInterpreter = [[FSInterpreter interpreter] retain];
		if( ! _scriptInterpreter ) {
			[self release];
			return nil;
		}

		NSString *contents = [[NSString alloc] initWithContentsOfFile:path encoding:NSUTF8StringEncoding error:NULL];

		FSInterpreterResult *result = [[self scriptInterpreter] execute:contents];
		[contents release];
		if( ! [result isOk] ) {
			NSAlert *alert = [[NSAlert alloc] init];
			alert.messageText = NSLocalizedStringFromTableInBundle( @"F-Script Plugin Error", nil, [NSBundle bundleForClass:[self class]], "F-Script plugin error title" );
			alert.informativeText = [NSString stringWithFormat:NSLocalizedStringFromTableInBundle( @"The F-Script plugin \"%@\" had an error while loading. The error occured near character %d.\n\n%@", nil, [NSBundle bundleForClass:[self class]], "F-Script plugin error message" ), [[path lastPathComponent] stringByDeletingPathExtension], [result errorRange].location, [result errorMessage]];
			alert.alertStyle = NSAlertStyleCritical;
			[alert runModal];
			[alert release];

			[self release];
			return nil;
		}

		[[self scriptInterpreter] setObject:self forIdentifier:@"scriptPlugin"];

		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( checkForModifications: ) name:NSApplicationWillBecomeActiveNotification object:[NSApplication sharedApplication]];
	}

	return self;
}

- (void) dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];

	[_scriptInterpreter release];
	[_path release];
	[_modDate release];

	_scriptInterpreter = nil;
	_path = nil;
	_manager = nil;
	_modDate = nil;

	[super dealloc];
}

- (oneway void) release {
	NSUInteger retainCount = [self retainCount] - 1;
	if( retainCount == 1 ) {
		id temp = _scriptInterpreter;
		_scriptInterpreter = nil;
		[temp release];
	}
	[super release];
}

#pragma mark -

@synthesize pluginManager = _manager;

- (FSInterpreter *) scriptInterpreter {
	return _scriptInterpreter;
}

- (NSString *) scriptFilePath {
	return _path;
}

- (void) reloadFromDisk {
	[self performSelector:@selector( unload )];

	NSString *identifier = nil;
	NSEnumerator *enumerator = [[[[[self scriptInterpreter] identifiers] copy] autorelease] objectEnumerator];
	while( ( identifier = [enumerator nextObject] ) )
		if( ! [identifier isEqualToString:@"sys"] )
			[[self scriptInterpreter] setObject:nil forIdentifier:identifier];

	NSString *contents = [[NSString alloc] initWithContentsOfFile:[self scriptFilePath] encoding:NSUTF8StringEncoding error:NULL];

	FSInterpreterResult *result = [[self scriptInterpreter] execute:contents];
	[contents release];

	[self performSelector:@selector( load )];

	if( ! [result isOk] ) {
		NSAlert *alert = [[NSAlert alloc] init];
		alert.messageText = NSLocalizedStringFromTableInBundle( @"F-Script Plugin Error", nil, [NSBundle bundleForClass:[self class]], "F-Script plugin error title" );
		alert.informativeText = [NSString stringWithFormat:NSLocalizedStringFromTableInBundle( @"The F-Script plugin \"%@\" had an error while loading. The error occured near character %d.\n\n%@", nil, [NSBundle bundleForClass:[self class]], "F-Script plugin error message" ), [[[self scriptFilePath] lastPathComponent] stringByDeletingPathExtension], [result errorRange].location, [result errorMessage]];
		alert.alertStyle = NSAlertStyleCritical;
		[alert runModal];
		[alert release];
		
		return;
	}

	[[self scriptInterpreter] setObject:self forIdentifier:@"scriptPlugin"];
}

- (void) inspectVariableNamed:(NSString *) variableName {
	BOOL found = NO;
	id object = [[self scriptInterpreter] objectForIdentifier:variableName found:&found];

	if( found && [object respondsToSelector:@selector( inspect )] ) {
		[object inspect];
	} else if( found ) {
		[[self scriptInterpreter] browse:object];
	}
}

#pragma mark -

- (void) promptForReload {
	NSAlert *alert = [[NSAlert alloc] init];
	alert.messageText = NSLocalizedStringFromTableInBundle( @"F-Script Plugin Changed", nil, [NSBundle bundleForClass:[self class]], "F-Script plugin file changed dialog title" );
	alert.informativeText = [NSString stringWithFormat:NSLocalizedStringFromTableInBundle( @"The F-Script plugin \"%@\" has changed on disk. Any script variables will reset if reloaded. All local block modifications will also be lost.", nil, [NSBundle bundleForClass:[self class]], "F-Script plugin changed on disk message" ), [[[self scriptFilePath] lastPathComponent] stringByDeletingPathExtension]];
	alert.alertStyle = NSAlertStyleInformational;
	[alert addButtonWithTitle:NSLocalizedStringFromTableInBundle( @"Reload", nil, [NSBundle bundleForClass:[self class]], "reload button title" )];
	[alert addButtonWithTitle:NSLocalizedStringFromTableInBundle( @"Keep Previous Version", nil, [NSBundle bundleForClass:[self class]], "keep previous version button title" )];
	NSModalResponse response = [alert runModal];
	[alert release];
	
	if( response == NSAlertFirstButtonReturn ) {
		[self reloadFromDisk];
	}
}

- (void) checkForModifications:(NSNotification *) notification {
	if( [self scriptFilePath] && [[NSFileManager defaultManager] fileExistsAtPath:[self scriptFilePath]] ) {
		NSDictionary *info = [[NSFileManager defaultManager] attributesOfItemAtPath:[self scriptFilePath] error:nil];
		NSDate *fileModDate = [info fileModificationDate];
		if( [fileModDate compare:_modDate] == NSOrderedDescending && [fileModDate compare:[NSDate date]] == NSOrderedAscending ) { // newer script file
			[_modDate autorelease];
			_modDate = [[NSDate date] retain];
			[self performSelector:@selector( promptForReload ) withObject:nil afterDelay:0.];
		}
	}
}

#pragma mark -

- (id) callScriptBlockNamed:(NSString *) blockName withArguments:(NSArray *) arguments forSelector:(SEL) selector {
	BOOL found = NO;
	id object = [[self scriptInterpreter] objectForIdentifier:blockName found:&found];

	if( found && [object isKindOfClass:[Block class]] ) {
		if( ! arguments ) arguments = @[[NSNull null]];
		if( (unsigned)[(Block *)object argumentCount] > [arguments count] ) {
			NSMutableArray *newArgs = [[arguments mutableCopy] autorelease];
			for( NSUInteger i = [arguments count]; i < (NSUInteger)[(Block *)object argumentCount]; i++ )
				[newArgs addObject:[NSNull null]];
			arguments = newArgs;
		}

		@try {
			id returnValue = [(Block *)object valueWithArguments:arguments];
			if( [returnValue isKindOfClass:[FSBoolean class]] ) {
				BOOL returnBool = ( [returnValue isEqual:[FSBoolean fsTrue]] ? YES : NO );
				return @(returnBool);
			} else {
				return returnValue;
			}
		} @catch ( NSException *exception ) {
			if( ! _errorShown ) {
				BlockStackElem *stack = [[exception userInfo][@"blockStack"] lastObject];
				NSString *locationError = @"";
				if( stack ) locationError = [NSString stringWithFormat:@" The error occured near character %d inside the block.", [stack firstCharIndex]];

				_errorShown = YES;
				
				NSAlert *alert = [[NSAlert alloc] init];
				alert.messageText = NSLocalizedStringFromTableInBundle( @"F-Script Plugin Error", nil, [NSBundle bundleForClass:[self class]], "F-Script plugin error title" );
				alert.informativeText = [NSString stringWithFormat:NSLocalizedStringFromTableInBundle( @"The F-Script plugin \"%@\" had an error while calling the \"%@\" block.%@\n\n%@", nil, [NSBundle bundleForClass:[self class]], "F-Script plugin error message" ), [[[self scriptFilePath] lastPathComponent] stringByDeletingPathExtension], blockName, locationError, [exception reason]];
				alert.alertStyle = NSAlertStyleCritical;
				[alert addButtonWithTitle:NSLocalizedString( @"OK", @"OK button title" )];
				[alert addButtonWithTitle:NSLocalizedStringFromTableInBundle( @"Inspect", nil, [NSBundle bundleForClass:[self class]], "inspect button title" )];
				[alert addButtonWithTitle:NSLocalizedStringFromTableInBundle( @"Edit...", nil, [NSBundle bundleForClass:[self class]], "edit button title" )];
				NSModalResponse response = [alert runModal];
				[alert release];
				
				_errorShown = NO;
				
				if( response == NSAlertSecondButtonReturn ) {
					if( stack && [stack lastCharIndex] != -1 ) [(Block *)object showError:[stack errorStr] start:[stack firstCharIndex] end:[stack lastCharIndex]];
					else if( stack ) [(Block *)object showError:[stack errorStr]];
					else [(Block *)object inspect];
				} else if( response == NSAlertThirdButtonReturn ) {
					[[NSWorkspace sharedWorkspace] openFile:[self scriptFilePath]];
				}
			}
		}
	}

	NSDictionary *error = @{NSLocalizedDescriptionKey: [[NSString alloc] initWithFormat:@"Block with identifier \"%@\" not found", blockName]};
	return [NSError errorWithDomain:JVFScriptErrorDomain code:-1 userInfo:error];
}

#pragma mark -

- (void) load {
	NSArray *args = @[[self scriptFilePath]];
	[self callScriptBlockNamed:@"load" withArguments:args forSelector:_cmd];
}

- (void) unload {
	[self callScriptBlockNamed:@"unload" withArguments:nil forSelector:_cmd];
}

- (NSArray *) contextualMenuItemsForObject:(id) object inView:(id <JVChatViewController>) view {
	NSArray *args = @[( object ? (id)object : (id)[NSNull null] ), ( view ? (id)view : (id)[NSNull null] )];
	id result = [self callScriptBlockNamed:@"contextualMenuItems" withArguments:args forSelector:_cmd];
	return ( [result isKindOfClass:[NSArray class]] ? result : nil );
}

- (NSArray *) toolbarItemIdentifiersForView:(id <JVChatViewController>) view {
	NSArray *args = @[view];
	id result = [self callScriptBlockNamed:@"toolbarItemIdentifiers" withArguments:args forSelector:_cmd];
	return ( [result isKindOfClass:[NSArray class]] ? result : nil );
}

- (NSToolbarItem *) toolbarItemForIdentifier:(NSString *) identifier inView:(id <JVChatViewController>) view willBeInsertedIntoToolbar:(BOOL) willBeInserted {
	NSArray *args = @[identifier, view, @(willBeInserted)];
	id result = [self callScriptBlockNamed:@"toolbarItem" withArguments:args forSelector:_cmd];
	return ( [result isKindOfClass:[NSToolbarItem class]] ? result : nil );
}

- (void) performNotification:(NSString *) identifier withContextInfo:(NSDictionary *) context andPreferences:(NSDictionary *) preferences {
	NSArray *args = @[identifier, ( context ? (id)context : (id)[NSNull null] ), ( preferences ? (id)preferences : (id)[NSNull null] )];
	[self callScriptBlockNamed:@"performNotification" withArguments:args forSelector:_cmd];
}

- (BOOL) processUserCommand:(NSString *) command withArguments:(NSAttributedString *) arguments toConnection:(MVChatConnection *) connection inView:(id <JVChatViewController>) view {
	NSArray *args = @[command, ( arguments ? (id)arguments : (id)[NSNull null] ), ( connection ? (id)connection : (id)[NSNull null] ), ( view ? (id)view : (id)[NSNull null] )];
	id result = [self callScriptBlockNamed:@"processUserCommand" withArguments:args forSelector:_cmd];
	return ( [result isKindOfClass:[NSNumber class]] ? [result boolValue] : NO );
}

- (BOOL) handleClickedLink:(NSURL *) url inView:(id <JVChatViewController>) view {
	NSArray *args = @[url, ( view ? (id)view : (id)[NSNull null] )];
	id result = [self callScriptBlockNamed:@"handleClickedLink" withArguments:args forSelector:_cmd];
	return ( [result isKindOfClass:[NSNumber class]] ? [result boolValue] : NO );
}

- (void) processIncomingMessage:(JVMutableChatMessage *) message inView:(id <JVChatViewController>) view {
	NSArray *args = @[message, view];
	[self callScriptBlockNamed:@"processIncomingMessage" withArguments:args forSelector:_cmd];
}

- (void) processOutgoingMessage:(JVMutableChatMessage *) message inView:(id <JVChatViewController>) view {
	NSArray *args = @[message, view];
	[self callScriptBlockNamed:@"processOutgoingMessage" withArguments:args forSelector:_cmd];
}

- (void) memberJoined:(JVChatRoomMember *) member inRoom:(JVChatRoomPanel *) room {
	NSArray *args = @[member, room];
	[self callScriptBlockNamed:@"memberJoined" withArguments:args forSelector:_cmd];
}

- (void) memberParted:(JVChatRoomMember *) member fromRoom:(JVChatRoomPanel *) room forReason:(NSAttributedString *) reason {
	NSArray *args = @[member, room, ( reason ? (id)reason : (id)[NSNull null] )];
	[self callScriptBlockNamed:@"memberParted" withArguments:args forSelector:_cmd];
}

- (void) memberKicked:(JVChatRoomMember *) member fromRoom:(JVChatRoomPanel *) room by:(JVChatRoomMember *) by forReason:(NSAttributedString *) reason {
	NSArray *args = @[member, room, ( by ? (id)by : (id)[NSNull null] ), ( reason ? (id)reason : (id)[NSNull null] )];
	[self callScriptBlockNamed:@"memberKicked" withArguments:args forSelector:_cmd];
}

- (void) joinedRoom:(JVChatRoomPanel *) room {
	NSArray *args = @[room];
	[self callScriptBlockNamed:@"joinedRoom" withArguments:args forSelector:_cmd];
}

- (void) partingFromRoom:(JVChatRoomPanel *) room {
	NSArray *args = @[room];
	[self callScriptBlockNamed:@"partingFromRoom" withArguments:args forSelector:_cmd];
}

- (void) kickedFromRoom:(JVChatRoomPanel *) room by:(JVChatRoomMember *) by forReason:(NSAttributedString *) reason {
	NSArray *args = @[room, ( by ? (id)by : (id)[NSNull null] ), ( reason ? (id)reason : (id)[NSNull null] )];
	[self callScriptBlockNamed:@"kickedFromRoom" withArguments:args forSelector:_cmd];
}

- (void) topicChangedTo:(NSAttributedString *) topic inRoom:(JVChatRoomPanel *) room by:(JVChatRoomMember *) member {
	NSArray *args = @[topic, room, ( member ? (id)member : (id)[NSNull null] )];
	[self callScriptBlockNamed:@"topicChanged" withArguments:args forSelector:_cmd];
}

- (BOOL) processSubcodeRequest:(NSString *) command withArguments:(NSString *) arguments fromUser:(MVChatUser *) user {
	NSArray *args = @[command, ( arguments ? (id)arguments : (id)[NSNull null] ), user];
	id result = [self callScriptBlockNamed:@"processSubcodeRequest" withArguments:args forSelector:_cmd];
	return ( [result isKindOfClass:[NSNumber class]] ? [result boolValue] : NO );
}

- (BOOL) processSubcodeReply:(NSString *) command withArguments:(NSString *) arguments fromUser:(MVChatUser *) user {
	NSArray *args = @[command, ( arguments ? (id)arguments : (id)[NSNull null] ), user];
	id result = [self callScriptBlockNamed:@"processSubcodeReply" withArguments:args forSelector:_cmd];
	return ( [result isKindOfClass:[NSNumber class]] ? [result boolValue] : NO );
}

- (void) connected:(MVChatConnection *) connection {
	NSArray *args = @[connection];
	[self callScriptBlockNamed:@"connected" withArguments:args forSelector:_cmd];
}

- (void) disconnecting:(MVChatConnection *) connection {
	NSArray *args = @[connection];
	[self callScriptBlockNamed:@"disconnecting" withArguments:args forSelector:_cmd];
}
@end
