#import <Cocoa/Cocoa.h>
#import "JVStandardCommands.h"
#import "MVConnectionsController.h"
#import "JVChatController.h"
#import "JVDirectChat.h"
#import "JVChatRoom.h"
#import "MVChatConnection.h"

@implementation JVStandardCommands
- (id) initWithBundle:(NSBundle *) bundle {
	self = [super init];
	return self;
}

- (BOOL) processUserCommand:(NSString *) command withArguments:(NSAttributedString *) arguments forConnection:(MVChatConnection *) connection {
	if( [command isEqualToString:@"msg"] || [command isEqualToString:@"query"] ) {
		return [self handleMessageCommand:command withMessage:arguments forConnection:connection];
	} else if( [command isEqualToString:@"amsg"] || [command isEqualToString:@"ame"] ) {
		return [self handleMassMessageCommand:command withMessage:arguments forConnection:connection];
	} else if( [command isEqualToString:@"away"] ) {
		[connection setAwayStatusWithMessage:[arguments string]];
		return YES;
	} else if( [command isEqualToString:@"join"] ) {
		return [self handleJoinWithArguments:[arguments string] forConnection:connection];
	} else if( [command isEqualToString:@"part"] || [command isEqualToString:@"leave"] ) {
		if( [arguments length] )
			return [self handlePartWithArguments:[arguments string] forConnection:connection];
		return NO;
	} else if( [command isEqualToString:@"server"] ) {
		return [self handleServerConnectWithArguments:[arguments string]];
	} else if( [command isEqualToString:@"dcc"] ) {
		NSString *subcmd = nil;
		NSScanner *scanner = [NSScanner scannerWithString:[arguments string]];
		[scanner scanUpToCharactersFromSet:[NSCharacterSet whitespaceAndNewlineCharacterSet] intoString:&subcmd];
		if( [subcmd isEqualToString:@"send"] )
			return [self handleFileSendWithArguments:[arguments string] forConnection:connection];
		return NO;
	} else if( [command isEqualToString:@"raw"] ) {
		[connection sendRawMessage:[arguments string]];
		return YES;
	} else if( [command isEqualToString:@"ctcp"] ) {
		return [self handleCTCPWithArguments:[arguments string] forConnection:connection];
	} else if( [command isEqualToString:@"quit"] || [command isEqualToString:@"exit"] ) {
		[[NSApplication sharedApplication] terminate:nil];
		return YES;
	} else if( [command isEqualToString:@"disconnect"] ) {
		[connection disconnect];
		return YES;
	}
	return NO;
}

