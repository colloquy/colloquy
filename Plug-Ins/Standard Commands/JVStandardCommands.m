#import <Cocoa/Cocoa.h>
#import "JVStandardCommands.h"
#import "MVChatPluginManager.h"
#import "MVChatPluginManagerAdditions.h"
#import "MVConnectionsController.h"
#import "MVChatConnection.h"
#import "JVChatController.h"
#import "JVChatRoom.h"
#import "JVDirectChat.h"
#import "JVChatRoomMember.h"
#import "JVInspectorController.h"
#import "JVChatMemberInspector.h"

@interface JVChatTranscript (JVChatTranscriptPrivate)
- (void) _reloadCurrentStyle:(id) sender;
@end

#pragma mark -

@implementation JVStandardCommands
- (id) initWithManager:(MVChatPluginManager *) manager {
	self = [super init];
	_manager = manager;
	return self;
}

- (void) dealloc {
	_manager = nil;
	[super dealloc];
}

- (BOOL) processUserCommand:(NSString *) command withArguments:(NSAttributedString *) arguments toConnection:(MVChatConnection *) connection {
	if( [command isEqualToString:@"msg"] || [command isEqualToString:@"query"] ) {
		return [self handleMessageCommand:command withMessage:arguments forConnection:connection];
	} else if( [command isEqualToString:@"amsg"] || [command isEqualToString:@"ame"] ) {
		return [self handleMassMessageCommand:command withMessage:arguments forConnection:connection];
	} else if( [command isEqualToString:@"away"] ) {
		[connection setAwayStatusWithMessage:arguments];
		return YES;
	} else if( [command isEqualToString:@"j"] ) {
		return [self handleJoinWithArguments:[arguments string] forConnection:connection];
	} else if( [command isEqualToString:@"leave"] ) {
		return [self handlePartWithArguments:[arguments string] forConnection:connection];
	} else if( [command isEqualToString:@"server"] ) {
		return [self handleServerConnectWithArguments:[arguments string]];
	} else if( [command isEqualToString:@"dcc"] ) {
		NSString *subcmd = nil;
		NSScanner *scanner = [NSScanner scannerWithString:[arguments string]];
		[scanner scanUpToCharactersFromSet:[NSCharacterSet whitespaceAndNewlineCharacterSet] intoString:&subcmd];
		if( [subcmd isEqualToString:@"send"] )
			return [self handleFileSendWithArguments:[arguments string] forConnection:connection];
		return NO;
	} else if( [command isEqualToString:@"raw"] || [command isEqualToString:@"quote"] ) {
		[connection sendRawMessage:[arguments string]];
		return YES;
	} else if( [command isEqualToString:@"umode"] ) {
		[connection sendRawMessage:[NSString stringWithFormat:@"MODE %@ %@", [connection nickname], [arguments string]]];
		return YES;
	} else if( [command isEqualToString:@"ctcp"] ) {
		return [self handleCTCPWithArguments:[arguments string] forConnection:connection];
	} else if( [command isEqualToString:@"wi"] ) {
		[connection fetchInformationForUser:[arguments string] withPriority:NO fromLocalServer:YES];
		return YES;
	} else if( [command isEqualToString:@"wii"] ) {
		[connection fetchInformationForUser:[arguments string] withPriority:NO fromLocalServer:NO];
		return YES;
	} else if( [command isEqualToString:@"globops"] ) {
		[connection sendRawMessage:[NSString stringWithFormat:@"GLOBOPS :%@", [arguments string]]];
		return YES;
	} else if( [command isEqualToString:@"quit"] || [command isEqualToString:@"exit"] ) {
		[[NSApplication sharedApplication] terminate:nil];
		return YES;
	} else if( [command isEqualToString:@"disconnect"] ) {
		[connection disconnect];
		return YES;
	} else if( [command isEqualToString:@"reload"] ) {
		if( [[arguments string] isEqualToString:@"plugins"] ) {
			[_manager findAndLoadPlugins];
			return YES;
		}
	}
	return NO;
}

