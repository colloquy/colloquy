#import "KABubbleWindowController.h"

NS_ASSUME_NONNULL_BEGIN

COLLOQUY_EXPORT
@interface JVNotificationController : NSObject <NSUserNotificationCenterDelegate, KABubbleWindowControllerDelegate> {
	NSMutableDictionary *_bubbles;
	NSMutableDictionary *_sounds;
	BOOL _useGrowl;
}
#if __has_feature(objc_class_property)
@property (readonly, strong, class) JVNotificationController *defaultController;
#else
+ (JVNotificationController *) defaultController;
#endif
- (void) performNotification:(NSString *) identifier withContextInfo:(nullable NSDictionary<NSString*,id> *) context;
@end

@protocol MVChatPluginNotificationSupport <MVChatPlugin>
- (void) performNotification:(NSString *) identifier withContextInfo:(nullable NSDictionary<NSString*,id> *) context andPreferences:(nullable NSDictionary<NSString*,id> *) preferences;
@end

NS_ASSUME_NONNULL_END
