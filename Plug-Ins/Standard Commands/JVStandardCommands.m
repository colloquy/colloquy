#import <Cocoa/Cocoa.h>
#import "JVStandardCommands.h"
#import "MVChatPluginManager.h"
#import "MVChatPluginManagerAdditions.h"
#import "MVConnectionsController.h"
#import "MVChatConnection.h"
#import "NSStringAdditions.h"
#import "JVChatController.h"
#import "JVChatRoom.h"
#import "JVDirectChat.h"
#import "JVChatRoomMember.h"
#import "JVInspectorController.h"
#import "MVFileTransferController.h"
#import "JVChatMemberInspector.h"
#import "JVChatRoomBrowser.h"
#import "JVStyle.h"

@interface JVChatTranscript (JVChatTranscriptPrivate)
- (void) _reloadCurrentStyle:(id) sender;
@end

#pragma mark -

@implementation JVStandardCommands
- (id) initWithManager:(MVChatPluginManager *) manager {
	if( ( self = [super init] ) ) {
		_manager = manager;
	}

	return self;
}

- (void) dealloc {
	_manager = nil;
	[super dealloc];
}

- (BOOL) processUserCommand:(NSString *) command withArguments:(NSAttributedString *) arguments toConnection:(MVChatConnection *) connection {
	if( [command isEqualToString:@"msg"] || [command isEqualToString:@"query"] ) {
		return [self handleMessageCommand:command withMessage:arguments forConnection:connection alwaysShow:NO];
	} else if( [command isEqualToString:@"amsg"] || [command isEqualToString:@"ame"] ) {
		return [self handleMassMessageCommand:command withMessage:arguments forConnection:connection];
	} else if( [command isEqualToString:@"away"] ) {
		[connection setAwayStatusWithMessage:arguments];
		return YES;
	} else if( [command isEqualToString:@"aaway"] ) {
		return [self handleMassAwayWithMessage:arguments];
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
		[connection sendRawMessage:[arguments string] immediately:YES];
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
	} else if( [command isEqualToString:@"quit"] || [command isEqualToString:@"disconnect"] ) {
		[connection disconnectWithReason:arguments];
		return YES;
	} else if( [command isEqualToString:@"reconnect"] || [command isEqualToString:@"server"] ) {
		[connection connect];
		return YES;
	} else if( [command isEqualToString:@"exit"] ) {
		[[NSApplication sharedApplication] terminate:nil];
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
	} else if( [[command substringToIndex:1] isEqualToString:@"/"] ) {
		NSMutableAttributedString *line = [[[NSMutableAttributedString alloc] init] autorelease];
		if( [command length] > 1 ) [line replaceCharactersInRange:NSMakeRange( 0, 0 ) withString:command];
		if( [arguments length] ) {
			[line replaceCharactersInRange:NSMakeRange( [line length], 0 ) withString:@" "];
			[line appendAttributedString:arguments];
		}
		if( [line length] ) {
			[room echoSentMessageToDisplay:line asAction:NO];
			[[room connection] sendMessage:line withEncoding:[room encoding] toUser:[room target] asAction:NO];
		}
		return YES;
	} else if( [command isEqualToString:@"msg"] || [command isEqualToString:@"query"] ) {
		return [self handleMessageCommand:command withMessage:arguments forConnection:[room connection] alwaysShow:YES];
	} else if( [command isEqualToString:@"amsg"] || [command isEqualToString:@"ame"] ) {
		return [self handleMassMessageCommand:command withMessage:arguments forConnection:[room connection]];
	} else if( [command isEqualToString:@"away"] ) {
		[[room connection] setAwayStatusWithMessage:arguments];
		return YES;
	} else if( [command isEqualToString:@"aaway"] ) {
		return [self handleMassAwayWithMessage:arguments];
	} else if( [command isEqualToString:@"j"] ) {
		return [self handleJoinWithArguments:[arguments string] forConnection:[room connection]];
	} else if( [command isEqualToString:@"leave"] ) {
		if( ! [arguments length] ) [self handlePartWithArguments:[room target] forConnection:[room connection]];
		else return [self handlePartWithArguments:[arguments string] forConnection:[room connection]];
		return YES;
	} else if( [command isEqualToString:@"server"] ) {
		return [self handleServerConnectWithArguments:[arguments string]];
	} else if( [command isEqualToString:@"list"] ) {
		id browser = [NSClassFromString( @"JVChatRoomBrowser" ) chatRoomBrowserForConnection:[room connection]];
		[browser showWindow:nil];
		[browser setFilter:[arguments string]];
		[browser showRoomBrowser:nil];
		return YES;
	} else if( [command isEqualToString:@"dcc"] ) {
		NSString *subcmd = nil;
		NSScanner *scanner = [NSScanner scannerWithString:[arguments string]];
		[scanner scanUpToCharactersFromSet:[NSCharacterSet whitespaceAndNewlineCharacterSet] intoString:&subcmd];
		if( [subcmd isEqualToString:@"send"] )
			return [self handleFileSendWithArguments:[arguments string] forConnection:[room connection]];
		return NO;
	} else if( [command isEqualToString:@"raw"] || [command isEqualToString:@"quote"] ) {
		[[room connection] sendRawMessage:[arguments string] immediately:YES];
		return YES;
	} else if( [command isEqualToString:@"ctcp"] ) {
		return [self handleCTCPWithArguments:[arguments string] forConnection:[room connection]];
	} else if( [command isEqualToString:@"topic"] || [command isEqualToString:@"t"] ) {
		if( ! [arguments length] ) return NO;
		NSStringEncoding encoding = [room encoding];
		if( ! encoding ) encoding = [[room connection] encoding];
		[[room connection] setTopic:arguments withEncoding:encoding forRoom:[room target]];
		return YES;
	} else if( [command isEqualToString:@"umode"] ) {
		[[room connection] sendRawMessage:[NSString stringWithFormat:@"MODE %@ %@", [[room connection] nickname], [arguments string]]];
		return YES;
	} else if( [command isEqualToString:@"names"] && ! [[arguments string] length] ) {
		[[room windowController] openViewsDrawer:nil];
		if( [[room windowController] isListItemExpanded:room] ) [[room windowController] collapseListItem:room];
		else [[room windowController] expandListItem:room];
		return YES;
	} else if( ( [command isEqualToString:@"cycle"] || [command isEqualToString:@"hop"] ) && ! [[arguments string] length] ) {
		[room setKeepAfterPart:YES];
		[room partChat:nil];
		[room joinChat:nil];
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
	} else if( [command isEqualToString:@"ban"] ) {
		NSArray *args = [[arguments string] componentsSeparatedByString:@" "];
		NSEnumerator *e = [args objectEnumerator];
		NSString *arg;
		while( arg = [e nextObject] ) {
			if( [arg length] )
				[[room connection] banMember:arg inRoom:[room target]];
		}
		return YES;
	} else if( [command isEqualToString:@"unban"] ) {
		NSArray *args = [[arguments string] componentsSeparatedByString:@" "];
		NSEnumerator *e = [args objectEnumerator];
		NSString *arg;
		while( arg = [e nextObject] ) {
			if( [arg length] )
				[[room connection] unbanMember:arg inRoom:[room target]];
		}
		return YES;
	} else if( [command isEqualToString:@"quit"] || [command isEqualToString:@"disconnect"] ) {
		[[room connection] disconnectWithReason:arguments];
		return YES;
	} else if( [command isEqualToString:@"reconnect"] || [command isEqualToString:@"server"] ) {
		[[room connection] connect];
		return YES;
	} else if( [command isEqualToString:@"exit"] ) {
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
	} else if( [command isEqualToString:@"console"] ) {
		id controller = [[_manager chatController] chatConsoleForConnection:[room connection] ifExists:NO];
		[[controller windowController] showChatViewController:controller];
		return YES;
	} else if( [command isEqualToString:@"reload"] ) {
		if( [[arguments string] isEqualToString:@"plugins"] ) {
			[_manager findAndLoadPlugins];
			return YES;
		} else if( [[arguments string] isEqualToString:@"style"] ) {
			[room _reloadCurrentStyle:nil];
			return YES;
		} else if( [[arguments string] isEqualToString:@"styles"] ) {
			[NSClassFromString( @"JVStyle" ) scanForStyles];
			return YES;
		} else if( [[arguments string] isEqualToString:@"emoticons"] ) {
			[[NSNotificationCenter defaultCenter] postNotificationName:@"JVChatEmoticonSetInstalledNotification" object:nil]; 
			return YES;
		}
	} else if( [command isEqualToString:@"ignore"] ) {
		return [self handleIgnoreWithArguments:[arguments string] inView:room];
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
		return [self handleMessageCommand:command withMessage:arguments forConnection:[chat connection] alwaysShow:YES];
	} else if( [command isEqualToString:@"amsg"] || [command isEqualToString:@"ame"] ) {
		return [self handleMassMessageCommand:command withMessage:arguments forConnection:[chat connection]];
	} else if( [command isEqualToString:@"away"] ) {
		[[chat connection] setAwayStatusWithMessage:arguments];
		return YES;
	} else if( [command isEqualToString:@"aaway"] ) {
		return [self handleMassAwayWithMessage:arguments];
	} else if( [command isEqualToString:@"j"] ) {
		return [self handleJoinWithArguments:[arguments string] forConnection:[chat connection]];
	} else if( [command isEqualToString:@"leave"] ) {
		return [self handlePartWithArguments:[arguments string] forConnection:[chat connection]];
	} else if( [command isEqualToString:@"server"] ) {
		return [self handleServerConnectWithArguments:[arguments string]];
	} else if( [command isEqualToString:@"list"] ) {
		id browser = [NSClassFromString( @"JVChatRoomBrowser" ) chatRoomBrowserForConnection:[chat connection]];
		[browser showWindow:nil];
		[browser setFilter:[arguments string]];
		[browser showRoomBrowser:nil];
		return YES;
	} else if( [command isEqualToString:@"raw"] || [command isEqualToString:@"quote"] ) {
		[[chat connection] sendRawMessage:[arguments string] immediately:YES];
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
	} else if( [command isEqualToString:@"quit"] || [command isEqualToString:@"disconnect"] ) {
		[[chat connection] disconnectWithReason:arguments];
		return YES;
	} else if( [command isEqualToString:@"reconnect"] || [command isEqualToString:@"server"] ) {
		[[chat connection] connect];
		return YES;
	} else if( [command isEqualToString:@"exit"] ) {
		[[NSApplication sharedApplication] terminate:nil];
		return YES;
	} else if( [command isEqualToString:@"console"] ) {
		id controller = [[_manager chatController] chatConsoleForConnection:[chat connection] ifExists:NO];
		[[controller windowController] showChatViewController:controller];
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
		} else if( [[arguments string] isEqualToString:@"styles"] ) {
			[[NSNotificationCenter defaultCenter] postNotificationName:@"JVChatStyleInstalledNotification" object:nil]; 
			return YES;
		} else if( [[arguments string] isEqualToString:@"emoticons"] ) {
			[[NSNotificationCenter defaultCenter] postNotificationName:@"JVChatEmoticonSetInstalledNotification" object:nil]; 
			return YES;
		}
	} else if( [command isEqualToString:@"ignore"] ) {
		return [self handleIgnoreWithArguments:[arguments string] inView:chat];
	}

	return NO;
}

