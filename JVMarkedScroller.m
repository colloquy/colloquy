#import <Cocoa/Cocoa.h>
#import "JVMarkedScroller.h"

@implementation JVMarkedScroller
- (id) initWithFrame:(NSRect) frame {
	if( ( self = [super initWithFrame:frame] ) ) {
		_marks = [[NSMutableSet set] retain];
		_lines = [[NSBezierPath bezierPath] retain];
		[_lines setLineWidth:1.5];
	}
	return self;
}

- (void) dealloc {
	[_marks release];
	[_lines release];

	_marks = nil;
	_lines = nil;

	[super dealloc];
}

- (void) drawRect:(NSRect) rect {
	[super drawRect:rect];

	if( [_lines isEmpty] ) return;

	NSAffineTransform *transform = [NSAffineTransform transform];

	float scale = [self knobProportion];
	[transform scaleXBy:( sFlags.isHoriz ? scale : 1. ) yBy:( sFlags.isHoriz ? 1. : scale )];

	float offset = [self rectForPart:NSScrollerKnobSlot].origin.y + 6.;
	[transform translateXBy:( sFlags.isHoriz ? offset / scale : 0. ) yBy:( sFlags.isHoriz ? 0. : offset / scale )];

	[[NSBezierPath bezierPathWithRect:NSInsetRect( [self rectForPart:NSScrollerKnobSlot], ( sFlags.isHoriz ? 4. : 0. ), ( sFlags.isHoriz ? 0. : 4. ) )] setClip];

	[[NSColor selectedKnobColor] set];
	[[transform transformBezierPath:_lines] stroke];

	[self drawKnob];
}

- (void) setFloatValue:(float) position knobProportion:(float) percent {
	[self setNeedsDisplayInRect:[self visibleRect]];
	[super setFloatValue:position knobProportion:percent];
}

- (void) rebuildLines {
	NSEnumerator *enumerator = [_marks objectEnumerator];
	NSNumber *location = nil;

	[_lines removeAllPoints];

	while( ( location = [enumerator nextObject] ) ) {
		float l = [location floatValue];
		[_lines moveToPoint:NSMakePoint( ( sFlags.isHoriz ? l : 3. ), ( sFlags.isHoriz ? 3. : l ) )];
		[_lines relativeLineToPoint:NSMakePoint( ( sFlags.isHoriz ? 0. : 8. ), ( sFlags.isHoriz ? 8. : 0. ) )];
	}
}

- (void) addMarkAt:(unsigned int) location {
	[_marks addObject:[NSNumber numberWithUnsignedInt:location]];
	[_lines moveToPoint:NSMakePoint( ( sFlags.isHoriz ? location : 3. ), ( sFlags.isHoriz ? 3. : location ) )];
	[_lines relativeLineToPoint:NSMakePoint( ( sFlags.isHoriz ? 0. : 8. ), ( sFlags.isHoriz ? 8. : 0. ) )];
	[self setNeedsDisplay:YES];
}

- (void) removeMarkAt:(unsigned int) location {
	[_marks removeObject:[NSNumber numberWithUnsignedInt:location]];
	[self rebuildLines];
	[self setNeedsDisplay:YES];
}

- (void) removeAllMarks {
	[_marks removeAllObjects];
	[_lines removeAllPoints];
	[self setNeedsDisplay:YES];
}

- (void) setMarks:(NSSet *) marks {
	[_marks autorelease];
	_marks = [marks mutableCopy];
	[self rebuildLines];
}

- (NSSet *) marks {
	return [[_marks retain] autorelease];
}
@end