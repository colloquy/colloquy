#import <Cocoa/Cocoa.h>
#import "JVStandardCommands.h"
#import "MVChatPluginManagerAdditions.h"
#import "MVConnectionsController.h"
#import "MVChatConnection.h"
#import "NSStringAdditions.h"
#import "JVChatController.h"
#import "MVChatRoom.h"
#import "MVChatUser.h"
#import "JVChatRoom.h"
#import "JVDirectChat.h"
#import "JVChatRoomMember.h"
#import "JVInspectorController.h"
#import "MVFileTransferController.h"
#import "JVChatMemberInspector.h"
#import "JVChatRoomBrowser.h"
#import "JVStyle.h"

@interface MVChatConnection (MVChatConnectionInspection) <JVInspection>
- (id <JVInspector>) inspector;
@end

#pragma mark -

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

#pragma mark -

- (BOOL) processUserCommand:(NSString *) command withArguments:(NSAttributedString *) arguments toConnection:(MVChatConnection *) connection inView:(id <JVChatViewController>) view {
	BOOL isChatRoom = [view isKindOfClass:NSClassFromString( @"JVChatRoom" )];
	BOOL isDirectChat = [view isKindOfClass:NSClassFromString( @"JVDirectChat" )];

	JVDirectChat *chat = view;
	JVChatRoom *room = view;

	if( isChatRoom || isDirectChat ) {
		if( ! [command caseInsensitiveCompare:@"me"] || ! [command caseInsensitiveCompare:@"action"] || ! [command caseInsensitiveCompare:@"say"] ) {
			if( [arguments length] ) {
				if( ! [command caseInsensitiveCompare:@"me"] || ! [command caseInsensitiveCompare:@"action"] ) {
					// This is so plugins can process /me actions as well
					// We're avoiding /say for now, as that really should just output exactly what
					// the input was so we should still bypass plugins for /say
					JVMutableChatMessage *message = [[[NSClassFromString( @"JVMutableChatMessage" ) alloc] initWithText:arguments sender:[[chat connection] nickname] andTranscript:chat] autorelease];
					[message setAction:YES];
					[chat sendMessage:message];
					[chat echoSentMessageToDisplay:[message body] asAction:YES];
				} else {
					[chat echoSentMessageToDisplay:arguments asAction:NO];
					if( isChatRoom ) [[room target] sendMessage:arguments asAction:NO];
					else [[chat target] sendMessage:arguments withEncoding:[chat encoding] asAction:NO];
				}
			}
			return YES;
		} else if( ! [command caseInsensitiveCompare:@"clear"] && ! [[arguments string] length] ) {
			[chat clearDisplay:nil];
			return YES;
		} else if( ! [command caseInsensitiveCompare:@"console"] ) {
			id controller = [[_manager chatController] chatConsoleForConnection:[chat connection] ifExists:NO];
			[[controller windowController] showChatViewController:controller];
			return YES;
		} else if( ! [command caseInsensitiveCompare:@"reload"] ) {
			if( [[arguments string] isEqualToString:@"style"] ) {
				[chat _reloadCurrentStyle:nil];
				return YES;
			}
		} else if( ! [command caseInsensitiveCompare:@"whois"] || ! [command caseInsensitiveCompare:@"wi"] ) {
//			id member = [[[NSClassFromString( @"JVChatRoomMember" ) alloc] initWithRoom:room andNickname:[arguments string]] autorelease];
//			id info = [NSClassFromString( @"JVInspectorController" ) inspectorOfObject:member];
//			[(id)[info inspector] setFetchLocalServerInfoOnly:YES];
//			[info show:nil];
			return YES;
		} else if( ! [command caseInsensitiveCompare:@"wii"] ) {
//			id member = [[[NSClassFromString( @"JVChatRoomMember" ) alloc] initWithRoom:room andNickname:[arguments string]] autorelease];
//			[[NSClassFromString( @"JVInspectorController" ) inspectorOfObject:member] show:nil];
			return YES;
		}
	}

	if( isChatRoom ) {
		if( ! [command caseInsensitiveCompare:@"leave"] || ! [command caseInsensitiveCompare:@"part"] ) {
			if( ! [arguments length] ) return [self handlePartWithArguments:[[room target] name] forConnection:[room connection]];
			else return [self handlePartWithArguments:[arguments string] forConnection:[room connection]];
		} else if( ! [command caseInsensitiveCompare:@"topic"] || ! [command caseInsensitiveCompare:@"t"] ) {
			if( ! [arguments length] ) return NO;
			[[room target] setTopic:arguments];
			return YES;
		} else if( ! [command caseInsensitiveCompare:@"names"] && ! [[arguments string] length] ) {
			[[room windowController] openViewsDrawer:nil];
			if( [[room windowController] isListItemExpanded:room] ) [[room windowController] collapseListItem:room];
			else [[room windowController] expandListItem:room];
			return YES;
		} else if( ( ! [command caseInsensitiveCompare:@"cycle"] || ! [command caseInsensitiveCompare:@"hop"] ) && ! [[arguments string] length] ) {
			[room setKeepAfterPart:YES];
			[room partChat:nil];
			[room joinChat:nil];
			return YES;
		} else if( ! [command caseInsensitiveCompare:@"invite"] ) {
			NSString *nick = nil;
			NSString *roomName = nil;
			NSCharacterSet *whitespace = [NSCharacterSet whitespaceAndNewlineCharacterSet];
			NSScanner *scanner = [NSScanner scannerWithString:[arguments string]];

			[scanner scanUpToCharactersFromSet:whitespace intoString:&nick];
			if( ! [nick length] ) return NO;
			if( ! [scanner isAtEnd] ) [scanner scanUpToCharactersFromSet:whitespace intoString:&roomName];

			[connection sendRawMessage:[NSString stringWithFormat:@"INVITE %@ %@", nick, ( [roomName length] ? roomName : [room target] )]];
			return YES;
		} else if( ! [command caseInsensitiveCompare:@"kick"] ) {
			NSString *member = nil;
			NSScanner *scanner = [NSScanner scannerWithString:[arguments string]];

			[scanner scanUpToCharactersFromSet:[NSCharacterSet whitespaceAndNewlineCharacterSet] intoString:&member];
			if( ! [member length] ) return NO;

			NSAttributedString *reason = nil;
			if( [arguments length] >= [scanner scanLocation] + 1 )
				reason = [arguments attributedSubstringFromRange:NSMakeRange( [scanner scanLocation] + 1, ( [arguments length] - [scanner scanLocation] - 1 ) )];

			MVChatUser *user = [[[room target] memberUsersWithNickname:member] anyObject];
			[[room target] kickOutMemberUser:user forReason:reason];
			return YES;
		} else if( ! [command caseInsensitiveCompare:@"op"] ) {
			NSArray *args = [[arguments string] componentsSeparatedByString:@" "];
			NSEnumerator *e = [args objectEnumerator];
			NSString *arg = nil;
			while( arg = [e nextObject] ) {
				if( [arg length] ) {
					MVChatUser *user = [[[room target] memberUsersWithNickname:arg] anyObject];
					[[room target] setMode:MVChatRoomMemberOperatorMode forMemberUser:user];
				}
			}
			return YES;
		} else if( ! [command caseInsensitiveCompare:@"deop"] ) {
			NSArray *args = [[arguments string] componentsSeparatedByString:@" "];
			NSEnumerator *e = [args objectEnumerator];
			NSString *arg = nil;
			while( arg = [e nextObject] ) {
				if( [arg length] ) {
					MVChatUser *user = [[[room target] memberUsersWithNickname:arg] anyObject];
					[[room target] removeMode:MVChatRoomMemberOperatorMode forMemberUser:user];
				}
			}
			return YES;
		} else if( ! [command caseInsensitiveCompare:@"halfop"] ) {
			NSArray *args = [[arguments string] componentsSeparatedByString:@" "];
			NSEnumerator *e = [args objectEnumerator];
			NSString *arg = nil;
			while( arg = [e nextObject] ) {
				if( [arg length] ) {
					MVChatUser *user = [[[room target] memberUsersWithNickname:arg] anyObject];
					[[room target] setMode:MVChatRoomMemberHalfOperatorMode forMemberUser:user];
				}
			}
			return YES;
		} else if( ! [command caseInsensitiveCompare:@"dehalfop"] ) {
			NSArray *args = [[arguments string] componentsSeparatedByString:@" "];
			NSEnumerator *e = [args objectEnumerator];
			NSString *arg = nil;
			while( arg = [e nextObject] ) {
				if( [arg length] ) {
					MVChatUser *user = [[[room target] memberUsersWithNickname:arg] anyObject];
					[[room target] setMode:MVChatRoomMemberHalfOperatorMode forMemberUser:user];
				}
			}
			return YES;
		} else if( ! [command caseInsensitiveCompare:@"voice"] ) {
			NSArray *args = [[arguments string] componentsSeparatedByString:@" "];
			NSEnumerator *e = [args objectEnumerator];
			NSString *arg = nil;
			while( arg = [e nextObject] ) {
				if( [arg length] ) {
					MVChatUser *user = [[[room target] memberUsersWithNickname:arg] anyObject];
					[[room target] setMode:MVChatRoomMemberVoicedMode forMemberUser:user];
				}
			}
			return YES;
		} else if( ! [command caseInsensitiveCompare:@"devoice"] ) {
			NSArray *args = [[arguments string] componentsSeparatedByString:@" "];
			NSEnumerator *e = [args objectEnumerator];
			NSString *arg = nil;
			while( arg = [e nextObject] ) {
				if( [arg length] ) {
					MVChatUser *user = [[[room target] memberUsersWithNickname:arg] anyObject];
					[[room target] removeMode:MVChatRoomMemberVoicedMode forMemberUser:user];
				}
			}
			return YES;
		} else if( ! [command caseInsensitiveCompare:@"quiet"] ) {
			NSArray *args = [[arguments string] componentsSeparatedByString:@" "];
			NSEnumerator *e = [args objectEnumerator];
			NSString *arg = nil;
			while( arg = [e nextObject] ) {
				if( [arg length] ) {
					MVChatUser *user = [[[room target] memberUsersWithNickname:arg] anyObject];
					[[room target] setMode:MVChatRoomMemberQuietedMode forMemberUser:user];
				}
			}
			return YES;
		} else if( ! [command caseInsensitiveCompare:@"dequiet"] ) {
			NSArray *args = [[arguments string] componentsSeparatedByString:@" "];
			NSEnumerator *e = [args objectEnumerator];
			NSString *arg = nil;
			while( arg = [e nextObject] ) {
				if( [arg length] ) {
					MVChatUser *user = [[[room target] memberUsersWithNickname:arg] anyObject];
					[[room target] removeMode:MVChatRoomMemberQuietedMode forMemberUser:user];
				}
			}
			return YES;
		} else if( ! [command caseInsensitiveCompare:@"ban"] ) {
			NSArray *args = [[arguments string] componentsSeparatedByString:@" "];
			NSEnumerator *e = [args objectEnumerator];
			NSString *arg = nil;
			while( arg = [e nextObject] ) {
				if( [arg length] ) {
					NSArray *parts = [arg componentsSeparatedByString:@"!"];
					NSString *nickname = ( [parts count] >= 1 ? [parts objectAtIndex:0] : nil );
					NSString *host = ( [parts count] >= 2 ? [parts objectAtIndex:1] : nil );
					MVChatUser *user = [NSClassFromString( @"MVChatUser" ) wildcardUserWithNicknameMask:nickname andHostMask:host];
					[[room target] addBanForUser:user];
				}
			}
			return YES;
		} else if( ! [command caseInsensitiveCompare:@"unban"] ) {
			NSArray *args = [[arguments string] componentsSeparatedByString:@" "];
			NSEnumerator *e = [args objectEnumerator];
			NSString *arg = nil;
			while( arg = [e nextObject] ) {
				if( [arg length] ) {
					NSArray *parts = [arg componentsSeparatedByString:@"!"];
					NSString *nickname = ( [parts count] >= 1 ? [parts objectAtIndex:0] : nil );
					NSString *host = ( [parts count] >= 2 ? [parts objectAtIndex:1] : nil );
					MVChatUser *user = [NSClassFromString( @"MVChatUser" ) wildcardUserWithNicknameMask:nickname andHostMask:host];
					[[room target] removeBanForUser:user];
				}
			}
			return YES;
		}
	}

	if( ! [command caseInsensitiveCompare:@"msg"] || ! [command caseInsensitiveCompare:@"query"] ) {
		return [self handleMessageCommand:command withMessage:arguments forConnection:connection alwaysShow:( isChatRoom || isDirectChat )];
	} else if( ! [command caseInsensitiveCompare:@"amsg"] || ! [command caseInsensitiveCompare:@"ame"] || ! [command caseInsensitiveCompare:@"broadcast"] || ! [command caseInsensitiveCompare:@"bract"] ) {
		return [self handleMassMessageCommand:command withMessage:arguments forConnection:connection];
	} else if( ! [command caseInsensitiveCompare:@"away"] ) {
		[connection setAwayStatusWithMessage:arguments];
		return YES;
	} else if( ! [command caseInsensitiveCompare:@"aaway"] ) {
		return [self handleMassAwayWithMessage:arguments];
	} else if( ! [command caseInsensitiveCompare:@"j"] || ! [command caseInsensitiveCompare:@"join"] ) {
		return [self handleJoinWithArguments:[arguments string] forConnection:connection];
	} else if( ! [command caseInsensitiveCompare:@"leave"] || ! [command caseInsensitiveCompare:@"part"] ) {
		return [self handlePartWithArguments:[arguments string] forConnection:connection];
	} else if( ! [command caseInsensitiveCompare:@"server"] ) {
		return [self handleServerConnectWithArguments:[arguments string]];
	} else if( ! [command caseInsensitiveCompare:@"dcc"] ) {
		NSString *subcmd = nil;
		NSScanner *scanner = [NSScanner scannerWithString:[arguments string]];
		[scanner scanUpToCharactersFromSet:[NSCharacterSet whitespaceAndNewlineCharacterSet] intoString:&subcmd];
		if( [subcmd isEqualToString:@"send"] )
			return [self handleFileSendWithArguments:[arguments string] forConnection:connection];
		return NO;
	} else if( ! [command caseInsensitiveCompare:@"raw"] || ! [command caseInsensitiveCompare:@"quote"] ) {
		[connection sendRawMessage:[arguments string] immediately:YES];
		return YES;
	} else if( ! [command caseInsensitiveCompare:@"umode"] ) {
		[connection sendRawMessage:[NSString stringWithFormat:@"MODE %@ %@", [connection nickname], [arguments string]]];
		return YES;
	} else if( ! [command caseInsensitiveCompare:@"ctcp"] ) {
		return [self handleCTCPWithArguments:[arguments string] forConnection:connection];
	} else if( ! [command caseInsensitiveCompare:@"wi"] ) {
//		[connection fetchInformationForUser:[arguments string] withPriority:NO fromLocalServer:YES];
		return YES;
	} else if( ! [command caseInsensitiveCompare:@"wii"] ) {
//		[connection fetchInformationForUser:[arguments string] withPriority:NO fromLocalServer:NO];
		return YES;
	} else if( ! [command caseInsensitiveCompare:@"list"] ) {
		JVChatRoomBrowser *browser = [NSClassFromString( @"JVChatRoomBrowser" ) chatRoomBrowserForConnection:connection];
		[connection fetchChatRoomList];
		[browser showWindow:nil];
		if( [[arguments string] length] ) {
			[browser setFilter:[arguments string]];
			[browser showRoomBrowser:nil];
		}
		return YES;
	} else if( ! [command caseInsensitiveCompare:@"quit"] || ! [command caseInsensitiveCompare:@"disconnect"] ) {
		[connection disconnectWithReason:arguments];
		return YES;
	} else if( ! [command caseInsensitiveCompare:@"reconnect"] || ! [command caseInsensitiveCompare:@"server"] ) {
		[connection connect];
		return YES;
	} else if( ! [command caseInsensitiveCompare:@"exit"] ) {
		[[NSApplication sharedApplication] terminate:nil];
		return YES;
	} else if( ! [command caseInsensitiveCompare:@"ignore"] ) {
		return [self handleIgnoreWithArguments:[arguments string] inView:room];
	} else if( ! [command caseInsensitiveCompare:@"invite"] ) {
        NSString *nick = nil;
		NSString *roomName = nil;
        NSCharacterSet *whitespace = [NSCharacterSet whitespaceAndNewlineCharacterSet];
		NSScanner *scanner = [NSScanner scannerWithString:[arguments string]];

		[scanner scanUpToCharactersFromSet:whitespace intoString:&nick];
		if( ! [nick length] || ! [roomName length] ) return NO;
        if( ! [scanner isAtEnd] ) [scanner scanUpToCharactersFromSet:whitespace intoString:&roomName];

		[connection sendRawMessage:[NSString stringWithFormat:@"INVITE %@ %@", nick, roomName]];
        return YES;
	} else if( ! [command caseInsensitiveCompare:@"reload"] ) {
		if( [[arguments string] isEqualToString:@"plugins"] ) {
			[_manager findAndLoadPlugins];
			return YES;
		} else if( [[arguments string] isEqualToString:@"styles"] ) {
			[NSClassFromString( @"JVStyle" ) scanForStyles];
			return YES;
		} else if( [[arguments string] isEqualToString:@"emoticons"] ) {
			[[NSNotificationCenter defaultCenter] postNotificationName:@"JVChatEmoticonSetInstalledNotification" object:nil]; 
			return YES;
		}
	} else if( ! [command caseInsensitiveCompare:@"globops"] ) {
		[connection sendRawMessage:[NSString stringWithFormat:@"%@ :%@", command, [arguments string]]];
		return YES;
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

	if( ! [to length] ) return NO;

	MVChatUser *user = [[connection chatUsersWithNickname:to] anyObject];

	if( ! [path length] ) {
		NSOpenPanel *panel = [NSOpenPanel openPanel];
		[panel setResolvesAliases:YES];
		[panel setCanChooseFiles:YES];
		[panel setCanChooseDirectories:NO];
		[panel setAllowsMultipleSelection:YES];
		if( [panel runModalForTypes:nil] == NSOKButton ) {
			NSEnumerator *enumerator = [[panel filenames] objectEnumerator];
			while( ( path = [enumerator nextObject] ) )
				[[_manager fileTransferController] addFileTransfer:[user sendFile:path passively:passive]];
		}
	} else [[_manager fileTransferController] addFileTransfer:[user sendFile:path passively:passive]];
	return YES;
}

- (BOOL) handleCTCPWithArguments:(NSString *) arguments forConnection:(MVChatConnection *) connection {
	NSString *to = nil, *ctcpRequest = nil, *ctcpArgs = nil;
	NSScanner *scanner = [NSScanner scannerWithString:arguments];

	[scanner scanUpToCharactersFromSet:[NSCharacterSet whitespaceCharacterSet] intoString:&to];
	[scanner scanUpToCharactersFromSet:[NSCharacterSet whitespaceAndNewlineCharacterSet] intoString:&ctcpRequest];
	[scanner scanUpToCharactersFromSet:[NSCharacterSet characterSetWithCharactersInString:@"\n\r"] intoString:&ctcpArgs];

	if( ! [to length] || ! [ctcpRequest length] ) return NO;

	MVChatUser *user = [[connection chatUsersWithNickname:to] anyObject];

	[user sendSubcodeRequest:ctcpRequest withArguments:ctcpArgs];
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

	if( [arguments length] && [channels count] == 1 ) {
		[connection joinChatRoomNamed:arguments];
		return YES;
	} else if( [arguments length] && [channels count] > 1 ) {
		NSEnumerator *chanEnum = [channels objectEnumerator];
		NSString *channel = nil;

		channels = [NSMutableArray array];
		while( ( channel = [chanEnum nextObject] ) ) {
			channel = [channel stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
			[(NSMutableArray *)channels addObject:channel];
		}

		[connection joinChatRoomsNamed:channels];
		return YES;
	} else {
		id browser = [NSClassFromString( @"JVChatRoomBrowser" ) chatRoomBrowserForConnection:connection];
		[browser showWindow:nil];
		[browser setFilter:arguments];
		[browser showRoomBrowser:nil];
		return YES;
	}

	return NO;
}

- (BOOL) handlePartWithArguments:(NSString *) arguments forConnection:(MVChatConnection *) connection {
	NSArray *channels = [arguments componentsSeparatedByString:@","];

	if( [arguments length] && [channels count] == 1 ) {
		[[connection joinedChatRoomWithName:arguments] part];
		return YES;
	} else if( [arguments length] && [channels count] > 1 ) {
		NSEnumerator *chanEnum = [channels objectEnumerator];
		NSString *channel = nil;

		while( ( channel = [chanEnum nextObject] ) ) {
			channel = [channel stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
			if( [channel length] ) [[connection joinedChatRoomWithName:channel] part];
		}

		return YES;
	}

	return NO;
}

- (BOOL) handleMessageCommand:(NSString *) command withMessage:(NSAttributedString *) message forConnection:(MVChatConnection *) connection alwaysShow:(BOOL) always {
	NSString *to = nil;
	NSAttributedString *msg = nil;
	NSScanner *scanner = [NSScanner scannerWithString:[message string]];

	[scanner scanUpToCharactersFromSet:[NSCharacterSet whitespaceAndNewlineCharacterSet] intoString:&to];

	if( ! [to length] ) return NO;

	MVChatUser *user = [[connection chatUsersWithNickname:to] anyObject];

	if( [message length] >= [scanner scanLocation] + 1 ) {
		[scanner setScanLocation:[scanner scanLocation] + 1];
		msg = [message attributedSubstringFromRange:NSMakeRange( [scanner scanLocation], [message length] - [scanner scanLocation] )];
	}

	BOOL show = NO;
	show = ( ! [command caseInsensitiveCompare:@"query"] ? YES : show );
	show = ( ! [msg length] ? YES : show );
	show = ( always ? YES : show );

	NSCharacterSet *chanSet = [connection chatRoomNamePrefixes];
	JVDirectChat *chatView = nil;

	if( ! [command caseInsensitiveCompare:@"msg"] && ( ! chanSet || [chanSet characterIsMember:[to characterAtIndex:0]] ) ) {
		MVChatRoom *room = [connection joinedChatRoomWithName:to];
		chatView = [[_manager chatController] chatViewControllerForRoom:room ifExists:YES];
	}

	if( ! chatView ) chatView = [[_manager chatController] chatViewControllerForUser:user ifExists:( ! show )];

	if( [msg length] ) {
		[chatView echoSentMessageToDisplay:msg asAction:NO];
		if( [[chatView target] isKindOfClass:NSClassFromString( @"MVChatRoom" )] ) {
			[[chatView target] sendMessage:msg asAction:NO];
		} else {
			NSStringEncoding encoding = [chatView encoding];
			if( ! encoding ) encoding = [connection encoding];
			[[chatView target] sendMessage:msg withEncoding:encoding asAction:NO];
		}
	}

	return YES;
}

- (BOOL) handleMassMessageCommand:(NSString *) command withMessage:(NSAttributedString *) message forConnection:(MVChatConnection *) connection {
	if( ! [message length] ) return NO;

	BOOL action = ( ! [command caseInsensitiveCompare:@"ame"] || ! [command caseInsensitiveCompare:@"bract"] );

	NSEnumerator *enumerator = [[[_manager chatController] chatViewControllersOfClass:NSClassFromString( @"JVChatRoom" )] objectEnumerator];
	JVChatRoom *room = nil;
	while( ( room = [enumerator nextObject] ) ) {
		[room echoSentMessageToDisplay:message asAction:action];
		[[room target] sendMessage:message asAction:action];
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
	// USAGE: /ignore -[p|m|n] [nickname|/regex/] ["message"|/regex/|word] [#rooms ...]
	// p makes the ignore permanent (i.e. the ignore is saved to disk)
	// m is to specify a message
	// n is to specify a nickname

	// EXAMPLES: 
	// /ignore - will open a GUI window to add and manage ignores
	// /ignore Loser23094 - ignore Loser23094 in all rooms
	// /ignore -m "is listening" - ignore any message that has "is listening" from everyone
	// /ignore -m /is listening .*/ - ignore the message expression "is listening *" from everyone
	// /ignore -mn /eevyl.*/ /is listening .*/ #adium #colloquy #here
	// /ignore -n /bunny.*/ - ignore users whose nick starts with bunny in all rooms

	NSArray *argsArray = [args componentsSeparatedByString:@" "];
	NSString *memberString = nil;
	NSString *messageString = nil;
	NSArray *rooms = nil;
	BOOL permanent = NO;
	BOOL member = YES;
	BOOL message = NO;
	int offset = 0;

	if( ! [args length] ) {
		id info = [NSClassFromString( @"JVInspectorController" ) inspectorOfObject:[view connection]];
		[info show:nil];		
		[(id)[info inspector] performSelector:@selector(selectTabWithIdentifier:) withObject:@"Ignores"];
		return YES;
	}

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
	if( [argsArray count] < ( offset + ( message ? 1 : 0 ) + ( member ? 1 : 0 ) ) ) return NO;

	if( member ) {
		memberString = [argsArray objectAtIndex:offset];
		offset++;
		args = [[argsArray subarrayWithRange:NSMakeRange( offset, [argsArray count] - offset )] componentsJoinedByString:@" "];
		// without that, the / test in message could have matched the / from the nick...
	}

	if( message ) {
		if( [args rangeOfString:@"\""].location != NSNotFound ) {
			messageString = [args substringWithRange:NSMakeRange( [args rangeOfString:@"\""].location + 1, [args rangeOfString:@"\"" options:NSBackwardsSearch].location - ( [args rangeOfString:@"\""].location + 1 ) )];
		} else if( [args rangeOfString:@"/"].location != NSNotFound) {
			messageString = [args substringWithRange:NSMakeRange( [args rangeOfString:@"/"].location, [args rangeOfString:@"/" options:NSBackwardsSearch].location - [args rangeOfString:@"/"].location + 1 )];
		} else messageString = [argsArray objectAtIndex:offset];

		offset += [[messageString componentsSeparatedByString:@" "] count];
	}

	if( offset < [argsArray count] && [(NSString *)[argsArray objectAtIndex:offset] length] )
		rooms = [argsArray subarrayWithRange:NSMakeRange( offset, [argsArray count] - offset )];

	KAIgnoreRule *rule = [NSClassFromString( @"KAIgnoreRule" ) ruleForUser:memberString message:messageString inRooms:rooms isPermanent:permanent friendlyName:nil];
	NSMutableArray *rules = [[_manager connectionsController] ignoreRulesForConnection:[view connection]];
	[rules addObject:rule];

	return YES;
}
@end
