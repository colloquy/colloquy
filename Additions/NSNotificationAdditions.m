#import "NSNotificationAdditions.h"
#import <pthread.h>

@implementation NSNotificationCenter (NSNotificationCenterAdditions)
- (void) postNotificationOnMainThread:(NSNotification *) notification {
	if( pthread_main_np() ) return [self postNotification:notification];
	[self postNotificationOnMainThread:notification waitUntilDone:NO];
}

- (void) postNotificationOnMainThread:(NSNotification *) notification waitUntilDone:(BOOL) wait {
	if( pthread_main_np() ) return [self postNotification:notification];
	[self performSelectorOnMainThread:@selector( postNotification: ) withObject:notification waitUntilDone:wait];
}

- (void) postNotificationOnMainThreadWithName:(NSString *) name object:(id) object {
	if( pthread_main_np() ) return [self postNotificationName:name object:object];
	[self postNotificationOnMainThreadWithName:name object:object userInfo:nil waitUntilDone:NO];
}

- (void) postNotificationOnMainThreadWithName:(NSString *) name object:(id) object userInfo:(NSDictionary *) userInfo {
	if( pthread_main_np() ) return [self postNotificationName:name object:object userInfo:userInfo];
	[self postNotificationOnMainThreadWithName:name object:object userInfo:nil waitUntilDone:NO];
}

- (void) postNotificationOnMainThreadWithName:(NSString *) name object:(id) object userInfo:(NSDictionary *) userInfo waitUntilDone:(BOOL) wait {
	if( pthread_main_np() ) return [self postNotificationName:name object:object userInfo:userInfo];

	NSMutableDictionary *info = [[NSMutableDictionary allocWithZone:nil] init];
	[info setObject:name forKey:@"name"];
	if( object ) [info setObject:object forKey:@"object"];
	if( userInfo ) [info setObject:userInfo forKey:@"userInfo"];

	[[self class] performSelectorOnMainThread:@selector( _postNotification: ) withObject:info waitUntilDone:wait];
	[info release];
}

+ (void) _postNotification:(NSDictionary *) info {
	NSString *name = [info objectForKey:@"name"];
	id object = [info objectForKey:@"object"];
	NSDictionary *userInfo = [info objectForKey:@"userInfo"];

	[[self defaultCenter] postNotificationName:name object:object userInfo:userInfo];
}
@end

@implementation NSNotificationQueue (NSNotificationQueueAdditions)
- (void) enqueueNotificationOnMainThread:(NSNotification *) notification postingStyle:(NSPostingStyle) postingStyle {
	if( pthread_main_np() ) return [self enqueueNotification:notification postingStyle:postingStyle];
	[self enqueueNotificationOnMainThread:notification postingStyle:postingStyle coalesceMask:( NSNotificationCoalescingOnName | NSNotificationCoalescingOnSender ) forModes:nil];
}

- (void) enqueueNotificationOnMainThread:(NSNotification *) notification postingStyle:(NSPostingStyle) postingStyle coalesceMask:(unsigned) coalesceMask forModes:(NSArray *) modes {
	if( pthread_main_np() ) return [self enqueueNotification:notification postingStyle:postingStyle coalesceMask:coalesceMask forModes:modes];

	NSMutableDictionary *info = [[NSMutableDictionary allocWithZone:nil] init];
	[info setObject:notification forKey:@"notification"];
	[info setObject:[NSNumber numberWithUnsignedInt:postingStyle] forKey:@"postingStyle"];
	[info setObject:[NSNumber numberWithUnsignedInt:coalesceMask] forKey:@"coalesceMask"];
	if( modes ) [info setObject:modes forKey:@"modes"];

	[[self class] performSelectorOnMainThread:@selector( _enqueueNotification: ) withObject:info waitUntilDone:NO];
	[info release];
}

+ (void) _enqueueNotification:(NSDictionary *) info {
	NSNotification *notification = [info objectForKey:@"notification"];
	NSPostingStyle postingStyle = [[info objectForKey:@"postingStyle"] unsignedIntValue];
	unsigned coalesceMask = [[info objectForKey:@"coalesceMask"] unsignedIntValue];
	NSArray *modes = [info objectForKey:@"modes"];

	[[self defaultQueue] enqueueNotification:notification postingStyle:postingStyle coalesceMask:coalesceMask forModes:modes];
}
@end