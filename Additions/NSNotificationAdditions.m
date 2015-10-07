#import "NSNotificationAdditions.h"
#import <pthread.h>

NS_ASSUME_NONNULL_BEGIN

@implementation NSNotificationCenter (NSNotificationCenterAdditions)
+ (NSNotificationCenter *) chatCenter {
#if ENABLE(CHAT_CENTER)
	static NSNotificationCenter *chatCenter = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		chatCenter = [[NSNotificationCenter alloc] init];
	});
	return chatCenter;
#else
	return [NSNotificationCenter defaultCenter];
#endif
}
- (void) postNotificationOnMainThread:(NSNotification *) notification {
	if( pthread_main_np() ) [self postNotification:notification];
	else [self postNotificationOnMainThread:notification waitUntilDone:NO];
}

- (void) postNotificationOnMainThread:(NSNotification *) notification waitUntilDone:(BOOL) wait {
	if( pthread_main_np() ) [self postNotification:notification];
	else [[self class] performSelectorOnMainThread:@selector( _postNotification: ) withObject:@{ @"notification": notification, @"center": self } waitUntilDone:wait];
}

+ (void) _postNotification:(NSDictionary *) info {
	[info[@"center"] postNotification:info[@"notification"]];
}

- (void) postNotificationOnMainThreadWithName:(NSString *) name object:(id __nullable) object {
	if( pthread_main_np() ) [self postNotificationName:name object:object userInfo:nil];
	else [self postNotificationOnMainThreadWithName:name object:object userInfo:@{} waitUntilDone:NO];
}

- (void) postNotificationOnMainThreadWithName:(NSString *) name object:(id __nullable) object userInfo:(NSDictionary  * __nullable ) userInfo {
	if( pthread_main_np() ) [self postNotificationName:name object:object userInfo:userInfo];
	else [self postNotificationOnMainThreadWithName:name object:object userInfo:userInfo waitUntilDone:NO];
}

- (void) postNotificationOnMainThreadWithName:(NSString *) name object:(id __nullable) object userInfo:(NSDictionary  * __nullable ) userInfo waitUntilDone:(BOOL) wait {
	if( pthread_main_np() ) [self postNotificationName:name object:object userInfo:userInfo];
	else {
		if ( !name ) return;
		NSMutableDictionary *info = [[NSMutableDictionary alloc] initWithCapacity:3];
		info[@"name"] = name;

		if( object ) info[@"object"] = object;
		if( userInfo ) info[@"userInfo"] = userInfo;
		info[@"center"] = self;

		[[self class] performSelectorOnMainThread:@selector( _postNotificationName: ) withObject:info waitUntilDone:wait];
	}
}

+ (void) _postNotificationName:(NSDictionary *) info {
	[info[@"center"] postNotificationName:info[@"name"] object:info[@"object"] userInfo:info[@"userInfo"]];
}
@end

NS_ASSUME_NONNULL_END
