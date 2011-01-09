#import "JVStandardCommands.h"
#import "JVChatController.h"
#import "MVConnectionsController.h"
#import "MVChatUserAdditions.h"
#import "JVDirectChatPanel.h"
#import "JVChatRoomPanel.h"
#import "JVChatMessage.h"
#import "JVInspectorController.h"
#import "JVChatUserInspector.h"
#import "JVChatRoomBrowser.h"
#import "JVStyle.h"
#import "JVEmoticonSet.h"

#import <WebKit/WebKit.h>

@interface MVChatConnection (MVChatConnectionInspection) <JVInspection>
- (id <JVInspector>) inspector;
@end

#pragma mark -

@interface JVChatTranscriptPanel (JVChatTranscriptPanelPrivate)
- (void) _reloadCurrentStyle:(id) sender;
@end

#pragma mark -

@interface MVChatConnection (MVChatConnectionPrivate)
- (NSCharacterSet *) _nicknamePrefixes;
@end

#pragma mark -

@implementation JVStandardCommands
- (id) initWithManager:(MVChatPluginManager *) manager {
	return [super init];
}

#pragma mark -

- (BOOL) processUserCommand:(NSString *) command withArguments:(NSAttributedString *) arguments toConnection:(MVChatConnection *) connection inView:(id <JVChatViewController>) view {
	BOOL isChatRoom = [view isKindOfClass:[JVChatRoomPanel class]];
	BOOL isDirectChat = [view isKindOfClass:[JVDirectChatPanel class]];

	JVDirectChatPanel *chat = (JVDirectChatPanel *)view;
	JVChatRoomPanel *room = (JVChatRoomPanel *)view;

	if( isChatRoom || isDirectChat ) {
		if( ! [command caseInsensitiveCompare:@"me"] || ! [command caseInsensitiveCompare:@"action"] || ! [command caseInsensitiveCompare:@"say"] ) {
			if( arguments.length ) {
				JVMutableChatMessage *message = [JVMutableChatMessage messageWithText:arguments sender:chat.connection.localUser];
				if( ! [command caseInsensitiveCompare:@"me"] || ! [command caseInsensitiveCompare:@"action"] ) {
					// This is so plugins can process /me actions as well
					// We're avoiding /say for now, as that really should just output exactly what
					// the input was so we should still bypass plugins for /say
					[message setAction:YES];
					[chat sendMessage:message];
					[chat echoSentMessageToDisplay:message];
				} else {
					if( isChatRoom ) [room.target sendMessage:message.body asAction:NO];
					else [chat.target sendMessage:message.body withEncoding:chat.encoding asAction:NO];
					[chat echoSentMessageToDisplay:message];
				}
			}
			return YES;
		} else if( ! [command caseInsensitiveCompare:@"clear"] && ! arguments.string.length ) {
			[chat clearDisplay:nil];
			return YES;
		} else if( ! [command caseInsensitiveCompare:@"console"] ) {
			id controller = [[JVChatController defaultController] chatConsoleForConnection:chat.connection ifExists:NO];
			[[controller windowController] showChatViewController:controller];
			return YES;
		} else if( ! [command caseInsensitiveCompare:@"reload"] ) {
			if( ! [arguments.string caseInsensitiveCompare:@"style"] ) {
				[chat _reloadCurrentStyle:nil];
				return YES;
			}
		} else if( ! [command caseInsensitiveCompare:@"whois"] || ! [command caseInsensitiveCompare:@"wi"] || ! [command caseInsensitiveCompare:@"wii"] ) {
			NSScanner *scanner = [NSScanner scannerWithString:arguments.string];
			NSString *nick = nil;
			[scanner scanUpToCharactersFromSet:[NSCharacterSet whitespaceAndNewlineCharacterSet] intoString:&nick];

			MVChatUser *user = [[connection chatUsersWithNickname:nick] anyObject];
			if( ! user ) return NO;
			[[JVInspectorController inspectorOfObject:user] show:nil];
			return YES;
		}
	}

	if( isChatRoom ) {
		if( ! [command caseInsensitiveCompare:@"leave"] || ! [command caseInsensitiveCompare:@"part"] ) {
			if( ! arguments.length ) return [self handlePartWithArguments:((MVChatRoom *)room.target).name forConnection:room.connection];
			else return [self handlePartWithArguments:arguments.string forConnection:room.connection];
		} else if( ! [command caseInsensitiveCompare:@"topic"] || ! [command caseInsensitiveCompare:@"t"] ) {
			if( ! arguments.length && connection.type == MVChatConnectionIRCType ) {
				[[room.display windowScriptObject] callWebScriptMethod:@"toggleTopic" withArguments:nil];
				return YES;
			} else if( arguments.length ) {
				[room.target changeTopic:arguments];
				return YES;
			} else return NO;
		} else if( ! [command caseInsensitiveCompare:@"names"] && ! arguments.string.length ) {
			[[room windowController] openViewsDrawer:nil];
			if( [[room windowController] isListItemExpanded:room] ) [[room windowController] collapseListItem:room];
			else [[room windowController] expandListItem:room];
			return YES;
		} else if( ( ! [command caseInsensitiveCompare:@"cycle"] || ! [command caseInsensitiveCompare:@"hop"] ) && ! arguments.string.length ) {
			[room partChat:nil];
			[room joinChat:nil];
			return YES;
		} else if( ! [command caseInsensitiveCompare:@"invite"] && connection.type == MVChatConnectionIRCType ) {
			NSString *nick = nil;
			NSString *roomName = nil;
			NSCharacterSet *whitespace = [NSCharacterSet whitespaceAndNewlineCharacterSet];
			NSScanner *scanner = [NSScanner scannerWithString:arguments.string];

			[scanner scanUpToCharactersFromSet:whitespace intoString:&nick];
			if( ! nick.length ) return NO;
			if( ! [scanner isAtEnd] ) [scanner scanUpToCharactersFromSet:whitespace intoString:&roomName];

			[connection sendRawMessage:[NSString stringWithFormat:@"INVITE %@ %@", nick, ( roomName.length ? roomName : room.target )]];
			return YES;
		} else if( ! [command caseInsensitiveCompare:@"kick"] ) {
			NSString *member = nil;
			NSScanner *scanner = [NSScanner scannerWithString:arguments.string];

			[scanner scanUpToCharactersFromSet:[NSCharacterSet whitespaceAndNewlineCharacterSet] intoString:&member];
			if( ! member.length ) return NO;

			NSAttributedString *reason = nil;
			if( arguments.length >= scanner.scanLocation + 1 )
				reason = [arguments attributedSubstringFromRange:NSMakeRange( scanner.scanLocation + 1, ( arguments.length - scanner.scanLocation - 1 ) )];

			MVChatUser *user = [[room.target memberUsersWithNickname:member] anyObject];
			if( user ) [room.target kickOutMemberUser:user forReason:reason];
			return YES;
		} else if( ! [command caseInsensitiveCompare:@"kickban"] || ! [command caseInsensitiveCompare:@"bankick"] || ! [command caseInsensitiveCompare:@"bk"] || ! [command caseInsensitiveCompare:@"kb"] ) {
			NSString *member = nil;
			NSScanner *scanner = [NSScanner scannerWithString:arguments.string];

			[scanner scanUpToCharactersFromSet:[NSCharacterSet whitespaceAndNewlineCharacterSet] intoString:&member];
			if( ! member.length ) return NO;

			NSAttributedString *reason = nil;
			if( arguments.length >= scanner.scanLocation + 1 )
				reason = [arguments attributedSubstringFromRange:NSMakeRange( scanner.scanLocation + 1, ( arguments.length - scanner.scanLocation - 1 ) )];

			MVChatUser *user = nil;
			if ( [member hasCaseInsensitiveSubstring:@"!"] || [member hasCaseInsensitiveSubstring:@"@"] ) {
				if ( ! [member hasCaseInsensitiveSubstring:@"!"] && [member hasCaseInsensitiveSubstring:@"@"] )
					member = [@"*!*" stringByAppendingString:member];
				user = [MVChatUser wildcardUserFromString:member];
			} else user = [[room.target memberUsersWithNickname:member] anyObject];

			if( user ) {
				[room.target addBanForUser:user];
				[room.target kickOutMemberUser:user forReason:reason];
				return YES;
			}
			return NO;
		} else if( ! [command caseInsensitiveCompare:@"op"] ) {
			NSArray *args = [arguments.string componentsSeparatedByString:@" "];
			for( NSString *arg in args ) {
				if( arg.length ) {
					MVChatUser *user = [[room.target memberUsersWithNickname:arg] anyObject];
					if( user ) [room.target setMode:MVChatRoomMemberOperatorMode forMemberUser:user];
				}
			}
			return YES;
		} else if( ! [command caseInsensitiveCompare:@"deop"] ) {
			NSArray *args = [arguments.string componentsSeparatedByString:@" "];
			for( NSString *arg in args ) {
				if( arg.length ) {
					MVChatUser *user = [[room.target memberUsersWithNickname:arg] anyObject];
					if( user ) [room.target removeMode:MVChatRoomMemberOperatorMode forMemberUser:user];
				}
			}
			return YES;
		} else if( ! [command caseInsensitiveCompare:@"halfop"] ) {
			NSArray *args = [arguments.string componentsSeparatedByString:@" "];
			for( NSString *arg in args ) {
				if( arg.length ) {
					MVChatUser *user = [[room.target memberUsersWithNickname:arg] anyObject];
					if( user ) [room.target setMode:MVChatRoomMemberHalfOperatorMode forMemberUser:user];
				}
			}
			return YES;
		} else if( ! [command caseInsensitiveCompare:@"dehalfop"] ) {
			NSArray *args = [arguments.string componentsSeparatedByString:@" "];
			for( NSString *arg in args ) {
				if( arg.length ) {
					MVChatUser *user = [[room.target memberUsersWithNickname:arg] anyObject];
					if( user ) [room.target removeMode:MVChatRoomMemberHalfOperatorMode forMemberUser:user];
				}
			}
			return YES;
		} else if( ! [command caseInsensitiveCompare:@"voice"] ) {
			NSArray *args = [arguments.string componentsSeparatedByString:@" "];
			for( NSString *arg in args ) {
				if( arg.length ) {
					MVChatUser *user = [[room.target memberUsersWithNickname:arg] anyObject];
					if( user ) [room.target setMode:MVChatRoomMemberVoicedMode forMemberUser:user];
				}
			}
			return YES;
		} else if( ! [command caseInsensitiveCompare:@"devoice"] ) {
			NSArray *args = [arguments.string componentsSeparatedByString:@" "];
			for( NSString *arg in args ) {
				if( arg.length ) {
					MVChatUser *user = [[room.target memberUsersWithNickname:arg] anyObject];
					if( user ) [room.target removeMode:MVChatRoomMemberVoicedMode forMemberUser:user];
				}
			}
			return YES;
		} else if( ! [command caseInsensitiveCompare:@"quiet"] ) {
			NSArray *args = [arguments.string componentsSeparatedByString:@" "];
			for( NSString *arg in args ) {
				if( arg.length ) {
					MVChatUser *user = [[room.target memberUsersWithNickname:arg] anyObject];
					if( user ) [room.target setMode:MVChatRoomMemberQuietedMode forMemberUser:user];
				}
			}
			return YES;
		} else if( ! [command caseInsensitiveCompare:@"dequiet"] ) {
			NSArray *args = [arguments.string componentsSeparatedByString:@" "];
			for( NSString *arg in args ) {
				if( arg.length ) {
					MVChatUser *user = [[room.target memberUsersWithNickname:arg] anyObject];
					if( user ) [room.target removeMode:MVChatRoomMemberQuietedMode forMemberUser:user];
				}
			}
			return YES;
		} else if( ! [command caseInsensitiveCompare:@"ban"] ) {
			NSArray *args = [arguments.string componentsSeparatedByString:@" "];
			for( NSString *arg in args ) {
				if( arg.length ) {
					MVChatUser *user = nil;
					if ( [arg hasCaseInsensitiveSubstring:@"!"] || [arg hasCaseInsensitiveSubstring:@"@"] || ! [room.target memberUsersWithNickname:arg] ) {
						if ( ! [arg hasCaseInsensitiveSubstring:@"!"] && [arg hasCaseInsensitiveSubstring:@"@"] )
							arg = [@"*!*" stringByAppendingString:arg];
						user = [MVChatUser wildcardUserFromString:arg];
					} else user = [[room.target memberUsersWithNickname:arg] anyObject];

					if( user ) [room.target addBanForUser:user];
				}
			}
			return YES;
		} else if( ! [command caseInsensitiveCompare:@"unban"] ) {
			NSArray *args = [arguments.string componentsSeparatedByString:@" "];
			for( NSString *arg in args ) {
				if( arg.length ) {
					MVChatUser *user = nil;
					if ( [arg hasCaseInsensitiveSubstring:@"!"] || [arg hasCaseInsensitiveSubstring:@"@"] || ! [room.target memberUsersWithNickname:arg] ) {
						if ( ! [arg hasCaseInsensitiveSubstring:@"!"] && [arg hasCaseInsensitiveSubstring:@"@"] )
							arg = [@"*!*" stringByAppendingString:arg];
						user = [MVChatUser wildcardUserFromString:arg];
					} else
						user = [[room.target memberUsersWithNickname:arg] anyObject];

					if( user ) [room.target removeBanForUser:user];
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
		[connection setAwayStatusMessage:arguments];
		return YES;
	} else if( ! [command caseInsensitiveCompare:@"aaway"] ) {
		return [self handleMassAwayWithMessage:arguments];
	} else if( ! [command caseInsensitiveCompare:@"anick"] ) {
		return [self handleMassNickChangeWithName:arguments.string];
	} else if( ! [command caseInsensitiveCompare:@"j"] || ! [command caseInsensitiveCompare:@"join"] ) {
		return [self handleJoinWithArguments:arguments.string forConnection:connection];
	} else if( ! [command caseInsensitiveCompare:@"leave"] || ! [command caseInsensitiveCompare:@"part"] ) {
		return [self handlePartWithArguments:arguments.string forConnection:connection];
	} else if( ! [command caseInsensitiveCompare:@"server"] ) {
		return [self handleServerConnectWithArguments:arguments.string];
	} else if( ! [command caseInsensitiveCompare:@"dcc"] ) {
		NSString *subcmd = nil;
		NSScanner *scanner = [NSScanner scannerWithString:arguments.string];
		[scanner scanUpToCharactersFromSet:[NSCharacterSet whitespaceAndNewlineCharacterSet] intoString:&subcmd];
		if( ! [subcmd caseInsensitiveCompare:@"send"] ) {
			return [self handleFileSendWithArguments:arguments.string forConnection:connection];
		} else if( ! [subcmd caseInsensitiveCompare:@"chat"] ) {
			NSString *nick = nil;
			[scanner scanUpToCharactersFromSet:[NSCharacterSet whitespaceAndNewlineCharacterSet] intoString:&nick];

			MVChatUser *user = [[connection chatUsersWithNickname:nick] anyObject];
			[user startDirectChat:nil];
			return YES;
		}

		return NO;
	} else if( ! [command caseInsensitiveCompare:@"raw"] || ! [command caseInsensitiveCompare:@"quote"] ) {
		[connection sendRawMessage:arguments.string immediately:YES];
		return YES;
	} else if( ! [command caseInsensitiveCompare:@"umode"] && connection.type == MVChatConnectionIRCType ) {
		[connection sendRawMessage:[NSString stringWithFormat:@"MODE %@ %@", [connection nickname], arguments.string]];
		return YES;
	} else if( ! [command caseInsensitiveCompare:@"ctcp"] && connection.type == MVChatConnectionIRCType ) {
		return [self handleCTCPWithArguments:arguments.string forConnection:connection];
	} else if( ! [command caseInsensitiveCompare:@"wi"] ) {
		[connection sendRawMessage:[NSString stringWithFormat:@"WHOIS %@", arguments.string]];
		return YES;
	} else if( ! [command caseInsensitiveCompare:@"wii"] ) {
		[connection sendRawMessage:[NSString stringWithFormat:@"WHOIS %@ %@", arguments.string, arguments.string]];
		return YES;
	} else if( ! [command caseInsensitiveCompare:@"list"] ) {
		JVChatRoomBrowser *browser = [JVChatRoomBrowser chatRoomBrowserForConnection:connection];
		[connection fetchChatRoomList];
		[browser showWindow:nil];
		[browser showRoomBrowser:nil];
		browser.filter = arguments.string;
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
		return [self handleIgnoreWithArguments:arguments.string inView:room];
	} else if( ! [command caseInsensitiveCompare:@"unignore"] ) {
		return [self handleUnignoreWithArguments:arguments.string inView:room];
	} else if( ! [command caseInsensitiveCompare:@"invite"] && connection.type == MVChatConnectionIRCType ) {
        NSString *nick = nil;
		NSString *roomName = nil;
        NSCharacterSet *whitespace = [NSCharacterSet whitespaceAndNewlineCharacterSet];
		NSScanner *scanner = [NSScanner scannerWithString:arguments.string];

		[scanner scanUpToCharactersFromSet:whitespace intoString:&nick];
		if( ! nick.length || ! roomName.length ) return NO;
        if( ! [scanner isAtEnd] ) [scanner scanUpToCharactersFromSet:whitespace intoString:&roomName];

		[connection sendRawMessage:[NSString stringWithFormat:@"INVITE %@ %@", nick, roomName]];
        return YES;
	} else if( ! [command caseInsensitiveCompare:@"reload"] ) {
		if( ! [arguments.string caseInsensitiveCompare:@"plugins"] || ! [arguments.string caseInsensitiveCompare:@"scripts"] ) {
			[[MVChatPluginManager defaultManager] reloadPlugins];
			return YES;
		} else if( ! [arguments.string caseInsensitiveCompare:@"styles"] ) {
			[JVStyle scanForStyles];
			return YES;
		} else if( ! [arguments.string caseInsensitiveCompare:@"emoticons"] ) {
			[JVEmoticonSet scanForEmoticonSets];
			return YES;
		} else if( ! [arguments.string caseInsensitiveCompare:@"all"] ) {
			[[MVChatPluginManager defaultManager] reloadPlugins];
			[JVEmoticonSet scanForEmoticonSets];
			[JVStyle scanForStyles];
			if( isChatRoom || isDirectChat )
				[chat _reloadCurrentStyle:nil];
			return YES;
		}
	} else if( ! [command caseInsensitiveCompare:@"help"] ) {
		[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://project.colloquy.info/wiki/Documentation/CommandReference"]];
		return YES;
	} else if( ! [command caseInsensitiveCompare:@"globops"] && connection.type == MVChatConnectionIRCType ) {
		[connection sendRawMessage:[NSString stringWithFormat:@"%@ :%@", command, arguments.string]];
		return YES;
	} else if( ( ! [command caseInsensitiveCompare:@"notice"] || ! [command caseInsensitiveCompare:@"onotice"] ) && connection.type == MVChatConnectionIRCType ) {
        NSString *targetPrefix = nil;
        NSString *target = nil;
        NSString *message = nil;
        NSCharacterSet *whitespace = [NSCharacterSet whitespaceAndNewlineCharacterSet];
        NSMutableCharacterSet *prefixes = [connection.chatRoomNamePrefixes mutableCopy];
		[prefixes addCharactersInString:@"@"];

		NSScanner *scanner = [NSScanner scannerWithString:arguments.string];
		if( [scanner scanCharactersFromSet:prefixes intoString:&targetPrefix] || ! isChatRoom ) {
			[scanner scanUpToCharactersFromSet:whitespace intoString:&target];
			if( targetPrefix.length ) target = [targetPrefix stringByAppendingString:target];
		} else if( isChatRoom ) {
			if( ! [command caseInsensitiveCompare:@"onotice"] )
				target = ((MVChatRoom *)room.target).name;
			else [scanner scanUpToCharactersFromSet:whitespace intoString:&target];
		}
		[prefixes release];

		[scanner scanCharactersFromSet:whitespace intoString:NULL];
		[scanner scanUpToCharactersFromSet:[NSCharacterSet characterSetWithCharactersInString:@"\n"] intoString:&message];

		if( ! target.length || ! message.length ) return YES;

		if( ! [command caseInsensitiveCompare:@"onotice"] && ! [target hasPrefix:@"@"] )
			target = [@"@" stringByAppendingString:[connection properNameForChatRoomNamed:target]];

		[connection sendRawMessage:[NSString stringWithFormat:@"NOTICE %@ :%@", target, message]];

		NSCharacterSet *chanSet = connection.chatRoomNamePrefixes;
		JVDirectChatPanel *chatView = nil;

		// this is an IRC specific command for sending to room operators only.
		if( [target hasPrefix:@"@"] && target.length > 1 )
			target = [target substringFromIndex:1];

		if( ! chanSet || [chanSet characterIsMember:[target characterAtIndex:0]] ) {
			MVChatRoom *room = [connection joinedChatRoomWithName:target];
			if( room ) chatView = [[JVChatController defaultController] chatViewControllerForRoom:room ifExists:YES];
		}

		if( ! chatView ) {
			MVChatUser *user = [[connection chatUsersWithNickname:target] anyObject];
			if( user ) chatView = [[JVChatController defaultController] chatViewControllerForUser:user ifExists:YES];
		}

		if( chatView ) {
			JVMutableChatMessage *cmessage = [JVMutableChatMessage messageWithText:message sender:connection.localUser];
			[cmessage setType:JVChatMessageNoticeType];
			[chatView echoSentMessageToDisplay:cmessage];
		}

		return YES;
	} else if( ! [command caseInsensitiveCompare:@"nick"] ) {
		NSString *newNickname = arguments.string;
		if( newNickname.length )
			connection.nickname = newNickname;
		return YES;
	} else if ( ! [command caseInsensitiveCompare:@"google"] || ! [command caseInsensitiveCompare:@"search"] ) {
		NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"http://www.google.com/search?q=%@", [arguments.string stringByEncodingIllegalURLCharacters]]];
		NSWorkspaceLaunchOptions options = (![[NSUserDefaults standardUserDefaults] boolForKey:@"JVURLOpensInBackground"]) ? NSWorkspaceLaunchDefault : NSWorkspaceLaunchWithoutActivation;

		[[NSWorkspace sharedWorkspace] openURLs:[NSArray arrayWithObject:url] withAppBundleIdentifier:nil options:options additionalEventParamDescriptor:nil launchIdentifiers:nil];

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
	[scanner scanCharactersFromSet:[NSCharacterSet whitespaceCharacterSet] intoString:nil];
	[scanner scanUpToCharactersFromSet:[NSCharacterSet whitespaceCharacterSet] intoString:&to];
	[scanner scanCharactersFromSet:[NSCharacterSet whitespaceCharacterSet] intoString:nil];
	[scanner scanUpToCharactersFromSet:[NSCharacterSet characterSetWithCharactersInString:@"\n\r"] intoString:&path];

	if( ! to.length ) return NO;

	BOOL directory = NO;
	path = [path stringByStandardizingPath];
	if( path.length && ! [[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&directory] ) return YES;
	if( directory ) return YES;

	MVChatUser *user = [[connection chatUsersWithNickname:to] anyObject];

	if( ! path.length )
		[user sendFile:nil];
	else [[NSNotificationCenter defaultCenter] postNotificationName:MVFileTransferStartedNotification object:[user sendFile:path passively:passive]];

	return YES;
}

- (BOOL) handleCTCPWithArguments:(NSString *) arguments forConnection:(MVChatConnection *) connection {
	NSString *to = nil, *ctcpRequest = nil, *ctcpArgs = nil;
	NSScanner *scanner = [NSScanner scannerWithString:arguments];

	[scanner scanUpToCharactersFromSet:[NSCharacterSet whitespaceCharacterSet] intoString:&to];
	[scanner scanUpToCharactersFromSet:[NSCharacterSet whitespaceAndNewlineCharacterSet] intoString:&ctcpRequest];
	[scanner scanUpToCharactersFromSet:[NSCharacterSet characterSetWithCharactersInString:@"\n\r"] intoString:&ctcpArgs];

	if( ! to.length || ! ctcpRequest.length ) return NO;

	MVChatUser *user = [[connection chatUsersWithNickname:to] anyObject];

	[user sendSubcodeRequest:ctcpRequest withArguments:ctcpArgs];
	return YES;
}

- (BOOL) handleServerConnectWithArguments:(NSString *) arguments {
	NSURL *url = nil;
	if( arguments.length && [arguments rangeOfString:@"://"].location != NSNotFound && ( url = [NSURL URLWithString:arguments] ) ) {
		[[MVConnectionsController defaultController] handleURL:url andConnectIfPossible:YES];
	} else if( arguments.length ) {
		NSString *address = nil;
		int port = 0;
		NSScanner *scanner = [NSScanner scannerWithString:arguments];
		[scanner scanUpToCharactersFromSet:[NSCharacterSet whitespaceAndNewlineCharacterSet] intoString:&address];
		[scanner scanInt:&port];

		if( address.length && port ) url = [NSURL URLWithString:[NSString stringWithFormat:@"irc://%@:%u", [address stringByEncodingIllegalURLCharacters], port]];
		else if( address.length && ! port ) url = [NSURL URLWithString:[NSString stringWithFormat:@"irc://%@", [address stringByEncodingIllegalURLCharacters]]];
		else [[MVConnectionsController defaultController] newConnection:nil];

		if( url ) [[MVConnectionsController defaultController] handleURL:url andConnectIfPossible:YES];
	} else [[MVConnectionsController defaultController] newConnection:nil];
	return YES;
}

- (BOOL) handleJoinWithArguments:(NSString *) arguments forConnection:(MVChatConnection *) connection {
	NSArray *channels = [[arguments stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] componentsSeparatedByString:@","];

	if( arguments.length && channels.count == 1 ) {
		[connection joinChatRoomNamed:[arguments stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]]];
		return YES;
	} else if( arguments.length && channels.count > 1 ) {
		for( NSString *channel in channels ) {
			channel = [channel stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
			if( channel.length )
				[(NSMutableArray *)channels addObject:channel];
		}

		[connection joinChatRoomsNamed:channels];
		return YES;
	} else {
		id browser = [JVChatRoomBrowser chatRoomBrowserForConnection:connection];
		[browser showWindow:nil];
		[browser showRoomBrowser:nil];
		return YES;
	}

	return NO;
}

- (BOOL) handlePartWithArguments:(NSString *) arguments forConnection:(MVChatConnection *) connection {
	NSArray *args = [arguments componentsSeparatedByString:@" "];
	NSArray *channels = [[args objectAtIndex:0] componentsSeparatedByString:@","];

	if( channels.count == 1 ) {
		[[connection joinedChatRoomWithName:[channels lastObject]] part];
		return YES;
	} else if( channels.count > 1 ) {
		NSString *message = [[args subarrayWithRange:NSMakeRange(1, args.count - 1)] componentsJoinedByString:@" "];
		NSAttributedString *reason = [[[NSAttributedString alloc] initWithString:message] autorelease];

		for( NSString *channel in channels ) {
			//channel = [channel stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
			if( channel.length ) [[connection joinedChatRoomWithName:channel] partWithReason:reason];
		}

		return YES;
	}

	return NO;
}

- (BOOL) handleMessageCommand:(NSString *) command withMessage:(NSAttributedString *) message forConnection:(MVChatConnection *) connection alwaysShow:(BOOL) always {
	NSString *to = nil;
	NSAttributedString *msg = nil;
	NSScanner *scanner = [NSScanner scannerWithString:message.string];

	[scanner scanUpToCharactersFromSet:[NSCharacterSet whitespaceAndNewlineCharacterSet] intoString:&to];

	if( ! to.length ) return NO;

	if( message.length >= scanner.scanLocation + 1 ) {
		scanner.scanLocation = scanner.scanLocation + 1;
		msg = [message attributedSubstringFromRange:NSMakeRange( scanner.scanLocation, message.length - scanner.scanLocation )];
	}

	BOOL show = NO;
	show = ( ! [command caseInsensitiveCompare:@"query"] ? YES : show );
	show = ( ! msg.length ? YES : show );
	show = ( always ? YES : show );

	JVDirectChatPanel *chatView = nil;

	// this is an IRC specific command for sending to room operators only.
	if( connection.type == MVChatConnectionIRCType ) {
		NSScanner *scanner = [NSScanner scannerWithString:to];
		scanner.charactersToBeSkipped = nil;
		[scanner scanCharactersFromSet:[connection _nicknamePrefixes] intoString:NULL];

		if( scanner.scanLocation ) {
			NSString *roomTargetName = [to substringFromIndex:scanner.scanLocation];
			if( roomTargetName.length > 1 && [connection.chatRoomNamePrefixes characterIsMember:[roomTargetName characterAtIndex:0]] ) {
				[connection sendRawMessage:[NSString stringWithFormat:@"PRIVMSG %@ :%@", to, msg.string]];

				MVChatRoom *room = [connection joinedChatRoomWithName:roomTargetName];
				if( room ) chatView = [[JVChatController defaultController] chatViewControllerForRoom:room ifExists:YES];

				JVMutableChatMessage *cmessage = [JVMutableChatMessage messageWithText:msg sender:connection.localUser];
				[chatView sendMessage:cmessage];
				[chatView echoSentMessageToDisplay:cmessage];

				return YES;
			}
		}
	}

	MVChatRoom *room = nil;
	if( [command isCaseInsensitiveEqualToString:@"msg"] && to.length > 1 && [connection.chatRoomNamePrefixes characterIsMember:[to characterAtIndex:0]] ) {
		room = [connection joinedChatRoomWithName:to];
		if( room ) chatView = [[JVChatController defaultController] chatViewControllerForRoom:room ifExists:YES];
	}

	MVChatUser *user = nil;
	if( ! chatView ) {
		user = [[connection chatUsersWithNickname:to] anyObject];
		if( user ) chatView = [[JVChatController defaultController] chatViewControllerForUser:user ifExists:( ! show )];
	}

	if( chatView && msg.length ) {
		JVMutableChatMessage *cmessage = [JVMutableChatMessage messageWithText:msg sender:connection.localUser];
		[chatView sendMessage:cmessage];
		[chatView addMessageToHistory:msg];
		[chatView echoSentMessageToDisplay:cmessage];
		return YES;
	} else if( ( user || room ) && msg.length ) {
		id target = room;
		if( ! target ) target = user;
		[target sendMessage:msg withEncoding:( room ? room.encoding : connection.encoding ) asAction:NO];
		return YES;
	}

	return NO;
}

- (BOOL) handleMassMessageCommand:(NSString *) command withMessage:(NSAttributedString *) message forConnection:(MVChatConnection *) connection {
	if( ! message.length ) return NO;

	BOOL action = ( ! [command caseInsensitiveCompare:@"ame"] || ! [command caseInsensitiveCompare:@"bract"] );

	for( JVChatRoomPanel *room in [[JVChatController defaultController] chatViewControllersOfClass:[JVChatRoomPanel class]] ) {
		JVMutableChatMessage *cmessage = [JVMutableChatMessage messageWithText:message sender:[room.connection localUser]];
		[cmessage setAction:action];
		[room sendMessage:cmessage];
		[room echoSentMessageToDisplay:cmessage];
	}

	return YES;
}

- (BOOL) handleMassAwayWithMessage:(NSAttributedString *) message {
	for( MVChatConnection *item in [[MVConnectionsController defaultController] connectedConnections] )
		item.awayStatusMessage = message;
	return YES;
}

- (BOOL) handleMassNickChangeWithName:(NSString *) nickname {
	for( MVChatConnection *item in [[MVConnectionsController defaultController] connectedConnections] )
		item.nickname = nickname;
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
	NSUInteger offset = 0;

	if( ! args.length ) {
		id info = [JVInspectorController inspectorOfObject:view.connection];
		[info show:nil];
		[[info inspector] performSelector:@selector(selectTabWithIdentifier:) withObject:@"Ignores"];
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
	if( argsArray.count < ( offset + ( message ? 1 : 0 ) + ( member ? 1 : 0 ) ) ) return NO;

	if( member ) {
		memberString = [argsArray objectAtIndex:offset];
		offset++;
		args = [[argsArray subarrayWithRange:NSMakeRange( offset, argsArray.count - offset )] componentsJoinedByString:@" "];
		// without that, the / test in message could have matched the / from the nick...
	}

	if( message ) {
		if( [args rangeOfString:@"\""].location != NSNotFound ) {
			messageString = [args substringWithRange:NSMakeRange( [args rangeOfString:@"\""].location + 1, [args rangeOfString:@"\"" options:NSBackwardsSearch].location - ( [args rangeOfString:@"\""].location + 1 ) )];
		} else if( [args rangeOfString:@"/"].location != NSNotFound) {
			messageString = [args substringWithRange:NSMakeRange( [args rangeOfString:@"/"].location, [args rangeOfString:@"/" options:NSBackwardsSearch].location - [args rangeOfString:@"/"].location + 1 )];
		} else messageString = [argsArray objectAtIndex:offset];

		offset += [messageString componentsSeparatedByString:@" "].count;
	}

	if( offset < argsArray.count && ((NSString *)[argsArray objectAtIndex:offset]).length )
		rooms = [argsArray subarrayWithRange:NSMakeRange( offset, argsArray.count - offset )];

	KAIgnoreRule *rule = [KAIgnoreRule ruleForUser:memberString message:messageString inRooms:rooms isPermanent:permanent friendlyName:nil];
	NSMutableArray *rules = [[MVConnectionsController defaultController] ignoreRulesForConnection:view.connection];
	[rules addObject:rule];

	return YES;
}

- (BOOL) handleUnignoreWithArguments:(NSString *) args inView:(id <JVChatViewController>) view {
	// USAGE: /unignore -[m|n] [nickname|/regex/] ["message"|/regex/|word] [#rooms ...]
	// m is to specify a message
	// n is to specify a nickname

	// EXAMPLES:
	// /unignore - will open a GUI window to add and manage ignores
	// /unignore Loser23094 - unignore Loser23094 in all rooms
	// /unignore -m "is listening" - unignore any message that has "is listening" from everyone
	// /unignore -m /is listening .*/ - unignore the message expression "is listening *" from everyone
	// /unignore -mn /eevyl.*/ /is listening .*/ #adium #colloquy #here
	// /unignore -n /bunny.*/ - unignore users whose nick starts with bunny in all rooms

	NSArray *argsArray = [args componentsSeparatedByString:@" "];
	NSString *memberString = nil;
	NSString *messageString = nil;
	NSArray *rooms = nil;
	BOOL member = YES;
	BOOL message = NO;
	NSUInteger offset = 0;

	if( ! args.length ) {
		id info = [JVInspectorController inspectorOfObject:view.connection];
		[info show:nil];
		[[info inspector] performSelector:@selector(selectTabWithIdentifier:) withObject:@"Ignores"];
		return YES;
	}

	if( [args hasPrefix:@"-"] ) { // parse commands/flags
		if( [[argsArray objectAtIndex:0] rangeOfString:@"m"].location != NSNotFound ) {
			member = NO;
			message = YES;
		}

		if( [[argsArray objectAtIndex:0] rangeOfString:@"n"].location != NSNotFound ) member = YES;

		offset++; // lookup next arg.
	}

	// check for wrong number of arguments
	if( argsArray.count < ( offset + ( message ? 1 : 0 ) + ( member ? 1 : 0 ) ) ) return NO;

	if( member ) {
		memberString = [argsArray objectAtIndex:offset];
		offset++;
		args = [[argsArray subarrayWithRange:NSMakeRange( offset, argsArray.count - offset )] componentsJoinedByString:@" "];
		// without that, the / test in message could have matched the / from the nick...
	}

	if( message ) {
		if( [args rangeOfString:@"\""].location != NSNotFound ) {
			messageString = [args substringWithRange:NSMakeRange( [args rangeOfString:@"\""].location + 1, [args rangeOfString:@"\"" options:NSBackwardsSearch].location - ( [args rangeOfString:@"\""].location + 1 ) )];
		} else if( [args rangeOfString:@"/"].location != NSNotFound) {
			messageString = [args substringWithRange:NSMakeRange( [args rangeOfString:@"/"].location, [args rangeOfString:@"/" options:NSBackwardsSearch].location - [args rangeOfString:@"/"].location + 1 )];
		} else messageString = [argsArray objectAtIndex:offset];

		offset += [messageString componentsSeparatedByString:@" "].count;
	}

	if( offset < argsArray.count && ((NSString *)[argsArray objectAtIndex:offset]).length )
		rooms = [argsArray subarrayWithRange:NSMakeRange( offset, argsArray.count - offset )];

	NSMutableArray *rules = [[MVConnectionsController defaultController] ignoreRulesForConnection:view.connection];
	for( NSUInteger i = 0; i < rules.count; i++ ) {
		KAIgnoreRule *rule = [rules objectAtIndex:i];
		if( ( !rule.user || [rule.user isCaseInsensitiveEqualToString:memberString] ) && ( !rule.message || [rule.message isCaseInsensitiveEqualToString:messageString] ) && ( !rule.rooms || [rule.rooms isEqualToArray:rooms] ) ) {
			[rules removeObjectAtIndex:i];
			i--;
			break;
		}
	}

	return YES;
}
@end
