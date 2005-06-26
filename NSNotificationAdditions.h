@interface NSNotificationCenter (NSNotificationCenterAdditions)
- (void) postNotificationOnMainThread:(NSNotification *) notification;
- (void) postNotificationOnMainThread:(NSNotification *) notification waitUntilDone:(BOOL) wait;
@end

@interface NSNotificationQueue (NSNotificationQueueAdditions)
- (void) enqueueNotificationOnMainThread:(NSNotification *) notification postingStyle:(NSPostingStyle) postingStyle;
- (void) enqueueNotificationOnMainThread:(NSNotification *) notification postingStyle:(NSPostingStyle) postingStyle coalesceMask:(unsigned) coalesceMask forModes:(NSArray *) modes;
@end