- (BOOL) processUserCommand:(NSString *) command withArguments:(NSAttributedString *) arguments toRoom:(NSString *) room forConnection:(MVChatConnection *) connection {
	if( [command isEqualToString:@"me"] || [command isEqualToString:@"action"] || [command isEqualToString:@"say"] ) {
		JVChatController *chatController = (JVChatController *)[NSClassFromString( @"JVChatController" ) defaultManager];
		NSStringEncoding encoding = [(JVChatRoom *)[chatController chatViewControllerForRoom:room withConnection:connection ifExists:YES] encoding];
		if( [arguments length] ) {
			JVChatRoom *chatView = [chatController chatViewControllerForRoom:room withConnection:connection ifExists:YES];
			[chatView echoSentMessageToDisplay:arguments asAction:( [command isEqualToString:@"me"] || [command isEqualToString:@"action"] )];
			[connection sendMessageToChatRoom:room attributedMessage:arguments withEncoding:encoding asAction:( [command isEqualToString:@"me"] || [command isEqualToString:@"action"] )];
		}
		return YES;
	} else if( [command isEqualToString:@"msg"] || [command isEqualToString:@"query"] ) {
		return [self handleMessageCommand:command withMessage:arguments forConnection:connection];
	} else if( [command isEqualToString:@"amsg"] || [command isEqualToString:@"ame"] ) {
		return [self handleMassMessageCommand:command withMessage:arguments forConnection:connection];
	} else if( [command isEqualToString:@"away"] ) {
		[connection setAwayStatusWithMessage:[arguments string]];
		return YES;
	} else if( [command isEqualToString:@"join"] ) {
		return [self handleJoinWithArguments:[arguments string] forConnection:connection];
	} else if( [command isEqualToString:@"part"] || [command isEqualToString:@"leave"] ) {
		if( ! [arguments length] ) [connection partChatForRoom:room];
		else return [self handlePartWithArguments:[arguments string] forConnection:connection];
		return YES;
	} else if( [command isEqualToString:@"server"] ) {
		return [self handleServerConnectWithArguments:[arguments string]];
	} else if( [command isEqualToString:@"dcc"] ) {
		NSString *subcmd = nil;
		NSScanner *scanner = [NSScanner scannerWithString:[arguments string]];
		[scanner scanUpToCharactersFromSet:[NSCharacterSet whitespaceAndNewlineCharacterSet] intoString:&subcmd];
		if( [subcmd isEqualToString:@"send"] )
			return [self handleFileSendWithArguments:[arguments string] forConnection:connection];
		return NO;
	} else if( [command isEqualToString:@"raw"] ) {
		[connection sendRawMessage:[arguments string]];
		return YES;
	} else if( [command isEqualToString:@"ctcp"] ) {
		return [self handleCTCPWithArguments:[arguments string] forConnection:connection];
	} else if( [command isEqualToString:@"topic"] ) {
		if( ! [arguments length] ) return NO;
		JVChatController *chatController = (JVChatController *)[NSClassFromString( @"JVChatController" ) defaultManager];
		NSStringEncoding encoding = [(JVChatRoom *)[chatController chatViewControllerForRoom:room withConnection:connection ifExists:YES] encoding];
		if( ! encoding ) encoding = (NSStringEncoding) [[NSUserDefaults standardUserDefaults] integerForKey:@"JVChatEncoding"];
		[connection setTopic:arguments withEncoding:encoding forRoom:room];
		return YES;
	} else if( [command isEqualToString:@"mode"] ) {
		NSRange vrange, orange, vsrange, osrange;
		BOOL handled = NO;
		NSScanner *scanner = [NSScanner scannerWithString:[arguments string]];
		NSString *modes = nil, *who = nil;

		if( ! [arguments length] ) return NO;

		[scanner scanUpToCharactersFromSet:[NSCharacterSet whitespaceCharacterSet] intoString:&modes];
		vrange = [modes rangeOfString:@"v"];
		if( vrange.location != NSNotFound ) vsrange = [modes rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:@"-+"] options:NSBackwardsSearch range:NSMakeRange( 0, vrange.location )];
		orange = [modes rangeOfString:@"o"];
		if( orange.location != NSNotFound ) osrange = [modes rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:@"-+"] options:NSBackwardsSearch range:NSMakeRange( 0, orange.location )];

		if( [arguments length] >= [scanner scanLocation] + 1 )
			[scanner setScanLocation:[scanner scanLocation] + 1];
		else return NO;

		[scanner scanUpToCharactersFromSet:[NSCharacterSet whitespaceAndNewlineCharacterSet] intoString:&who];

		if( ! who ) return NO;

		if( vrange.location != NSNotFound && vsrange.location != NSNotFound ) {
			if( [modes characterAtIndex:vsrange.location] == '+' ) [connection voiceMember:who inRoom:room];
			else [connection devoiceMember:who inRoom:room];
			handled = YES;
		}

		if( orange.location != NSNotFound && osrange.location != NSNotFound ) {
			if( [modes characterAtIndex:osrange.location] == '+' ) [connection promoteMember:who inRoom:room];
			else [connection demoteMember:who inRoom:room];
			handled = YES;
		}
		return handled;
	} else if( [command isEqualToString:@"names"] ) {
		JVChatController *chatController = (JVChatController *)[NSClassFromString( @"JVChatController" ) defaultManager];
		JVChatRoom *rm = [chatController chatViewControllerForRoom:room withConnection:connection ifExists:YES];
		[[rm windowController] openViewsDrawer:nil];
		[[rm windowController] expandListItem:rm];
		return YES;
	} else if( [command isEqualToString:@"clear"] ) {
		JVChatController *chatController = (JVChatController *)[NSClassFromString( @"JVChatController" ) defaultManager];
		[(JVChatRoom *)[chatController chatViewControllerForRoom:room withConnection:connection ifExists:YES] clearDisplay:nil];
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

		[connection kickMember:member inRoom:room forReason:msg];
		return YES;
	} else if( [command isEqualToString:@"quit"] || [command isEqualToString:@"exit"] ) {
		[[NSApplication sharedApplication] terminate:nil];
		return YES;
	} else if( [command isEqualToString:@"disconnect"] ) {
		[connection disconnect];
		return YES;
	}
	return NO;
}

