#import <Foundation/Foundation.h>

#import "MVChatConnection.h"


NS_ASSUME_NONNULL_BEGIN

COLLOQUY_EXPORT extern NSString *MVDirectChatConnectionOfferNotification;

COLLOQUY_EXPORT extern NSString *MVDirectChatConnectionDidConnectNotification;
COLLOQUY_EXPORT extern NSString *MVDirectChatConnectionDidDisconnectNotification;
COLLOQUY_EXPORT extern NSString *MVDirectChatConnectionErrorOccurredNotification;

COLLOQUY_EXPORT extern NSString *MVDirectChatConnectionGotMessageNotification;

COLLOQUY_EXPORT extern NSString *MVDirectChatConnectionErrorDomain;

typedef enum {
	MVDirectChatConnectionConnectedStatus = 'dcCo',
	MVDirectChatConnectionWaitingStatus = 'dcWa',
	MVDirectChatConnectionDisconnectedStatus = 'dcDs',
	MVDirectChatConnectionErrorStatus = 'dcEr'
} MVDirectChatConnectionStatus;

@class MVChatUser;

COLLOQUY_EXPORT
@interface MVDirectChatConnection : NSObject
+ (id) directChatConnectionWithUser:(MVChatUser *) user passively:(BOOL) passive;

- (BOOL) isPassive;
- (MVDirectChatConnectionStatus) status;

- (MVChatUser *) user;
- (NSString *) host;
- (NSString *) connectedHost;
- (unsigned short) port;

- (void) initiate;
- (void) disconnect;

- (void) setEncoding:(NSStringEncoding) encoding;
- (NSStringEncoding) encoding;

- (void) setOutgoingChatFormat:(MVChatMessageFormat) format;
- (MVChatMessageFormat) outgoingChatFormat;

- (void) sendMessage:(MVChatString *) message withEncoding:(NSStringEncoding) encoding asAction:(BOOL) action;
- (void) sendMessage:(MVChatString *) message withEncoding:(NSStringEncoding) encoding withAttributes:(NSDictionary *)attributes;
@end

NS_ASSUME_NONNULL_END
