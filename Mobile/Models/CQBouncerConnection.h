@class AsyncSocket;
@class CQBouncerSettings;
@protocol CQBouncerConnectionDelegate;

@interface CQBouncerConnection : NSObject {
	AsyncSocket *_socket;
	CQBouncerSettings *_settings;
	id <CQBouncerConnectionDelegate> _delegate;

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
}
- (id) initWithBouncerSettings:(CQBouncerSettings *) settings;

@property (retain) CQBouncerSettings *settings;

- (void) sendRawMessage:(id) raw;
- (void) sendRawMessageWithFormat:(NSString *) format, ...;

- (void) connect;
- (void) disconnect;

@property (assign, nonatomic) id <CQBouncerConnectionDelegate> delegate;
@end

@protocol CQBouncerConnectionDelegate <NSObject>
@optional
- (void) bouncerConnectionDidConnect:(CQBouncerConnection *) connection;
- (void) bouncerConnectionDidDisconnect:(CQBouncerConnection *) connection;
- (void) bouncerConnection:(CQBouncerConnection *) connection didRecieveConnectionInfo:(NSDictionary *) info;
- (void) bouncerConnectionDidFinishConnectionList:(CQBouncerConnection *) connection;
@end
