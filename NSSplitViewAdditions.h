@interface NSSplitView (NSSplitViewAdditions)
- (NSString *) stringWithSavedPosition;
- (void) setPositionFromString:(NSString *) string;

- (void) savePositionUsingName:(NSString *) name;
- (BOOL) setPositionUsingName:(NSString *) name;
@end
