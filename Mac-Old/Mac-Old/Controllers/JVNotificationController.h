COLLOQUY_EXPORT
@interface JVNotificationController : NSObject <NSUserNotificationCenterDelegate> {
	NSMutableDictionary *_bubbles;
	NSMutableDictionary *_sounds;
	BOOL _useGrowl;
}
+ (JVNotificationController *) defaultController;
- (void) performNotification:(NSString *) identifier withContextInfo:(NSDictionary *) context;
@end

@interface NSObject (MVChatPluginNotificationSupport)
- (void) performNotification:(NSString *) identifier withContextInfo:(NSDictionary *) context andPreferences:(NSDictionary *) preferences;
@end