- (BOOL) processUserCommand:(NSString *) command withArguments:(NSAttributedString *) arguments toUser:(NSString *) user forConnection:(MVChatConnection *) connection {
	if( [command isEqualToString:@"me"] || [command isEqualToString:@"action"] || [command isEqualToString:@"say"] ) {
		JVChatController *chatController = (JVChatController *)[NSClassFromString( @"JVChatController" ) defaultManager];
		NSStringEncoding encoding = [(JVDirectChat *)[chatController chatViewControllerForUser:user withConnection:connection ifExists:YES] encoding];
		if( [arguments length] ) {
			JVDirectChat *chatView = [chatController chatViewControllerForUser:user withConnection:connection ifExists:YES];
			[chatView echoSentMessageToDisplay:arguments asAction:( [command isEqualToString:@"me"] || [command isEqualToString:@"action"] )];
			[connection sendMessageToUser:user attributedMessage:arguments withEncoding:encoding asAction:( [command isEqualToString:@"me"] || [command isEqualToString:@"action"] )];
		}
		return YES;
	} else if( [command isEqualToString:@"msg"] || [command isEqualToString:@"query"] ) {
		return [self handleMessageCommand:command withMessage:arguments forConnection:connection];
	} else if( [command isEqualToString:@"amsg"] || [command isEqualToString:@"ame"] ) {
		return [self handleMassMessageCommand:command withMessage:arguments forConnection:connection];
	} else if( [command isEqualToString:@"away"] ) {
		[connection setAwayStatusWithMessage:[arguments string]];
		return YES;
	} else if( [command isEqualToString:@"join"] ) {
		return [self handleJoinWithArguments:[arguments string] forConnection:connection];
	} else if( [command isEqualToString:@"part"] || [command isEqualToString:@"leave"] ) {
		if( [arguments length] )
			return [self handlePartWithArguments:[arguments string] forConnection:connection];
		return NO;
	} else if( [command isEqualToString:@"server"] ) {
		return [self handleServerConnectWithArguments:[arguments string]];
	} else if( [command isEqualToString:@"raw"] ) {
		[connection sendRawMessage:[arguments string]];
		return YES;
	} else if( [command isEqualToString:@"ctcp"] ) {
		return [self handleCTCPWithArguments:[arguments string] forConnection:connection];
	} else if( [command isEqualToString:@"dcc"] ) {
		NSString *subcmd = nil;
		NSScanner *scanner = [NSScanner scannerWithString:[arguments string]];
		[scanner scanUpToCharactersFromSet:[NSCharacterSet whitespaceAndNewlineCharacterSet] intoString:&subcmd];
		if( [subcmd isEqualToString:@"send"] )
			return [self handleFileSendWithArguments:[arguments string] forConnection:connection];
		return NO;
	} else if( [command isEqualToString:@"clear"] ) {
		JVChatController *chatController = (JVChatController *)[NSClassFromString( @"JVChatController" ) defaultManager];
		[(JVChatRoom *)[chatController chatViewControllerForUser:user withConnection:connection ifExists:YES] clearDisplay:nil];
	} else if( [command isEqualToString:@"quit"] || [command isEqualToString:@"exit"] ) {
		[[NSApplication sharedApplication] terminate:nil];
		return YES;
	} else if( [command isEqualToString:@"disconnect"] ) {
		[connection disconnect];
		return YES;
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
				[connection sendFileToUser:to withFilePath:path];
		}
	} else [connection sendFileToUser:to withFilePath:path];
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
	MVConnectionsController *connectionsController = (MVConnectionsController *)[NSClassFromString( @"MVConnectionsController" ) defaultManager];
	NSURL *url = nil;
	if( arguments && ( url = [NSURL URLWithString:arguments] ) ) {
		[connectionsController handleURL:url andConnectIfPossible:YES];
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
		else [connectionsController newConnection:nil];

		if( url ) [connectionsController handleURL:url andConnectIfPossible:YES];
	} else [connectionsController newConnection:nil];
	return YES;
}

