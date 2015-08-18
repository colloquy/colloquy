@class GCDAsyncSocket;
@class CQBouncerSettings;
@protocol CQBouncerConnectionDelegate;

NS_ASSUME_NONNULL_BEGIN

@interface CQBouncerConnection : NSObject {
	GCDAsyncSocket *_socket;
	CQBouncerSettings *_settings;
	id <CQBouncerConnectionDelegate> __weak _delegate;

	NSString *_connectionIdentifier;
	NSString *_serverAddress;
	unsigned short _serverPort;
	BOOL _secure;
	NSString *_username;
	NSString *_realName;
	NSString *_password;
	NSString *_nickname;
	NSString *_nicknamePassword;
	NSArray *_alternateNicknames;
	NSStringEncoding _encoding;
	NSTimeInterval _connectedTime;
	NSError *_error;
	id _userInfo;
}
- (instancetype) init NS_UNAVAILABLE;
- (instancetype) initWithBouncerSettings:(CQBouncerSettings *) settings NS_DESIGNATED_INITIALIZER;

@property (nonatomic, strong) CQBouncerSettings *settings;
@property (nonatomic, strong) id userInfo;

- (void) sendRawMessage:(id) raw;
- (void) sendRawMessageWithFormat:(NSString *) format, ...;

- (void) connect;
- (void) disconnect;

@property (nonatomic, nullable, weak) id <CQBouncerConnectionDelegate> delegate;
@end

@protocol CQBouncerConnectionDelegate <NSObject>
@optional
- (void) bouncerConnectionDidConnect:(CQBouncerConnection *) connection;
- (void) bouncerConnectionDidDisconnect:(CQBouncerConnection *) connection withError:(NSError *) error;
- (void) bouncerConnection:(CQBouncerConnection *) connection didRecieveConnectionInfo:(NSDictionary *) info;
- (void) bouncerConnectionDidFinishConnectionList:(CQBouncerConnection *) connection;
@end

NS_ASSUME_NONNULL_END
