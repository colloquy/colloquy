#import "JVFScriptChatPlugin.h"
#import "JVChatWindowController.h"
#import "JVChatMessage.h"
#import "JVChatRoomPanel.h"
#import "JVChatRoomMember.h"

NSString *JVFScriptErrorDomain = @"JVFScriptErrorDomain";

@interface BlockStackElem : NSObject <NSCoding> {}
- (Block *) block;
- (NSString *) errorStr;
- (int) firstCharIndex;
- (int) lastCharIndex;
@end

#pragma mark -

@implementation JVFScriptChatPlugin
- (id) initWithManager:(MVChatPluginManager *) manager {
	if( ( self = [self init] ) ) {
		_scriptInterpreter = nil;
		_path = nil;
	}

	return self;
}

- (id) initWithScriptAtPath:(NSString *) path withManager:(MVChatPluginManager *) manager {
	if( ( self = [self initWithManager:manager] ) ) {
		_path = [path copyWithZone:[self zone]];
		_scriptInterpreter = [[FSInterpreter interpreter] retain];
		if( ! _scriptInterpreter ) {
			[self release];
			return nil;
		}

		NSString *contents = [NSString stringWithContentsOfFile:path];
		FSInterpreterResult *result = [[self scriptInterpreter] execute:contents];
		if( ! [result isOk] ) {
			NSRunCriticalAlertPanel( NSLocalizedString( @"F-Script Plugin Error", "F-Script plugin error title" ), NSLocalizedString( @"The F-Script plugin \"%@\" had an error while loading. The error occured near character %d.\n\n%@", "F-Script plugin error message" ), nil, nil, nil, [path lastPathComponent], [result errorRange].location, [result errorMessage] );
			[self release];
			return nil;
		}

		[[self scriptInterpreter] setObject:self forIdentifier:@"scriptPlugin"];
	}

	return self;
}

- (void) dealloc {
	[_scriptInterpreter release];
	[_path release];

	_scriptInterpreter = nil;
	_path = nil;

	[super dealloc];
}

#pragma mark -

- (FSInterpreter *) scriptInterpreter {
	return _scriptInterpreter;
}