- (BOOL) handleJoinWithArguments:(NSString *) arguments forConnection:(MVChatConnection *) connection {
	NSArray *rooms = [arguments componentsSeparatedByString:@" "];
	NSEnumerator *enumerator = [rooms objectEnumerator];
	id item = nil;
	if( ! [rooms count] ) return NO;
	while( ( item = [enumerator nextObject] ) )
		[connection joinChatForRoom:item];
	return YES;
}

- (BOOL) handlePartWithArguments:(NSString *) arguments forConnection:(MVChatConnection *) connection {
	NSArray *rooms = [arguments componentsSeparatedByString:@" "];
	NSEnumerator *enumerator = [rooms objectEnumerator];
	id item = nil;
	if( ! [rooms count] ) return NO;
	while( ( item = [enumerator nextObject] ) )
		[connection partChatForRoom:item];
	return YES;
}

- (BOOL) handleMessageCommand:(NSString *) command withMessage:(NSAttributedString *) message forConnection:(MVChatConnection *) connection {
	JVChatController *chatController = (JVChatController *)[NSClassFromString( @"JVChatController" ) defaultManager];
	NSString *to = nil;
	NSAttributedString *msg = nil;
	NSScanner *scanner = [NSScanner scannerWithString:[message string]];

	[scanner scanUpToCharactersFromSet:[NSCharacterSet whitespaceAndNewlineCharacterSet] intoString:&to];

	if( ! to ) return NO;

	NSStringEncoding encoding = [(JVDirectChat *)[chatController chatViewControllerForUser:to withConnection:connection ifExists:YES] encoding];
	if( ! encoding ) encoding = (NSStringEncoding) [[NSUserDefaults standardUserDefaults] integerForKey:@"JVChatEncoding"];

	if( [message length] >= [scanner scanLocation] + 1 ) {
		[scanner setScanLocation:[scanner scanLocation] + 1];
		msg = [message attributedSubstringFromRange:NSMakeRange( [scanner scanLocation], [message length] - [scanner scanLocation] )];
	}

	if( [command isEqualToString:@"query"] ) {
		JVDirectChat *chatView = [chatController chatViewControllerForUser:to withConnection:connection ifExists:NO];
		if( [msg length] ) [chatView echoSentMessageToDisplay:msg asAction:NO];
	}

	if( [msg length] ) [connection sendMessageToUser:to attributedMessage:msg withEncoding:encoding asAction:NO];
	return YES;
}

- (BOOL) handleMassMessageCommand:(NSString *) command withMessage:(NSAttributedString *) message forConnection:(MVChatConnection *) connection {
	JVChatController *chatController = (JVChatController *)[NSClassFromString( @"JVChatController" ) defaultManager];
	NSStringEncoding encoding = (NSStringEncoding) [[NSUserDefaults standardUserDefaults] integerForKey:@"JVChatEncoding"];
	if( ! [message length] ) return NO;
	NSEnumerator *enumerator = [[chatController chatViewControllersOfClass:NSClassFromString( @"JVChatRoom" )] objectEnumerator];
	id item = nil;
	while( ( item = [enumerator nextObject] ) ) {
		[connection sendMessageToChatRoom:[item target] attributedMessage:message withEncoding:encoding asAction:[command isEqualToString:@"ame"]];
		[item echoSentMessageToDisplay:message asAction:[command isEqualToString:@"ame"]];
	}
	return YES;
}
@end
