@interface JVSplitView : NSSplitView {
	long _mainSubviewIndex;
}
@property (readonly, copy) NSString *stringWithSavedPosition;
- (void) setPositionFromString:(NSString *) string;

- (void) savePositionUsingName:(NSString *) name;
- (BOOL) setPositionUsingName:(NSString *) name;

- (void) setMainSubviewIndex:(long) index;
- (BOOL) mainSubviewIndex;
@end
