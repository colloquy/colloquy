//
//  MVMessaging.h
//  Chat Core
//
//  Created by C.W. Betts on 1/27/16.
//
//

#import <Foundation/Foundation.h>

#import "MVAvailability.h"
#import "MVChatString.h"

@protocol MVMessaging <NSObject>

@optional
- (void) sendMessage:(MVChatString *) message asAction:(BOOL) action;

@required
- (void) sendMessage:(MVChatString *) message withEncoding:(NSStringEncoding) encoding asAction:(BOOL) action;
- (void) sendMessage:(MVChatString *) message withEncoding:(NSStringEncoding) encoding withAttributes:(NSDictionary *) attributes;

@optional
- (void) sendCommand:(NSString *) command withArguments:(MVChatString *) arguments;
- (void) sendCommand:(NSString *) command withArguments:(MVChatString *) arguments withEncoding:(NSStringEncoding) encoding;

@end
