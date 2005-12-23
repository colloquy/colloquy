@interface JVSplitView : NSSplitView {}
- (NSString *) stringWithSavedPosition;
- (void) setPositionFromString:(NSString *) string;

- (void) savePositionUsingName:(NSString *) name;
- (BOOL) setPositionUsingName:(NSString *) name;
@end
