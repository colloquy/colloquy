#import <AppKit/NSScroller.h>

@class NSMutableSet;
@class NSSet;

@interface JVMarkedScroller : NSScroller {
	NSMutableSet *_marks;
	NSMutableArray *_shades;
	NSBezierPath *_lines;
	NSBezierPath *_shadedAreas;
}
- (void) addMarkAt:(unsigned long long) location;
- (void) removeMarkAt:(unsigned long long) location;
- (void) removeAllMarks;

- (void) setMarks:(NSSet *) marks;
- (NSSet *) marks;

- (void) startShadedAreaAt:(unsigned long long) location;
- (void) stopShadedAreaAt:(unsigned long long) location;

- (void) removeAllShadedAreas;
@end
