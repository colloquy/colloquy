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
