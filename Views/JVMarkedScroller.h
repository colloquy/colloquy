#import <Cocoa/Cocoa.h>

@class JVMark;

@interface JVMarkedScroller : NSScroller {
	NSMutableSet<JVMark*> *_marks;
	NSMutableArray *_shades;
	unsigned long long _nearestPreviousMark;
	unsigned long long _nearestNextMark;
	unsigned long long _currentMark;
	BOOL _jumpingToMark;
}
@property unsigned long long locationOfCurrentMark;

- (IBAction) jumpToPreviousMark:(id) sender;
- (IBAction) jumpToNextMark:(id) sender;
- (void) jumpToMarkWithIdentifier:(NSString *) identifier;

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

@property (copy) NSSet<JVMark*> *marks;

- (void) startShadedAreaAt:(unsigned long long) location;
- (void) stopShadedAreaAt:(unsigned long long) location;

- (void) removeAllShadedAreas;

@property (readonly) unsigned long long contentViewLength;
@property (readonly) CGFloat scaleToContentView;
@property (readonly) CGFloat shiftAmountToCenterAlign;
@end
