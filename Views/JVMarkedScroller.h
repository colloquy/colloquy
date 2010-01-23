
@interface JVMarkedScroller : NSScroller {
	NSMutableSet *_marks;
	NSMutableArray *_shades;
	long long _nearestPreviousMark;
	long long _nearestNextMark;
	long long _currentMark;
	BOOL _jumpingToMark;
}
- (void) setLocationOfCurrentMark:(long long) location;
- (long long) locationOfCurrentMark;

- (IBAction) jumpToPreviousMark:(id) sender;
- (IBAction) jumpToNextMark:(id) sender;
- (void) jumpToMarkWithIdentifier:(NSString *) identifier;

- (void) shiftMarksAndShadedAreasBy:(long long) displacement;

- (void) addMarkAt:(long long) location;
- (void) addMarkAt:(long long) location withIdentifier:(NSString *) identifier;
- (void) addMarkAt:(long long) location withColor:(NSColor *) color;
- (void) addMarkAt:(long long) location withIdentifier:(NSString *) identifier withColor:(NSColor *) color;

- (void) removeMarkAt:(long long) location;
- (void) removeMarkAt:(long long) location withIdentifier:(NSString *) identifier;
- (void) removeMarkAt:(long long) location withColor:(NSColor *) color;
- (void) removeMarkAt:(long long) location withIdentifier:(NSString *) identifier withColor:(NSColor *) color;
- (void) removeMarkWithIdentifier:(NSString *) identifier;
- (void) removeMarksGreaterThan:(long long) location;
- (void) removeMarksLessThan:(long long) location;
- (void) removeMarksInRange:(NSRange) range;
- (void) removeAllMarks;

- (void) setMarks:(NSSet *) marks;
- (NSSet *) marks;

- (void) startShadedAreaAt:(long long) location;
- (void) stopShadedAreaAt:(long long) location;

- (void) removeAllShadedAreas;

- (long long) contentViewLength;
- (CGFloat) scaleToContentView;
- (CGFloat) shiftAmountToCenterAlign;
@end
