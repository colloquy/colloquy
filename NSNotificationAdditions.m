#import "NSNotificationAdditions.h"
#import <Foundation/Foundation.h>

@implementation NSNotificationCenter (NSNotificationAdditions)
- (void) postNotificationOnMainThread:(NSNotification *) notification {
	[self performSelectorOnMainThread:@selector( _postNotification: ) withObject:notification waitUntilDone:YES];
}

- (void) _postNotification:(NSNotification *) notification {
	[self postNotification:notification];
}
@end

@implementation NSNotificationQueue (NSNotificationAdditions)
- (void) enqueueNotificationOnMainThread:(NSNotification *) notification postingStyle:(NSPostingStyle) postingStyle {
	[self enqueueNotificationOnMainThread:notification postingStyle:postingStyle coalesceMask:( NSNotificationCoalescingOnName | NSNotificationCoalescingOnSender ) forModes:nil];
}

- (void) enqueueNotificationOnMainThread:(NSNotification *) notification postingStyle:(NSPostingStyle) postingStyle coalesceMask:(unsigned) coalesceMask forModes:(NSArray *) modes {
	NSMutableDictionary *info = [NSMutableDictionary dictionary];
	[info setObject:notification forKey:@"notification"];
	[info setObject:[NSNumber numberWithUnsignedInt:postingStyle] forKey:@"postingStyle"];
	[info setObject:[NSNumber numberWithUnsignedInt:coalesceMask] forKey:@"coalesceMask"];
	if( modes ) [info setObject:modes forKey:@"modes"];

	[self performSelectorOnMainThread:@selector( _enqueueNotification: ) withObject:info waitUntilDone:YES];
}

- (void) _enqueueNotification:(NSDictionary *) info {
	NSNotification *notification = [info objectForKey:@"notification"];
	NSPostingStyle postingStyle = [[info objectForKey:@"postingStyle"] unsignedIntValue];
	unsigned coalesceMask = [[info objectForKey:@"coalesceMask"] unsignedIntValue];
	NSArray *modes = [info objectForKey:@"modes"];

	[self enqueueNotification:notification postingStyle:postingStyle coalesceMask:coalesceMask forModes:modes];
}
@end