- (NSString *) scriptFilePath {
	return _path;
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

- (id) callScriptBlockNamed:(NSString *) blockName withArguments:(NSArray *) arguments forSelector:(SEL) selector {
	BOOL found = NO;
	id object = [[self scriptInterpreter] objectForIdentifier:blockName found:&found];

	if( found && [object isKindOfClass:[Block class]] ) {
		if( [(Block *)object argumentCount] > [arguments count] ) {
			if( NSRunCriticalAlertPanel( NSLocalizedString( @"F-Script Plugin Error", "F-Script plugin error title" ), NSLocalizedString( @"The F-Script plugin \"%@\" had an error while calling the \"%@\" block. This block expects %d arguments, only %d are provided.", "F-Script plugin error message" ), nil, NSLocalizedString( @"Inspect", "inspect button title" ), nil, [[self scriptFilePath] lastPathComponent], blockName, [(Block *)object argumentCount], [arguments count] ) == NSCancelButton )
				[(Block *)object inspect];
			NSDictionary *error = [NSDictionary dictionaryWithObject:[NSString stringWithFormat:@"Block with identifier \"%@\" expects %d arguments, we only have %d", blockName, [(Block *)object argumentCount], [arguments count]] forKey:NSLocalizedDescriptionKey];
			return [NSError errorWithDomain:JVFScriptErrorDomain code:-2 userInfo:error];
		} else {
			@try {
				return [(Block *)object valueWithArguments:arguments];
			} @catch ( NSException *exception ) {
				BlockStackElem *stack = [[[exception userInfo] objectForKey:@"blockStack"] lastObject];
				NSString *locationError = @"";
				if( stack ) locationError = [NSString stringWithFormat:@" The error occured near character %d inside the block.", [stack firstCharIndex]];
				if( NSRunCriticalAlertPanel( NSLocalizedString( @"F-Script Plugin Error", "F-Script plugin error title" ), NSLocalizedString( @"The F-Script plugin \"%@\" had an error while calling the \"%@\" block.%@\n\n%@", "F-Script plugin error message" ), nil, NSLocalizedString( @"Inspect", "inspect button title" ), nil, [[self scriptFilePath] lastPathComponent], blockName, locationError, [exception reason] ) == NSCancelButton ) {
					if( stack && [stack lastCharIndex] != -1 ) [(Block *)object showError:[stack errorStr] start:[stack firstCharIndex] end:[stack lastCharIndex]];
					else if( stack ) [(Block *)object showError:[stack errorStr]];
					else [(Block *)object inspect];
				}
			}
		}
	}

	NSDictionary *error = [NSDictionary dictionaryWithObject:[NSString stringWithFormat:@"Block with identifier \"%@\" not found", blockName] forKey:NSLocalizedDescriptionKey];
	return [NSError errorWithDomain:JVFScriptErrorDomain code:-1 userInfo:error];
}

#pragma mark -

- (NSArray *) contextualMenuItemsForObject:(id) object inView:(id <JVChatViewController>) view {
	NSArray *args = [NSArray arrayWithObjects:object, view, nil];
	id result = [self callScriptBlockNamed:@"contextualMenuItems" withArguments:args forSelector:_cmd];
	return ( [result isKindOfClass:[NSArray class]] ? result : nil );
}

- (void) performNotification:(NSString *) identifier withContextInfo:(NSDictionary *) context andPreferences:(NSDictionary *) preferences {
	NSArray *args = [NSArray arrayWithObjects:identifier, context, preferences, nil];
	[self callScriptBlockNamed:@"performNotification" withArguments:args forSelector:_cmd];
}

- (BOOL) processUserCommand:(NSString *) command withArguments:(NSAttributedString *) arguments toConnection:(MVChatConnection *) connection inView:(id <JVChatViewController>) view {
	NSArray *args = [NSArray arrayWithObjects:command, arguments, connection, view, nil];
	id result = [self callScriptBlockNamed:@"processUserCommand" withArguments:args forSelector:_cmd];
	return ( [result isKindOfClass:[NSNumber class]] ? [result boolValue] : NO );
}

- (BOOL) handleClickedLink:(NSURL *) url inView:(id <JVChatViewController>) view {
	NSArray *args = [NSArray arrayWithObjects:url, view, nil];
	id result = [self callScriptBlockNamed:@"handleClickedLink" withArguments:args forSelector:_cmd];
	return ( [result isKindOfClass:[NSNumber class]] ? [result boolValue] : NO );
}

- (void) processIncomingMessage:(JVMutableChatMessage *) message {
	NSArray *args = [NSArray arrayWithObject:message];
	[self callScriptBlockNamed:@"processIncomingMessage" withArguments:args forSelector:_cmd];
}

- (void) processOutgoingMessage:(JVMutableChatMessage *) message {
	NSArray *args = [NSArray arrayWithObject:message];
	[self callScriptBlockNamed:@"processOutgoingMessage" withArguments:args forSelector:_cmd];
}

- (void) memberJoined:(JVChatRoomMember *) member inRoom:(JVChatRoomPanel *) room {
	NSArray *args = [NSArray arrayWithObjects:member, room, nil];
	[self callScriptBlockNamed:@"memberJoined" withArguments:args forSelector:_cmd];
}

- (void) memberParted:(JVChatRoomMember *) member fromRoom:(JVChatRoomPanel *) room forReason:(NSAttributedString *) reason {
	NSArray *args = [NSArray arrayWithObjects:member, room, reason, nil];
	[self callScriptBlockNamed:@"memberParted" withArguments:args forSelector:_cmd];
}

- (void) memberKicked:(JVChatRoomMember *) member fromRoom:(JVChatRoomPanel *) room by:(JVChatRoomMember *) by forReason:(NSAttributedString *) reason {
	NSArray *args = [NSArray arrayWithObjects:member, room, by, reason, nil];
	[self callScriptBlockNamed:@"memberKicked" withArguments:args forSelector:_cmd];
}

- (void) joinedRoom:(JVChatRoomPanel *) room {
	NSArray *args = [NSArray arrayWithObject:room];
	[self callScriptBlockNamed:@"joinedRoom" withArguments:args forSelector:_cmd];
}

- (void) partingFromRoom:(JVChatRoomPanel *) room {
	NSArray *args = [NSArray arrayWithObject:room];
	[self callScriptBlockNamed:@"partingFromRoom" withArguments:args forSelector:_cmd];
}

- (void) kickedFromRoom:(JVChatRoomPanel *) room by:(JVChatRoomMember *) by forReason:(NSAttributedString *) reason {
	NSArray *args = [NSArray arrayWithObjects:room, by, reason, nil];
	[self callScriptBlockNamed:@"kickedFromRoom" withArguments:args forSelector:_cmd];
}

- (void) topicChangedTo:(NSAttributedString *) topic inRoom:(JVChatRoomPanel *) room by:(JVChatRoomMember *) member {
	NSArray *args = [NSArray arrayWithObjects:topic, room, member, nil];
	[self callScriptBlockNamed:@"topicChanged" withArguments:args forSelector:_cmd];
}

- (BOOL) processSubcodeRequest:(NSString *) command withArguments:(NSString *) arguments fromUser:(MVChatUser *) user {
	NSArray *args = [NSArray arrayWithObjects:command, arguments, user, nil];
	id result = [self callScriptBlockNamed:@"processSubcodeRequest" withArguments:args forSelector:_cmd];
	return ( [result isKindOfClass:[NSNumber class]] ? [result boolValue] : NO );
}

- (BOOL) processSubcodeReply:(NSString *) command withArguments:(NSString *) arguments fromUser:(MVChatUser *) user {
	NSArray *args = [NSArray arrayWithObjects:command, arguments, user, nil];
	id result = [self callScriptBlockNamed:@"processSubcodeReply" withArguments:args forSelector:_cmd];
	return ( [result isKindOfClass:[NSNumber class]] ? [result boolValue] : NO );
}

- (void) connected:(MVChatConnection *) connection {
	NSArray *args = [NSArray arrayWithObject:connection];
	[self callScriptBlockNamed:@"connected" withArguments:args forSelector:_cmd];
}

- (void) disconnecting:(MVChatConnection *) connection {
	NSArray *args = [NSArray arrayWithObject:connection];
	[self callScriptBlockNamed:@"disconnecting" withArguments:args forSelector:_cmd];
}
@end
