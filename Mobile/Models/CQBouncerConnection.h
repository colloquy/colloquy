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
	NSError *_error;
	id _userInfo;
}
- (id) initWithBouncerSettings:(CQBouncerSettings *) settings;

@property (nonatomic, retain) CQBouncerSettings *settings;
@property (nonatomic, retain) id userInfo;

- (void) sendRawMessage:(id) raw;
- (void) sendRawMessageWithFormat:(NSString *) format, ...;

- (void) connect;
- (void) disconnect;

@property (nonatomic, assign) id <CQBouncerConnectionDelegate> delegate;
@end

@protocol CQBouncerConnectionDelegate <NSObject>
@optional
- (void) bouncerConnectionDidConnect:(CQBouncerConnection *) connection;
- (void) bouncerConnectionDidDisconnect:(CQBouncerConnection *) connection withError:(NSError *) error;
- (void) bouncerConnection:(CQBouncerConnection *) connection didRecieveConnectionInfo:(NSDictionary *) info;
- (void) bouncerConnectionDidFinishConnectionList:(CQBouncerConnection *) connection;
@end
