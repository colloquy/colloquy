@class MVChatPluginManager;
@class NSString;
@class MVChatConnection;

@protocol MVChatPlugin
- (id) initWithManager:(MVChatPluginManager *) manager;
@end

@interface NSObject (MVChatPluginSubcodeSupport)
- (BOOL) processSubcodeRequest:(NSString *) command withArguments:(NSString *) arguments fromUser:(NSString *) user forConnection:(MVChatConnection *) connection;
- (BOOL) processSubcodeReply:(NSString *) command withArguments:(NSString *) arguments fromUser:(NSString *) user forConnection:(MVChatConnection *) connection;
@end
