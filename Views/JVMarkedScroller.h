@interface JVMarkedScroller : NSScroller
- (void) setLocationOfCurrentMark:(unsigned long long) location;
- (unsigned long long) locationOfCurrentMark;

- (unsigned long long) locationOfPreviousMark;
- (unsigned long long) locationOfNextMark;
- (unsigned long long) locationOfMarkWithIdentifier:(NSString *) identifier;

- (void) shiftMarksAndShadedAreasBy:(long long) displacement;

- (void) addMarkAt:(unsigned long long) location;
- (void) addMarkAt:(unsigned long long) location withIdentifier:(NSString *) identifier;
- (void) addMarkAt:(unsigned long long) location withColor:(NSColor *) color;
- (void) addMarkAt:(unsigned long long) location withIdentifier:(NSString *) identifier withColor:(NSColor *) color;
- (void) removeMarkAt:(unsigned long long) location;
- (void) removeMarkAt:(unsigned long long) location withIdentifier:(NSString *) identifier;
- (void) removeMarkAt:(unsigned long long) location withColor:(NSColor *) color;
- (void) removeMarkAt:(unsigned long long) location withIdentifier:(NSString *) identifier withColor:(NSColor *) color;
- (void) removeMarkWithIdentifier:(NSString *) identifier;
- (void) removeMarksGreaterThan:(unsigned long long) location;
- (void) removeMarksLessThan:(unsigned long long) location;
- (void) removeMarksInRange:(NSRange) range;
- (void) removeAllMarks;

- (void) setMarks:(NSSet *) marks;
- (NSSet *) marks;

- (void) startShadedAreaAt:(unsigned long long) location;
- (void) stopShadedAreaAt:(unsigned long long) location;

- (void) removeAllShadedAreas;

- (unsigned long long) contentViewLength;
- (float) scaleToContentView;
- (long) shiftAmountToCenterAlign;
@end