//  KAConnectionHandler.h
//  Colloquy
//  Created by Karl Adam on Thu Apr 15 2004.

#import <Cocoa/Cocoa.h>
#import "JVChatController.h"

@interface KAConnectionHandler : NSObject {}
+ (KAConnectionHandler *) defaultHandler;

- (BOOL) connection:(MVChatConnection *) connection willPostMessage:(NSData *) message from:(NSString *) user toRoom:(BOOL) flag;

- (IBAction) checkMemos:(id) sender;
@end
