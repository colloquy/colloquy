#import "JVAutoEmotionDisplay.h"
#import "MVChatConnection.h"

@implementation JVAutoEmotionDisplay
- (id) initWithBundle:(NSBundle *) bundle {
	self = [super init];
	aedStrings = [[NSMutableDictionary dictionary] retain];
	return self;
}

- (void) dealloc {
	[aedStrings autorelease];
	aedStrings = nil;
	[super dealloc];	
}

- (BOOL) processUserCommand:(NSString *) command withArguments:(NSAttributedString *) arguments toRoom:(NSString *) room forConnection:(MVChatConnection *) connection {
	if( [command isEqualToString:@"aed"] ) {
		if( arguments ) [aedStrings setObject:[[arguments copy] autorelease] forKey:room];
		else [aedStrings removeObjectForKey:room];
		return YES;
	}
	return NO;
}

- (BOOL) processUserCommand:(NSString *) command withArguments:(NSAttributedString *) arguments toUser:(NSString *) user forConnection:(MVChatConnection *) connection {
	if( [command isEqualToString:@"aed"] ) {
		if( arguments ) [aedStrings setObject:[[arguments copy] autorelease] forKey:[@":" stringByAppendingString:user]];
		else [aedStrings removeObjectForKey:[@":" stringByAppendingString:user]];
		return YES;
	}
	return NO;
}

- (NSMutableAttributedString *) processRoomMessage:(NSMutableAttributedString *) message toRoom:(NSString *) room asAction:(BOOL) action forConnection:(MVChatConnection *) connection {
	if( [aedStrings objectForKey:room] ) {
		NSMutableAttributedString *appd = [[[NSMutableAttributedString alloc] initWithString:@" "] autorelease];
		[appd appendAttributedString:[aedStrings objectForKey:room]];
		[message appendAttributedString:appd];
	}
	return message;
}

- (NSMutableAttributedString *) processPrivateMessage:(NSMutableAttributedString *) message toUser:(NSString *) user asAction:(BOOL) action forConnection:(MVChatConnection *) connection {
	if( [aedStrings objectForKey:[@":" stringByAppendingString:user]] ) {
		NSMutableAttributedString *appd = [[[NSMutableAttributedString alloc] initWithString:@" "] autorelease];
		[appd appendAttributedString:[aedStrings objectForKey:[@":" stringByAppendingString:user]]];
		[message appendAttributedString:appd];
	}
	return message;
}
@end