#pragma mark -

- (BOOL) handleFileSendWithArguments:(NSString *) arguments forConnection:(MVChatConnection *) connection {
	NSString *to = nil, *path = nil;
	BOOL passive = [[NSUserDefaults standardUserDefaults] boolForKey:@"JVSendFilesPassively"];
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
				[[_manager fileTransferController] addFileTransfer:[connection sendFile:path toUser:to passively:passive]];
		}
	} else [[_manager fileTransferController] addFileTransfer:[connection sendFile:path toUser:to passively:passive]];
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

		if( address && port ) url = [NSURL URLWithString:[NSString stringWithFormat:@"irc://%@:%du", [address stringByEncodingIllegalURLCharacters], port]];
		else if( address && ! port ) url = [NSURL URLWithString:[NSString stringWithFormat:@"irc://%@", [address stringByEncodingIllegalURLCharacters]]];
		else [[_manager connectionsController] newConnection:nil];

		if( url ) [[_manager connectionsController] handleURL:url andConnectIfPossible:YES];
	} else [[_manager connectionsController] newConnection:nil];
	return YES;
}

- (BOOL) handleJoinWithArguments:(NSString *) arguments forConnection:(MVChatConnection *) connection {
	NSArray *channels = [arguments componentsSeparatedByString:@","];
	NSCharacterSet *chanSet = [NSCharacterSet characterSetWithCharactersInString:@"&#+!"];
	NSEnumerator *chanEnum = [channels objectEnumerator];
	NSString *channel = nil;
	while( ( channel = [chanEnum nextObject] ) ) {
		channel = [channel stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
		[connection sendRawMessage:[NSString stringWithFormat:@"JOIN %@", ( [chanSet characterIsMember:[channel characterAtIndex:0]] ? channel : [@"#" stringByAppendingString:channel] )]];
	}
	return YES;
}

- (BOOL) handlePartWithArguments:(NSString *) arguments forConnection:(MVChatConnection *) connection {
	NSArray *channels = [arguments componentsSeparatedByString:@","];
	NSCharacterSet *chanSet = [NSCharacterSet characterSetWithCharactersInString:@"&#+!"];
	NSEnumerator *chanEnum = [channels objectEnumerator];
	NSString *channel = nil;
	while( ( channel = [chanEnum nextObject] ) ) {
		channel = [channel stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
		[connection sendRawMessage:[NSString stringWithFormat:@"PART %@", ( [chanSet characterIsMember:[channel characterAtIndex:0]] ? channel : [@"#" stringByAppendingString:channel] )]];
	}
	return YES;
}

- (BOOL) handleMessageCommand:(NSString *) command withMessage:(NSAttributedString *) message forConnection:(MVChatConnection *) connection alwaysShow:(BOOL) always {
	NSString *to = nil;
	NSAttributedString *msg = nil;
	NSScanner *scanner = [NSScanner scannerWithString:[message string]];

	[scanner scanUpToCharactersFromSet:[NSCharacterSet whitespaceAndNewlineCharacterSet] intoString:&to];

	if( ! to ) return NO;

	NSStringEncoding encoding = [(JVDirectChat *)[[_manager chatController] chatViewControllerForUser:to withConnection:connection ifExists:YES] encoding];
	if( ! encoding ) encoding = [connection encoding];

	if( [message length] >= [scanner scanLocation] + 1 ) {
		[scanner setScanLocation:[scanner scanLocation] + 1];
		msg = [message attributedSubstringFromRange:NSMakeRange( [scanner scanLocation], [message length] - [scanner scanLocation] )];
	}

	BOOL show = NO;
	show = ( [command isEqualToString:@"query"] ? YES : show );
	show = ( ! [msg length] ? YES : show );
	show = ( always ? YES : show );

	JVDirectChat *chatView = [[_manager chatController] chatViewControllerForUser:to withConnection:connection ifExists:( ! show )];
	if( [msg length] ) {
		[chatView echoSentMessageToDisplay:msg asAction:NO];
		[connection sendMessage:msg withEncoding:encoding toUser:to asAction:NO];
	}

	return YES;
}

- (BOOL) handleMassMessageCommand:(NSString *) command withMessage:(NSAttributedString *) message forConnection:(MVChatConnection *) connection {
	if( ! [message length] ) return NO;

	NSStringEncoding encoding = [connection encoding];
	NSEnumerator *enumerator = [[[_manager chatController] chatViewControllersOfClass:NSClassFromString( @"JVChatRoom" )] objectEnumerator];
	id item = nil;
	while( ( item = [enumerator nextObject] ) ) {
		encoding = [item encoding];
		if( ! encoding ) encoding = [connection encoding];
		[connection sendMessage:message withEncoding:encoding toChatRoom:[item target] asAction:[command isEqualToString:@"ame"]];
		[item echoSentMessageToDisplay:message asAction:[command isEqualToString:@"ame"]];
	}

	return YES;
}

- (BOOL) handleMassAwayWithMessage:(NSAttributedString *) message {
	NSEnumerator *enumerator = [[[_manager connectionsController] connectedConnections] objectEnumerator];
	id item = nil;
	while( ( item = [enumerator nextObject] ) )
		[item setAwayStatusWithMessage:message];
	return YES;
}

- (BOOL) handleIgnoreWithArguments:(NSString *) args inView:(id <JVChatViewController>) view {
	// USAGE: /ignore -[p|m|n] [nickname|/regex/] ["message"|/regex/|word] [#rooms ...|*]
	// p makes the ignore permanent (i.e. the ignore is saved to disk)
	// m is to specify a message
	// n is to specify a nickname

	// EXAMPLES: 
	// /ignore Loser23094 - ignore Loser23094 in the current room
	// /ignore -m "is listening" - ignore any message that has "is listening" from everyone
	// /ignore -m /is listening .*/ - ignore the message expression "is listening *" from everyone
	// /ignore -mn /eevyl.*/ /is listening .*/ #adium #colloquy #here
	// /ignore -n /bunny.*/ * - ignore user in all rooms

	NSArray *argsArray = [args componentsSeparatedByString:@" "];
	NSString *memberString = nil;
	NSString *messageString = nil;
	NSArray *rooms = nil;
	BOOL regex = NO;
	BOOL permanent = NO;
	BOOL member = YES;
	BOOL message = NO;
	int offset = 0;

	if( [args hasPrefix:@"-"] ) { // parse commands/flags
		if( [[argsArray objectAtIndex:0] rangeOfString:@"p"].location != NSNotFound ) permanent = YES;
		if( [[argsArray objectAtIndex:0] rangeOfString:@"m"].location != NSNotFound ) {
			member = NO;
			message = YES;
		}
	
		if( [[argsArray objectAtIndex:0] rangeOfString:@"n"].location != NSNotFound ) member = YES;
	
		offset++; // lookup next arg.
	}

	// check for wrong number of arguments
	if( [argsArray count] < ( 1 + ( message ? 1 : 0 ) + ( member ? 1 : 0 ) ) ) return NO;

	if( member ) {
		memberString = [argsArray objectAtIndex:offset];
		if( [memberString hasPrefix:@"/"] && [memberString hasSuffix:@"/"] && [memberString length] > 2 ) {
			memberString = [args substringWithRange:NSMakeRange( 1, [memberString length] - 2 )];
			regex = YES;
		}
		offset++;
	}

	if( message ) {
		if( [args rangeOfString:@"\""].location ) {
			messageString = [args substringWithRange:NSMakeRange( [args rangeOfString:@"\""].location + 1, [args rangeOfString:@"\"" options:NSBackwardsSearch].location - ( [args rangeOfString:@"\""].location + 1 ) )];
		} else if( [args rangeOfString:@"/"].location ) {
			messageString = [args substringWithRange:NSMakeRange( [args rangeOfString:@"/"].location + 1, [args rangeOfString:@"/" options:NSBackwardsSearch].location - ( [args rangeOfString:@"/"].location + 1 ) )];
			regex = YES;
		} else messageString = [argsArray objectAtIndex:offset];
		
		offset += [[messageString componentsSeparatedByString:@" "] count];
	}

	if( offset < [argsArray count] )
		rooms = [argsArray subarrayWithRange:NSMakeRange( offset, [argsArray count] - offset )];

	if( ! rooms && [view isMemberOfClass:NSClassFromString( @"JVChatRoom" )] ) rooms = [NSArray arrayWithObject:[(JVChatRoom *)view target]];

	if( [rooms containsObject:@"*"] ) rooms = nil; // We want all rooms.

	[[_manager chatController] addIgnoreForUser:memberString withMessage:messageString inRooms:rooms usesRegex:regex isPermanent:permanent];

	return YES;
}
@end