- (BOOL) processUserCommand:(NSString *) command withArguments:(NSAttributedString *) arguments toRoom:(JVChatRoom *) room {
	if( [command isEqualToString:@"me"] || [command isEqualToString:@"action"] || [command isEqualToString:@"say"] ) {
		if( [arguments length] ) {
			[room echoSentMessageToDisplay:arguments asAction:( [command isEqualToString:@"me"] || [command isEqualToString:@"action"] )];
			[[room connection] sendMessage:arguments withEncoding:[room encoding] toChatRoom:[room target] asAction:( [command isEqualToString:@"me"] || [command isEqualToString:@"action"] )];
		}
		return YES;
	} else if ( [[command substringToIndex:1] isEqualToString:@"/"] ) {
		NSMutableAttributedString *line = [[[NSMutableAttributedString alloc] init] autorelease];
		if( [command length] > 1 ) {
			[line replaceCharactersInRange:NSMakeRange(0,0) withString:command];
		}
		if( [arguments length] ) {
			[line replaceCharactersInRange:NSMakeRange([line length], 0) withString:@" "];
			[line appendAttributedString:arguments];
		}
		if( [line length] ) {
			[room echoSentMessageToDisplay:line asAction:NO];
			[[room connection] sendMessage:line withEncoding:[room encoding] toUser:[room target] asAction:NO];
		}
		return YES;
	} else if( [command isEqualToString:@"msg"] || [command isEqualToString:@"query"] ) {
		return [self handleMessageCommand:command withMessage:arguments forConnection:[room connection]];
	} else if( [command isEqualToString:@"amsg"] || [command isEqualToString:@"ame"] ) {
		return [self handleMassMessageCommand:command withMessage:arguments forConnection:[room connection]];
	} else if( [command isEqualToString:@"away"] ) {
		[[room connection] setAwayStatusWithMessage:arguments];
		return YES;
	} else if( [command isEqualToString:@"j"] ) {
		return [self handleJoinWithArguments:[arguments string] forConnection:[room connection]];
	} else if( [command isEqualToString:@"leave"] ) {
		if( ! [arguments length] ) [self handlePartWithArguments:[room target] forConnection:[room connection]];
		else return [self handlePartWithArguments:[arguments string] forConnection:[room connection]];
		return YES;
	} else if( [command isEqualToString:@"server"] ) {
		return [self handleServerConnectWithArguments:[arguments string]];
	} else if( [command isEqualToString:@"dcc"] ) {
		NSString *subcmd = nil;
		NSScanner *scanner = [NSScanner scannerWithString:[arguments string]];
		[scanner scanUpToCharactersFromSet:[NSCharacterSet whitespaceAndNewlineCharacterSet] intoString:&subcmd];
		if( [subcmd isEqualToString:@"send"] )
			return [self handleFileSendWithArguments:[arguments string] forConnection:[room connection]];
		return NO;
	} else if( [command isEqualToString:@"raw"] || [command isEqualToString:@"quote"] ) {
		[[room connection] sendRawMessage:[arguments string]];
		return YES;
	} else if( [command isEqualToString:@"ctcp"] ) {
		return [self handleCTCPWithArguments:[arguments string] forConnection:[room connection]];
	} else if( [command isEqualToString:@"topic"] || [command isEqualToString:@"t"] ) {
		if( ! [arguments length] ) return NO;
		NSStringEncoding encoding = [room encoding];
		if( ! encoding ) encoding = (NSStringEncoding) [[NSUserDefaults standardUserDefaults] integerForKey:@"JVChatEncoding"];
		[[room connection] setTopic:arguments withEncoding:encoding forRoom:[room target]];
		return YES;
	} else if( [command isEqualToString:@"umode"] ) {
		[[room connection] sendRawMessage:[NSString stringWithFormat:@"MODE %@ %@", [[room connection] nickname], [arguments string]]];
		return YES;
	} else if( [command isEqualToString:@"names"] && ! [[arguments string] length] ) {
		[[room windowController] openViewsDrawer:nil];
		[[room windowController] expandListItem:room];
		return YES;
	} else if( [command isEqualToString:@"clear"] ) {
		[room clearDisplay:nil];
		return YES;
	} else if( [command isEqualToString:@"kick"] ) {
		NSString *member = nil, *msg = nil;
		NSScanner *scanner = [NSScanner scannerWithString:[arguments string]];

		[scanner scanUpToCharactersFromSet:[NSCharacterSet whitespaceAndNewlineCharacterSet] intoString:&member];
		if( ! member ) return NO;

		if( [arguments length] >= [scanner scanLocation] + 1 ) {
			[scanner setScanLocation:[scanner scanLocation] + 1];
			msg = [[arguments string] substringFromIndex:[scanner scanLocation]];
		}

		[[room connection] kickMember:member inRoom:[room target] forReason:msg];
		return YES;
	} else if( [command isEqualToString:@"op"] ) {
		NSArray *args = [[arguments string] componentsSeparatedByString:@" "];
		NSEnumerator *e = [args objectEnumerator];
		NSString *arg;
		while( arg = [e nextObject] ) {
			if( [arg length] )
				[[room connection] promoteMember:arg inRoom:[room target]];
		}
		return YES;
	} else if( [command isEqualToString:@"deop"] ) {
		NSArray *args = [[arguments string] componentsSeparatedByString:@" "];
		NSEnumerator *e = [args objectEnumerator];
		NSString *arg;
		while( arg = [e nextObject] ) {
			if( [arg length] )
				[[room connection] demoteMember:arg inRoom:[room target]];
		}
		return YES;
	} else if( [command isEqualToString:@"halfop"] ) {
		NSArray *args = [[arguments string] componentsSeparatedByString:@" "];
		NSEnumerator *e = [args objectEnumerator];
		NSString *arg;
		while( arg = [e nextObject] ) {
			if( [arg length] )
				[[room connection] halfopMember:arg inRoom:[room target]];
		}
		return YES;
	} else if( [command isEqualToString:@"dehalfop"] ) {
		NSArray *args = [[arguments string] componentsSeparatedByString:@" "];
		NSEnumerator *e = [args objectEnumerator];
		NSString *arg;
		while( arg = [e nextObject] ) {
			if( [arg length] )
				[[room connection] dehalfopMember:arg inRoom:[room target]];
		}
		return YES;
	} else if( [command isEqualToString:@"voice"] ) {
		NSArray *args = [[arguments string] componentsSeparatedByString:@" "];
		NSEnumerator *e = [args objectEnumerator];
		NSString *arg;
		while( arg = [e nextObject] ) {
			if( [arg length] )
				[[room connection] voiceMember:arg inRoom:[room target]];
		}
		return YES;
	} else if( [command isEqualToString:@"devoice"] ) {
		NSArray *args = [[arguments string] componentsSeparatedByString:@" "];
		NSEnumerator *e = [args objectEnumerator];
		NSString *arg;
		while( arg = [e nextObject] ) {
			if( [arg length] )
				[[room connection] devoiceMember:arg inRoom:[room target]];
		}
		return YES;
	} else if( [command isEqualToString:@"quit"] || [command isEqualToString:@"exit"] ) {
		[[NSApplication sharedApplication] terminate:nil];
		return YES;
	} else if( [command isEqualToString:@"whois"] || [command isEqualToString:@"wi"] ) {
		id member = [[[NSClassFromString( @"JVChatRoomMember" ) alloc] initWithRoom:room andNickname:[arguments string]] autorelease];
		id info = [NSClassFromString( @"JVInspectorController" ) inspectorOfObject:member];
		[(id)[info inspector] setFetchLocalServerInfoOnly:YES];
		[info show:nil];
		return YES;
	} else if( [command isEqualToString:@"wii"] ) {
		id member = [[[NSClassFromString( @"JVChatRoomMember" ) alloc] initWithRoom:room andNickname:[arguments string]] autorelease];
		[[NSClassFromString( @"JVInspectorController" ) inspectorOfObject:member] show:nil];
		return YES;
	} else if( [command isEqualToString:@"globops"] ) {
		[[room connection] sendRawMessage:[NSString stringWithFormat:@"GLOBOPS :%@", [arguments string]]];
		return YES;
	} else if( [command isEqualToString:@"disconnect"] ) {
		[[room connection] disconnect];
		return YES;
	} else if( [command isEqualToString:@"reload"] ) {
		if( [[arguments string] isEqualToString:@"plugins"] ) {
			[_manager findAndLoadPlugins];
			return YES;
		} else if( [[arguments string] isEqualToString:@"style"] ) {
			[room _reloadCurrentStyle:nil];
			return YES;
		}
	}
	return NO;
}

