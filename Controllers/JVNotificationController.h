#import "KABubbleWindowController.h"

@interface JVNotificationController : NSObject <NSUserNotificationCenterDelegate, KABubbleWindowControllerDelegate> {
	NSMutableDictionary *_bubbles;
	NSMutableDictionary *_sounds;
	BOOL _useGrowl;
}
+ (JVNotificationController *) defaultController;
#if __has_feature(objc_class_property)
@property (readonly, strong, class) JVNotificationController *defaultController;
#endif
- (void) performNotification:(NSString *) identifier withContextInfo:(NSDictionary *) context;
@end

@protocol MVChatPluginNotificationSupport <NSObject>
- (void) performNotification:(NSString *) identifier withContextInfo:(NSDictionary *) context andPreferences:(NSDictionary *) preferences;
@end
