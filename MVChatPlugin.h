@class NSMutableData;
@class NSMutableAttributedString;
@class NSString;
@class NSAttributedString;
@class MVChatConnection;
@class MVChatPluginManager;

@protocol MVChatPlugin
- (id) initWithManager:(MVChatPluginManager *) manager;
@end

@interface NSObject (MVChatPlugin)
- (NSMutableData *) processRoomMessage:(NSMutableData *) message fromUser:(NSString *) user inRoom:(NSString *) room asAction:(BOOL) action forConnection:(MVChatConnection *) connection;
- (NSMutableData *) processPrivateMessage:(NSMutableData *) message fromUser:(NSString *) user asAction:(BOOL) action forConnection:(MVChatConnection *) connection;

- (NSMutableAttributedString *) processRoomMessage:(NSMutableAttributedString *) message toRoom:(NSString *) room asAction:(BOOL) action forConnection:(MVChatConnection *) connection;
- (NSMutableAttributedString *) processPrivateMessage:(NSMutableAttributedString *) message toUser:(NSString *) user asAction:(BOOL) action forConnection:(MVChatConnection *) connection;

- (BOOL) processUserCommand:(NSString *) command withArguments:(NSAttributedString *) arguments forConnection:(MVChatConnection *) connection;
- (BOOL) processUserCommand:(NSString *) command withArguments:(NSAttributedString *) arguments toRoom:(NSString *) room forConnection:(MVChatConnection *) connection;
- (BOOL) processUserCommand:(NSString *) command withArguments:(NSAttributedString *) arguments toUser:(NSString *) user forConnection:(MVChatConnection *) connection;

- (BOOL) processSubcodeRequest:(NSString *) command withArguments:(NSString *) arguments fromUser:(NSString *) user forConnection:(MVChatConnection *) connection;
- (BOOL) processSubcodeReply:(NSString *) command withArguments:(NSString *) arguments fromUser:(NSString *) user forConnection:(MVChatConnection *) connection;
@end