- (BOOL) processUserCommand:(NSString *) command withArguments:(NSAttributedString *) arguments toChat:(JVDirectChat *) chat {
	if( [command isEqualToString:@"me"] || [command isEqualToString:@"action"] || [command isEqualToString:@"say"] ) {
		if( [arguments length] ) {
			[chat echoSentMessageToDisplay:arguments asAction:( [command isEqualToString:@"me"] || [command isEqualToString:@"action"] )];
			[[chat connection] sendMessage:arguments withEncoding:[chat encoding] toUser:[chat target] asAction:( [command isEqualToString:@"me"] || [command isEqualToString:@"action"] )];
		}
		return YES;
	} else if ( [[command substringToIndex:1] isEqualToString:@"/"] ) {
		NSMutableAttributedString *line = [[[NSMutableAttributedString alloc] init] autorelease];
		if( [command length] > 1 ) {
			[line replaceCharactersInRange:NSMakeRange(0,0) withString:command];
		}
		if( [arguments length] ) {
			[line replaceCharactersInRange:NSMakeRange([line length], 0) withString:@" "];
			[line appendAttributedString:arguments];
		}
		if( [line length] ) {
			[chat echoSentMessageToDisplay:line asAction:NO];
			[[chat connection] sendMessage:line withEncoding:[chat encoding] toUser:[chat target] asAction:NO];
		}
		return YES;
	} else if( [command isEqualToString:@"msg"] || [command isEqualToString:@"query"] ) {
		return [self handleMessageCommand:command withMessage:arguments forConnection:[chat connection]];
	} else if( [command isEqualToString:@"amsg"] || [command isEqualToString:@"ame"] ) {
		return [self handleMassMessageCommand:command withMessage:arguments forConnection:[chat connection]];
	} else if( [command isEqualToString:@"away"] ) {
		[[chat connection] setAwayStatusWithMessage:arguments];
		return YES;
	} else if( [command isEqualToString:@"j"] ) {
		return [self handleJoinWithArguments:[arguments string] forConnection:[chat connection]];
	} else if( [command isEqualToString:@"leave"] ) {
		return [self handlePartWithArguments:[arguments string] forConnection:[chat connection]];
	} else if( [command isEqualToString:@"server"] ) {
		return [self handleServerConnectWithArguments:[arguments string]];
	} else if( [command isEqualToString:@"raw"] || [command isEqualToString:@"quote"] ) {
		[[chat connection] sendRawMessage:[arguments string]];
		return YES;
	} else if( [command isEqualToString:@"umode"] ) {
		[[chat connection] sendRawMessage:[NSString stringWithFormat:@"MODE %@ %@", [[chat connection] nickname], [arguments string]]];
		return YES;
	} else if( [command isEqualToString:@"ctcp"] ) {
		return [self handleCTCPWithArguments:[arguments string] forConnection:[chat connection]];
	} else if( [command isEqualToString:@"dcc"] ) {
		NSString *subcmd = nil;
		NSScanner *scanner = [NSScanner scannerWithString:[arguments string]];
		[scanner scanUpToCharactersFromSet:[NSCharacterSet whitespaceAndNewlineCharacterSet] intoString:&subcmd];
		if( [subcmd isEqualToString:@"send"] )
			return [self handleFileSendWithArguments:[arguments string] forConnection:[chat connection]];
		return NO;
	} else if( [command isEqualToString:@"clear"] ) {
		[chat clearDisplay:nil];
	} else if( [command isEqualToString:@"quit"] || [command isEqualToString:@"exit"] ) {
		[[NSApplication sharedApplication] terminate:nil];
		return YES;
	} else if( [command isEqualToString:@"disconnect"] ) {
		[[chat connection] disconnect];
		return YES;
	} else if( [command isEqualToString:@"whois"] || [command isEqualToString:@"wi"] ) {
		id member = [[[NSClassFromString( @"JVChatRoomMember" ) alloc] initWithRoom:(JVChatRoom *)chat andNickname:[arguments string]] autorelease];
		id info = [NSClassFromString( @"JVInspectorController" ) inspectorOfObject:member];
		[(id)[info inspector] setFetchLocalServerInfoOnly:YES];
		[info show:nil];
		return YES;
	} else if( [command isEqualToString:@"wii"] ) {
		id member = [[[NSClassFromString( @"JVChatRoomMember" ) alloc] initWithRoom:(JVChatRoom *)chat andNickname:[arguments string]] autorelease];
		[[NSClassFromString( @"JVInspectorController" ) inspectorOfObject:member] show:nil];
		return YES;
	} else if( [command isEqualToString:@"globops"] ) {
		[[chat connection] sendRawMessage:[NSString stringWithFormat:@"GLOBOPS :%@", [arguments string]]];
		return YES;
	} else if( [command isEqualToString:@"reload"] ) {
		if( [[arguments string] isEqualToString:@"plugins"] ) {
			[_manager findAndLoadPlugins];
			return YES;
		} else if( [[arguments string] isEqualToString:@"style"] ) {
			[chat _reloadCurrentStyle:nil];
			return YES;
		}
	}
	return NO;
}

