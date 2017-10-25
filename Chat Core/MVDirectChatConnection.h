#import <Foundation/Foundation.h>

#import "MVChatConnection.h"
#import "MVMessaging.h"


NS_ASSUME_NONNULL_BEGIN

COLLOQUY_EXPORT extern NSString *MVDirectChatConnectionOfferNotification;

COLLOQUY_EXPORT extern NSString *MVDirectChatConnectionDidConnectNotification;
COLLOQUY_EXPORT extern NSString *MVDirectChatConnectionDidDisconnectNotification;
COLLOQUY_EXPORT extern NSString *MVDirectChatConnectionErrorOccurredNotification;

COLLOQUY_EXPORT extern NSString *MVDirectChatConnectionGotMessageNotification;

COLLOQUY_EXPORT extern NSString *MVDirectChatConnectionErrorDomain;

typedef NS_ENUM(OSType, MVDirectChatConnectionStatus) {
	MVDirectChatConnectionConnectedStatus = 'dcCo',
	MVDirectChatConnectionWaitingStatus = 'dcWa',
	MVDirectChatConnectionDisconnectedStatus = 'dcDs',
	MVDirectChatConnectionErrorStatus = 'dcEr'
};

@class MVChatUser;

COLLOQUY_EXPORT
@interface MVDirectChatConnection : NSObject <MVMessaging>
+ (instancetype) directChatConnectionWithUser:(MVChatUser *) user passively:(BOOL) passive;

@property (getter=isPassive, readonly) BOOL passive;
@property (readonly) MVDirectChatConnectionStatus status;

@property (readonly, strong) MVChatUser *user;
@property (readonly, copy) NSString *host;
@property (readonly, copy) NSString *connectedHost;
@property (readonly) unsigned short port;

- (void) initiate;
- (void) disconnect;

@property NSStringEncoding encoding;

@property MVChatMessageFormat outgoingChatFormat;

- (void) sendMessage:(MVChatString *) message withEncoding:(NSStringEncoding) encoding asAction:(BOOL) action;
- (void) sendMessage:(MVChatString *) message withEncoding:(NSStringEncoding) encoding withAttributes:(NSDictionary<NSString*,id> *)attributes;
@end

NS_ASSUME_NONNULL_END
