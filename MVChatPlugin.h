#import "MVChatConnection.h"

@protocol MVChatPlugin
- (id) initWithBundle:(NSBundle *) bundle;
@end

@interface NSObject (MVChatPlugin)
- (NSMutableAttributedString *) processRoomMessage:(NSMutableAttributedString *) message fromUser:(NSString *) user inRoom:(NSString *) room asAction:(BOOL) action forConnection:(MVChatConnection *) connection;
- (NSMutableAttributedString *) processPrivateMessage:(NSMutableAttributedString *) message fromUser:(NSString *) user asAction:(BOOL) action forConnection:(MVChatConnection *) connection;

- (NSMutableAttributedString *) processRoomMessage:(NSMutableAttributedString *) message toRoom:(NSString *) room asAction:(BOOL) action forConnection:(MVChatConnection *) connection;
- (NSMutableAttributedString *) processPrivateMessage:(NSMutableAttributedString *) message toUser:(NSString *) user asAction:(BOOL) action forConnection:(MVChatConnection *) connection;

- (BOOL) processUserCommand:(NSString *) command withArguments:(NSAttributedString *) arguments toRoom:(NSString *) room forConnection:(MVChatConnection *) connection;
- (BOOL) processUserCommand:(NSString *) command withArguments:(NSAttributedString *) arguments toUser:(NSString *) user forConnection:(MVChatConnection *) connection;

- (BOOL) processSubcodeRequest:(NSString *) command withArguments:(NSString *) arguments fromUser:(NSString *) user forConnection:(MVChatConnection *) connection;
- (BOOL) processSubcodeReply:(NSString *) command withArguments:(NSString *) arguments fromUser:(NSString *) user forConnection:(MVChatConnection *) connection;
@end
