#import "KABubbleWindowController.h"

@interface JVNotificationController : NSObject <NSUserNotificationCenterDelegate, KABubbleWindowControllerDelegate> {
	NSMutableDictionary *_bubbles;
	NSMutableDictionary *_sounds;
	BOOL _useGrowl;
}
+ (JVNotificationController *) defaultController;
- (void) performNotification:(NSString *) identifier withContextInfo:(NSDictionary *) context;
@end

@protocol MVChatPluginNotificationSupport <NSObject>
- (void) performNotification:(NSString *) identifier withContextInfo:(NSDictionary *) context andPreferences:(NSDictionary *) preferences;
@end
