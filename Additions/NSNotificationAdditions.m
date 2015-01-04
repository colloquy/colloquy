#import "NSNotificationAdditions.h"
#import <pthread.h>

@implementation NSNotificationCenter (NSNotificationCenterAdditions)
- (void) postNotificationOnMainThread:(NSNotification *) notification {
	if( pthread_main_np() ) [self postNotification:notification];
	else [self postNotificationOnMainThread:notification waitUntilDone:NO];
}

- (void) postNotificationOnMainThread:(NSNotification *) notification waitUntilDone:(BOOL) wait {
	if( pthread_main_np() ) [self postNotification:notification];
	else [[self class] performSelectorOnMainThread:@selector( _postNotification: ) withObject:notification waitUntilDone:wait];
}

+ (void) _postNotification:(NSNotification *) notification {
	[[self defaultCenter] postNotification:notification];
}

- (void) postNotificationOnMainThreadWithName:(NSString *) name object:(id) object {
	if( pthread_main_np() ) [self postNotificationName:name object:object userInfo:nil];
	else [self postNotificationOnMainThreadWithName:name object:object userInfo:nil waitUntilDone:NO];
}

- (void) postNotificationOnMainThreadWithName:(NSString *) name object:(id) object userInfo:(NSDictionary *) userInfo {
	if( pthread_main_np() ) [self postNotificationName:name object:object userInfo:userInfo];
	else [self postNotificationOnMainThreadWithName:name object:object userInfo:userInfo waitUntilDone:NO];
}

- (void) postNotificationOnMainThreadWithName:(NSString *) name object:(id) object userInfo:(NSDictionary *) userInfo waitUntilDone:(BOOL) wait {
	if( pthread_main_np() ) [self postNotificationName:name object:object userInfo:userInfo];
	else {
		NSMutableDictionary *info = [[NSMutableDictionary alloc] initWithCapacity:3];
		if( name ) info[@"name"] = name;
		else return;

		if( object ) info[@"object"] = object;
		if( userInfo ) info[@"userInfo"] = userInfo;

		[[self class] performSelectorOnMainThread:@selector( _postNotificationName: ) withObject:info waitUntilDone:wait];
	}
}

+ (void) _postNotificationName:(NSDictionary *) info {
	NSString *name = info[@"name"];
	id object = info[@"object"];
	NSDictionary *userInfo = info[@"userInfo"];

	[[self defaultCenter] postNotificationName:name object:object userInfo:userInfo];
}
@end
