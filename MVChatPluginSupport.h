@class NSMutableData;
@class NSString;
@class MVChatConnection;
@class NSMutableAttributedString;
@class NSAttributedString;

@interface NSObject (MVChatPluginMessageSupport)
- (NSMutableData *) processRoomMessage:(NSMutableData *) message fromUser:(NSString *) user inRoom:(NSString *) room asAction:(BOOL) action forConnection:(MVChatConnection *) connection;
- (NSMutableData *) processPrivateMessage:(NSMutableData *) message fromUser:(NSString *) user asAction:(BOOL) action forConnection:(MVChatConnection *) connection;

- (NSMutableAttributedString *) processRoomMessage:(NSMutableAttributedString *) message toRoom:(NSString *) room asAction:(BOOL) action forConnection:(MVChatConnection *) connection;
- (NSMutableAttributedString *) processPrivateMessage:(NSMutableAttributedString *) message toUser:(NSString *) user asAction:(BOOL) action forConnection:(MVChatConnection *) connection;
@end

@interface NSObject (MVChatPluginCommandSupport)
- (BOOL) processUserCommand:(NSString *) command withArguments:(NSAttributedString *) arguments forConnection:(MVChatConnection *) connection;
- (BOOL) processUserCommand:(NSString *) command withArguments:(NSAttributedString *) arguments toRoom:(NSString *) room forConnection:(MVChatConnection *) connection;
- (BOOL) processUserCommand:(NSString *) command withArguments:(NSAttributedString *) arguments toUser:(NSString *) user forConnection:(MVChatConnection *) connection;
@end
