#import <Foundation/NSObject.h>

@class NSLock;

@interface JVNotificationController : NSObject {}
+ (JVNotificationController *) defaultManager;
- (void) performNotification:(NSString *) identifier withContextInfo:(NSDictionary *) context;
@end