#pragma mark -

- (BOOL) handleFileSendWithArguments:(NSString *) arguments forConnection:(MVChatConnection *) connection {
	NSString *to = nil, *path = nil;
	NSScanner *scanner = [NSScanner scannerWithString:arguments];
	[scanner scanUpToCharactersFromSet:[NSCharacterSet whitespaceAndNewlineCharacterSet] intoString:nil];
	[scanner scanUpToCharactersFromSet:[NSCharacterSet whitespaceCharacterSet] intoString:&to];
	if( [arguments length] >= [scanner scanLocation] + 1 ) {
		[scanner setScanLocation:[scanner scanLocation] + 1];
		path = [arguments substringFromIndex:[scanner scanLocation]];
		if( ! [[NSFileManager defaultManager] fileExistsAtPath:path] ) return NO;
	}

	if( ! to ) return NO;

	if( ! [path length] ) {
		NSOpenPanel *panel = [NSOpenPanel openPanel];
		[panel setResolvesAliases:YES];
		[panel setCanChooseFiles:YES];
		[panel setCanChooseDirectories:NO];
		[panel setAllowsMultipleSelection:YES];
		if( [panel runModalForTypes:nil] == NSOKButton ) {
			NSEnumerator *enumerator = [[panel filenames] objectEnumerator];
			while( ( path = [enumerator nextObject] ) )
				[connection sendFile:path toUser:to];
		}
	} else [connection sendFile:path toUser:to];
	return YES;
}

