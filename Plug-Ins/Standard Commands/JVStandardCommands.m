#import <Cocoa/Cocoa.h>
#import "JVStandardCommands.h"
#import "MVChatWindowController.h"
#import "MVConnectionsController.h"

@implementation JVStandardCommands
- (id) initWithBundle:(NSBundle *) bundle {
	self = [super init];
	return self;
}

- (BOOL) processUserCommand:(NSString *) command withArguments:(NSAttributedString *) arguments toRoom:(NSString *) room forConnection:(MVChatConnection *) connection {
	Class chatWindowControllerClass = NSClassFromString( @"MVChatWindowController" );
	Class connectionsControllerClass = NSClassFromString( @"MVConnectionsController" );
	if( [command isEqualToString:@"me"] || [command isEqualToString:@"action"] || [command isEqualToString:@"say"] ) {
		if( [arguments length] )
			[connection sendMessageToChatRoom:room attributedMessage:arguments withEncoding:NSUTF8StringEncoding asAction:( [command isEqualToString:@"me"] || [command isEqualToString:@"action"] )];
		return YES;
	} else if( [command isEqualToString:@"msg"] || [command isEqualToString:@"query"] ) {
		NSString *to = nil;
		NSAttributedString *msg = nil;
		NSScanner *scanner = [NSScanner scannerWithString:[arguments string]];

		[scanner scanUpToCharactersFromSet:[NSCharacterSet whitespaceAndNewlineCharacterSet] intoString:&to];
		if( [arguments length] >= [scanner scanLocation] + 1 ) {
			[scanner setScanLocation:[scanner scanLocation] + 1];
			msg = [arguments attributedSubstringFromRange:NSMakeRange( [scanner scanLocation], [arguments length] - [scanner scanLocation] )];
		}

		if( [command isEqualToString:@"query"] ) {
			MVChatWindowController *window = [chatWindowControllerClass chatWindowWithUser:to withConnection:connection ifExists:NO];
			[window showWindowAndMakeKey:nil];
		}

		if( [msg length] ) [connection sendMessageToUser:to attributedMessage:msg withEncoding:NSUTF8StringEncoding asAction:NO];
		return YES;
	} else if( [command isEqualToString:@"amsg"] || [command isEqualToString:@"ame"] ) {
		NSEnumerator *enumerator = [[chatWindowControllerClass roomChatWindowsForConnection:connection] keyEnumerator];
		id item = nil;
		if( ! [arguments length] ) return YES;
		while( ( item = [enumerator nextObject] ) )
			[connection sendMessageToChatRoom:item attributedMessage:arguments withEncoding:NSUTF8StringEncoding asAction:[command isEqualToString:@"ame"]];
		return YES;
	} else if( [command isEqualToString:@"nick"] ) {
		NSString *nick = nil;
		[[NSScanner scannerWithString:[arguments string]] scanUpToCharactersFromSet:[NSCharacterSet whitespaceAndNewlineCharacterSet] intoString:&nick];
		[connection setNickname:nick];
		return YES;
	} else if( [command isEqualToString:@"away"] ) {
		[connection setAwayStatusWithMessage:[arguments string]];
		return YES;
	} else if( [command isEqualToString:@"join"] ) {
		NSArray *rooms = [[arguments string] componentsSeparatedByString:@" "];
		NSEnumerator *enumerator = [rooms objectEnumerator];
		id item = nil;
		while( ( item = [enumerator nextObject] ) )
			[connection joinChatForRoom:item];
		return YES;
	} else if( [command isEqualToString:@"part"] ) {
		if( ! [arguments string] ) {
			[connection partChatForRoom:room];
		} else {
			NSArray *rooms = [[arguments string] componentsSeparatedByString:@" "];
			NSEnumerator *enumerator = [rooms objectEnumerator];
			id item = nil;
			while( ( item = [enumerator nextObject] ) )
				[connection partChatForRoom:item];
		}
		return YES;
	} else if( [command isEqualToString:@"server"] ) {
		NSURL *url = nil;
		if( [arguments string] && ( url = [NSURL URLWithString:[arguments string]] ) ) {
			[[connectionsControllerClass defaultManager] handleURL:url andConnectIfPossible:YES];
		} else if( [arguments string] ) {
			NSString *address = nil;
			int port = 0;
			NSScanner *scanner = [NSScanner scannerWithString:[arguments string]];
			[scanner scanUpToCharactersFromSet:[NSCharacterSet whitespaceAndNewlineCharacterSet] intoString:&address];
			if( [arguments length] >= [scanner scanLocation] + 1 ) {
				[scanner setScanLocation:[scanner scanLocation] + 1];
				[scanner scanInt:&port];
			}
			
			if( address && port ) url = [NSURL URLWithString:[NSString stringWithFormat:@"irc://%@:%du", MVURLEncodeString( address ), port]];
			else if( address && ! port ) url = [NSURL URLWithString:[NSString stringWithFormat:@"irc://%@", MVURLEncodeString( address )]];
			else [[connectionsControllerClass defaultManager] newConnection:nil];

			if( url ) [[connectionsControllerClass defaultManager] handleURL:url andConnectIfPossible:YES];
		} else [[connectionsControllerClass defaultManager] newConnection:nil];
		return YES;
	} else if( [command isEqualToString:@"dcc"] ) {
		NSString *subcmd = nil;
		NSScanner *scanner = [NSScanner scannerWithString:[arguments string]];
		[scanner scanUpToCharactersFromSet:[NSCharacterSet whitespaceAndNewlineCharacterSet] intoString:&subcmd];
		if( [subcmd isEqualToString:@"send"] ) {
			NSString *to = nil, *path = nil;

			[scanner scanUpToCharactersFromSet:[NSCharacterSet whitespaceCharacterSet] intoString:&to];
			if( [arguments length] >= [scanner scanLocation] + 1 ) {
				[scanner setScanLocation:[scanner scanLocation] + 1];
				path = [[arguments string] substringFromIndex:[scanner scanLocation]];
			}

			if( ! to ) {
				// display error
				return YES;
			}

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
	} else if( [command isEqualToString:@"topic"] ) {
		[connection setTopic:arguments withEncoding:NSUTF8StringEncoding forRoom:room];
		return YES;
	} else if( [command isEqualToString:@"mode"] ) {
		return NO;
	} else if( [command isEqualToString:@"names"] ) {
		MVChatWindowController *window = [chatWindowControllerClass chatWindowForRoom:room withConnection:connection ifExists:NO];
		[window openMemberDrawer:nil];
		return YES;
	} else if( [command isEqualToString:@"clear"] ) {
		MVChatWindowController *window = [chatWindowControllerClass chatWindowForRoom:room withConnection:connection ifExists:NO];
		[window clearDisplay:nil];
		return YES;
	} else if( [command isEqualToString:@"kick"] ) {
		NSString *member = nil, *msg = nil;
		NSScanner *scanner = [NSScanner scannerWithString:[arguments string]];

		[scanner scanUpToCharactersFromSet:[NSCharacterSet whitespaceAndNewlineCharacterSet] intoString:&member];
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
	BOOL handled = NO;
	return handled;
}
@end
