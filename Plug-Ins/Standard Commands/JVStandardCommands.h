#import <Foundation/Foundation.h>
#import "MVChatPlugin.h"

@interface JVStandardCommands : NSObject <MVChatPlugin> {}
- (BOOL) handleFileSendWithArguments:(NSString *) arguments forConnection:(MVChatConnection *) connection;
- (BOOL) handleCTCPWithArguments:(NSString *) arguments forConnection:(MVChatConnection *) connection;
- (BOOL) handleServerConnectWithArguments:(NSString *) arguments;
- (BOOL) handleJoinWithArguments:(NSString *) arguments forConnection:(MVChatConnection *) connection;
- (BOOL) handlePartWithArguments:(NSString *) arguments forConnection:(MVChatConnection *) connection;
- (BOOL) handleMessageCommand:(NSString *) command withMessage:(NSAttributedString *) message forConnection:(MVChatConnection *) connection;
- (BOOL) handleMassMessageCommand:(NSString *) command withMessage:(NSAttributedString *) message forConnection:(MVChatConnection *) connection;
@end