- (BOOL) handleCTCPWithArguments:(NSString *) arguments forConnection:(MVChatConnection *) connection {
	NSString *to = nil, *ctcpRequest = nil, *ctcpArgs = nil;
	NSScanner *scanner = [NSScanner scannerWithString:arguments];
	
	[scanner scanUpToCharactersFromSet:[NSCharacterSet whitespaceCharacterSet] intoString:&to];
	[scanner scanUpToCharactersFromSet:[NSCharacterSet whitespaceAndNewlineCharacterSet] intoString:&ctcpRequest];
	[scanner scanUpToCharactersFromSet:[NSCharacterSet characterSetWithCharactersInString:@"\n\r"] intoString:&ctcpArgs];
	
	if( ! to || ! ctcpRequest ) return NO;
	
	[connection sendSubcodeRequest:ctcpRequest toUser:to withArguments:ctcpArgs];
	return YES;
}

- (BOOL) handleServerConnectWithArguments:(NSString *) arguments {
	NSURL *url = nil;
	if( arguments && ( url = [NSURL URLWithString:arguments] ) ) {
		[[_manager connectionsController] handleURL:url andConnectIfPossible:YES];
	} else if( arguments ) {
		NSString *address = nil;
		int port = 0;
		NSScanner *scanner = [NSScanner scannerWithString:arguments];
		[scanner scanUpToCharactersFromSet:[NSCharacterSet whitespaceAndNewlineCharacterSet] intoString:&address];
		if( [arguments length] >= [scanner scanLocation] + 1 ) {
			[scanner setScanLocation:[scanner scanLocation] + 1];
			[scanner scanInt:&port];
		}

		if( address && port ) url = [NSURL URLWithString:[NSString stringWithFormat:@"irc://%@:%du", MVURLEncodeString( address ), port]];
		else if( address && ! port ) url = [NSURL URLWithString:[NSString stringWithFormat:@"irc://%@", MVURLEncodeString( address )]];
		else [[_manager connectionsController] newConnection:nil];

		if( url ) [[_manager connectionsController] handleURL:url andConnectIfPossible:YES];
	} else [[_manager connectionsController] newConnection:nil];
	return YES;
}

