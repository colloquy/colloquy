//  KAIgnoreRule.h
//  Colloquy
//  Created by Karl Adam on Thu Apr 15 2004.

#import <Foundation/NSObject.h>

@class JVChatController;
@class NSString;
@class NSArray;

@interface KAInternalIgnoreRule : NSObject {
	NSString *_ignoredKey;
	NSArray *_inChannels;
	BOOL _regex;
	BOOL _memberIgnore;
}
+ (id) ruleWithString:(NSString *) string inRooms:(NSArray *) rooms usesRegex:(BOOL) regex ignoreMember:(BOOL) member;

- (id) initWithString:(NSString *) string inRooms:(NSArray *) rooms usesRegex:(BOOL) regex ignoreMember:(BOOL) member;

- (NSString *) key;
- (NSArray *) channels;
- (BOOL) isMember;
- (BOOL) regex;
@end