#import <AppKit/NSScroller.h>

@class NSMutableSet;
@class NSSet;

@interface JVMarkedScroller : NSScroller {
	NSMutableSet *_marks;
	NSBezierPath *_lines;
}
- (void) addMarkAt:(unsigned int) location;
- (void) removeMarkAt:(unsigned int) location;
- (void) removeAllMarks;

- (void) setMarks:(NSSet *) marks;
- (NSSet *) marks;
@end