- (BOOL) handleJoinWithArguments:(NSString *) arguments forConnection:(MVChatConnection *) connection {
	[connection sendRawMessage:[NSString stringWithFormat:@"JOIN %@", arguments]];
	return YES;
}

- (BOOL) handlePartWithArguments:(NSString *) arguments forConnection:(MVChatConnection *) connection {
	[connection sendRawMessage:[NSString stringWithFormat:@"PART %@", arguments]];
	return YES;
}

- (BOOL) handleMessageCommand:(NSString *) command withMessage:(NSAttributedString *) message forConnection:(MVChatConnection *) connection {
	NSString *to = nil;
	NSAttributedString *msg = nil;
	NSScanner *scanner = [NSScanner scannerWithString:[message string]];

	[scanner scanUpToCharactersFromSet:[NSCharacterSet whitespaceAndNewlineCharacterSet] intoString:&to];

	if( ! to ) return NO;

	NSStringEncoding encoding = [(JVDirectChat *)[[_manager chatController] chatViewControllerForUser:to withConnection:connection ifExists:YES] encoding];
	if( ! encoding ) encoding = (NSStringEncoding) [[NSUserDefaults standardUserDefaults] integerForKey:@"JVChatEncoding"];

	if( [message length] >= [scanner scanLocation] + 1 ) {
		[scanner setScanLocation:[scanner scanLocation] + 1];
		msg = [message attributedSubstringFromRange:NSMakeRange( [scanner scanLocation], [message length] - [scanner scanLocation] )];
	}

	JVDirectChat *chatView = [[_manager chatController] chatViewControllerForUser:to withConnection:connection ifExists:NO];
	if( [msg length] ) [chatView echoSentMessageToDisplay:msg asAction:NO];

	if( [msg length] ) [connection sendMessage:msg withEncoding:encoding toUser:to asAction:NO];
	return YES;
}

- (BOOL) handleMassMessageCommand:(NSString *) command withMessage:(NSAttributedString *) message forConnection:(MVChatConnection *) connection {
	NSStringEncoding encoding = (NSStringEncoding) [[NSUserDefaults standardUserDefaults] integerForKey:@"JVChatEncoding"];
	if( ! [message length] ) return NO;
	NSEnumerator *enumerator = [[[_manager chatController] chatViewControllersOfClass:NSClassFromString( @"JVChatRoom" )] objectEnumerator];
	id item = nil;
	while( ( item = [enumerator nextObject] ) ) {
		[connection sendMessage:message withEncoding:encoding toChatRoom:[item target] asAction:[command isEqualToString:@"ame"]];
		[item echoSentMessageToDisplay:message asAction:[command isEqualToString:@"ame"]];
	}
	return YES;
}
@end
