@interface NSNotificationCenter (NSNotificationAdditions)
- (void) postNotificationOnMainThread:(NSNotification *) notification;
- (void) postNotificationOnMainThread:(NSNotification *) notification waitUntilDone:(BOOL) wait;
@end

@interface NSNotificationQueue (NSNotificationAdditions)
- (void) enqueueNotificationOnMainThread:(NSNotification *) notification postingStyle:(NSPostingStyle) postingStyle;
- (void) enqueueNotificationOnMainThread:(NSNotification *) notification postingStyle:(NSPostingStyle) postingStyle coalesceMask:(unsigned) coalesceMask forModes:(NSArray *) modes;
@end
