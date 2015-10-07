#import <Foundation/Foundation.h>
#import "MVChatConnection.h"

NS_ASSUME_NONNULL_BEGIN

extern NSString *MVDirectChatConnectionOfferNotification;

extern NSString *MVDirectChatConnectionDidConnectNotification;
extern NSString *MVDirectChatConnectionDidDisconnectNotification;
extern NSString *MVDirectChatConnectionErrorOccurredNotification;

extern NSString *MVDirectChatConnectionGotMessageNotification;

extern NSString *MVDirectChatConnectionErrorDomain;

typedef NS_ENUM(OSType, MVDirectChatConnectionStatus) {
	MVDirectChatConnectionConnectedStatus = 'dcCo',
	MVDirectChatConnectionWaitingStatus = 'dcWa',
	MVDirectChatConnectionDisconnectedStatus = 'dcDs',
	MVDirectChatConnectionErrorStatus = 'dcEr'
};

@class MVDirectClientConnection;
@class MVChatUser;

@interface MVDirectChatConnection : NSObject {
@private
	MVDirectClientConnection *_directClientConnection;
	MVChatMessageFormat _outgoingChatFormat;
	NSStringEncoding _encoding;
	NSString *_host;
	NSString *_connectedHost;
	BOOL _passive;
	BOOL _localRequest;
	unsigned short _port;
	long long _passiveId;
	MVChatUser *_user;
	MVDirectChatConnectionStatus _status;
	NSError *_lastError;
}
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
- (void) sendMessage:(MVChatString *) message withEncoding:(NSStringEncoding) encoding withAttributes:(NSDictionary *)attributes;
@end

NS_ASSUME_NONNULL_END
