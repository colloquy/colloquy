#import <Foundation/Foundation.h>

#import "MVChatConnection.h"


NS_ASSUME_NONNULL_BEGIN

extern NSString *MVDirectChatConnectionOfferNotification;

extern NSString *MVDirectChatConnectionDidConnectNotification;
extern NSString *MVDirectChatConnectionDidDisconnectNotification;
extern NSString *MVDirectChatConnectionErrorOccurredNotification;

extern NSString *MVDirectChatConnectionGotMessageNotification;

extern NSString *MVDirectChatConnectionErrorDomain;

typedef enum {
	MVDirectChatConnectionConnectedStatus = 'dcCo',
	MVDirectChatConnectionWaitingStatus = 'dcWa',
	MVDirectChatConnectionDisconnectedStatus = 'dcDs',
	MVDirectChatConnectionErrorStatus = 'dcEr'
} MVDirectChatConnectionStatus;

@class MVChatUser;

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
