#import <AppKit/NSScroller.h>

@class NSMutableSet;
@class NSSet;

@interface JVMarkedScroller : NSScroller {
	NSMutableSet *_marks;
	NSMutableArray *_shades;
	NSBezierPath *_lines;
	NSBezierPath *_shadedAreas;
}
- (void) shiftMarksAndShadedAreasBy:(unsigned long) displacement;

- (void) addMarkAt:(unsigned long long) location;
- (void) removeMarkAt:(unsigned long long) location;
- (void) removeMarksGreaterThan:(unsigned long long) location;
- (void) removeMarksLessThan:(unsigned long long) location;
- (void) removeMarksInRange:(NSRange) range;
- (void) removeAllMarks;

- (void) setMarks:(NSSet *) marks;
- (NSSet *) marks;

- (void) startShadedAreaAt:(unsigned long long) location;
- (void) stopShadedAreaAt:(unsigned long long) location;

- (void) removeAllShadedAreas;
@end
