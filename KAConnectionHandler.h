//
//  KAConnectionHandler.h
//  Colloquy
//
//  Created by Karl Adam on Thu Apr 15 2004.
//  Copyright (c) 2004 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "JVChatController.h"

@interface KAConnectionHandler : NSObject {

}

+ (KAConnectionHandler *) defaultHandler;

#pragma mark -

- (BOOL) connection:(MVChatConnection *) connection willPostMessage:(NSData *) message from:(NSString *) user toRoom:(BOOL) flag;
@end
