//  KAConnectionHandler.h
//  Colloquy
//  Created by Karl Adam on Thu Apr 15 2004.

#import <Cocoa/Cocoa.h>

@class JVChatController;

@interface KAInternalIgnoreRule : NSObject {
	NSString	*_ignoredKey;
	NSArray		*_inChannels;
	BOOL		_regex;
	BOOL		_memberIgnore;
}

- (id) initWithString:(NSString *)inString inRooms:(NSArray *)inRooms usesRegex:(BOOL) inRegex ignoreMember:(BOOL) inMemberIgnore;
+ (id) ruleWithString:(NSString *)inString inRooms:(NSArray *)inRooms usesRegex:(BOOL) inRegex ignoreMember:(BOOL) inMemberIgnore;

- (NSString *) key;
- (NSArray *) channels;
- (BOOL) isMember;
- (BOOL) regex;

@end
