//  KAConnectionHandler.m
//  Colloquy
//  Created by Karl Adam on Thu Apr 15 2004.

#import <ChatCore/MVChatConnection.h>

#import "KAConnectionHandler.h"
#import "MVApplicationController.h"
#import "JVChatController.h"
#import "JVNotificationController.h"

static KAConnectionHandler *sharedHandler = nil;

@implementation KAConnectionHandler
+ (KAConnectionHandler *) defaultHandler {
	extern KAConnectionHandler *sharedHandler;
	if( ! sharedHandler && [MVApplicationController isTerminating] ) return nil;
	return ( sharedHandler ? sharedHandler : ( sharedHandler = [[self alloc] init] ) );
}

# pragma mark -

- (BOOL) connection:(MVChatConnection *) connection willPostMessage:(NSData *) message from:(NSString *) user toRoom:(BOOL) flag {
	BOOL hideFromUser = YES;

	if( [[JVChatController defaultManager] chatViewControllerForUser:user withConnection:connection ifExists:YES] )
		hideFromUser = NO;

	NSString *curMsg = [[[NSString alloc] initWithData:message encoding:NSUTF8StringEncoding] autorelease];
	if( ! curMsg ) curMsg = [NSString stringWithCString:[message bytes] length:[message length]];

	if( [user isEqualToString:@"NickServ"] ) {
		if( [curMsg rangeOfString:@"password accepted" options:NSCaseInsensitiveSearch].location != NSNotFound ) {
			NSMutableDictionary *context = [NSMutableDictionary dictionary];
			[context setObject:NSLocalizedString( @"You Have Been Identified", "identified bubble title" ) forKey:@"title"];
			[context setObject:[NSString stringWithFormat:@"%@ on %@", curMsg, [connection server]] forKey:@"description"];
			[context setObject:[NSImage imageNamed:@"Keychain"] forKey:@"image"];
			[context setObject:[connection nickname] forKey:@"performedOn"];
			[context setObject:user forKey:@"performedBy"];
			[[JVNotificationController defaultManager] performNotification:@"JVNickNameIdentifiedWithServer" withContextInfo:context];
		}
	}

	if( [user isEqualToString:@"MemoServ"] ) {
		if( [curMsg rangeOfString:@"new memo" options:NSCaseInsensitiveSearch].location != NSNotFound && [curMsg rangeOfString:@"no" options:NSCaseInsensitiveSearch].location == NSNotFound ) {
			NSMutableDictionary *context = [NSMutableDictionary dictionary];
			[context setObject:NSLocalizedString( @"You Have New Memos", "new memos bubble title" ) forKey:@"title"];
			[context setObject:curMsg forKey:@"description"];
			[context setObject:[NSImage imageNamed:@"Stickies"] forKey:@"image"];
			[context setObject:[connection nickname] forKey:@"performedOn"];
			[context setObject:user forKey:@"performedBy"];
			[[JVNotificationController defaultManager] performNotification:@"JVNewMemosFromServer" withContextInfo:context];
		}	
	}

	return hideFromUser;
}
@end