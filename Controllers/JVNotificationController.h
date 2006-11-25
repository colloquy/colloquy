@interface JVNotificationController : NSObject {
	NSMutableDictionary *_bubbles;
	NSMutableDictionary *_sounds;
}
+ (JVNotificationController *) defaultController;
- (void) performNotification:(NSString *) identifier withContextInfo:(NSDictionary *) context;
@end

@interface NSObject (MVChatPluginNotificationSupport)
- (void) performNotification:(NSString *) identifier withContextInfo:(NSDictionary *) context andPreferences:(NSDictionary *) preferences;
@end
