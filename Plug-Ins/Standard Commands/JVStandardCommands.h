#import "MVChatPluginManager.h"

@class MVChatConnection;
@class MVChatPluginManager;
@protocol JVChatViewController;

@interface JVStandardCommands : NSObject <MVChatPlugin> {
	MVChatPluginManager* _manager;
}
- (BOOL) handleFileSendWithArguments:(NSString *) arguments forConnection:(MVChatConnection *) connection;
- (BOOL) handleCTCPWithArguments:(NSString *) arguments forConnection:(MVChatConnection *) connection;
- (BOOL) handleServerConnectWithArguments:(NSString *) arguments;
- (BOOL) handleJoinWithArguments:(NSString *) arguments forConnection:(MVChatConnection *) connection;
- (BOOL) handlePartWithArguments:(NSString *) arguments forConnection:(MVChatConnection *) connection;
- (BOOL) handleMessageCommand:(NSString *) command withMessage:(NSAttributedString *) message forConnection:(MVChatConnection *) connection alwaysShow:(BOOL) always;
- (BOOL) handleMassMessageCommand:(NSString *) command withMessage:(NSAttributedString *) message forConnection:(MVChatConnection *) connection;
- (BOOL) handleMassAwayWithMessage:(NSAttributedString *) message;
- (BOOL) handleIgnoreWithArguments:(NSString *) args inView:(id <JVChatViewController>) view;
@end
