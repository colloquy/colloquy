//  KAConnectionHandler.h
//  Colloquy
//  Created by Karl Adam on Thu Apr 15 2004.

#import <Cocoa/Cocoa.h>
@class JVChatController;

@interface KAConnectionHandler : NSResponder {
	NSMutableDictionary *_ignoreRules;
}

+ (KAConnectionHandler *) defaultHandler;

- (BOOL) connection:(MVChatConnection *) connection willPostMessage:(NSData *) message from:(NSString *) user toRoom:(BOOL) flag withInfo:(NSDictionary *) info;

- (void) addIgnore:(NSString *)inIgnoreName withKey:(NSString *)ignoreKeyExpression inRooms:(NSArray *) rooms usesRegex:(BOOL) regex isMember:(BOOL) member; 
- (BOOL) shouldIgnoreUser:(NSString *) user inRoom:(NSString *) room;
- (BOOL) shouldIgnoreMessage:(NSAttributedString *) message inRoom:(NSString *) room;
- (BOOL) shouldIgnoreMessage:(NSAttributedString *) message fromUser:(NSString *)user inRoom:(NSString *) room;
@end
