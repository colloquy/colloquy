#import <Cocoa/Cocoa.h>
#import "JVMarkedScroller.h"

@implementation JVMarkedScroller
- (id) initWithFrame:(NSRect) frame {
	if( ( self = [super initWithFrame:frame] ) ) {
		_marks = [[NSMutableSet set] retain];
		_shades = [[NSMutableArray array] retain];

		_lines = [[NSBezierPath bezierPath] retain];
		[_lines setLineWidth:1.];

		_shadedAreas = [[NSBezierPath bezierPath] retain];
	}
	return self;
}

- (void) dealloc {
	[_marks release];
	[_shades release];
	[_lines release];
	[_shadedAreas release];

	_marks = nil;
	_shades = nil;
	_lines = nil;
	_shadedAreas = nil;

	[super dealloc];
}

- (void) drawRect:(NSRect) rect {
	NSEraseRect( rect );
	[super drawRect:rect];

	NSAffineTransform *transform = [NSAffineTransform transform];

	NSRect clip = NSInsetRect( [self rectForPart:NSScrollerKnobSlot], ( sFlags.isHoriz ? 6. : 0. ), ( sFlags.isHoriz ? 0. : 6. ) );
	float scale = NSHeight( clip ) / ( NSHeight( [self frame] ) / [self knobProportion] );
	[transform scaleXBy:( sFlags.isHoriz ? scale : 1. ) yBy:( sFlags.isHoriz ? 1. : scale )];

	float offset = [self rectForPart:NSScrollerKnobSlot].origin.y + 6.;
	[transform translateXBy:( sFlags.isHoriz ? offset / scale : 0. ) yBy:( sFlags.isHoriz ? 0. : offset / scale )];

	clip = NSInsetRect( [self rectForPart:NSScrollerKnobSlot], ( sFlags.isHoriz ? 0. : 3. ), ( sFlags.isHoriz ? 3. : 0. ) );
	NSRectClip( clip );

	NSBezierPath *shaded = _shadedAreas;
	if( ( [_shades count] % 2 ) == 1 ) {
		shaded = [[_shadedAreas copy] autorelease];

		unsigned long long start = [[_shades lastObject] unsignedLongLongValue];
		unsigned long long stop = ( NSHeight( [self frame] ) / [self knobProportion] );
		float width = [[self class] scrollerWidthForControlSize:[self controlSize]];
		NSRect rect = NSZeroRect;

		if( sFlags.isHoriz ) rect = NSMakeRect( start, 0., ( stop - start ), width );
		else rect = NSMakeRect( 0., start, width, ( stop - start ) );
		[shaded appendBezierPathWithRect:rect];
	}

	[[[NSColor knobColor] colorWithAlphaComponent:0.45] set];
	[[transform transformBezierPath:shaded] fill];

	clip = NSInsetRect( [self rectForPart:NSScrollerKnobSlot], ( sFlags.isHoriz ? 4. : 3. ), ( sFlags.isHoriz ? 3. : 4. ) );
	NSRectClip( clip );

	[[NSColor selectedKnobColor] set];
	[[transform transformBezierPath:_lines] stroke];

	[self drawKnob];
}

- (void) setFloatValue:(float) position knobProportion:(float) percent {
	[self setNeedsDisplayInRect:[self rectForPart:NSScrollerKnobSlot]];
	[super setFloatValue:position knobProportion:percent];
}

- (NSMenu *) menuForEvent:(NSEvent *) event {
	NSMenu *menu = [[[NSMenu alloc] initWithTitle:@""] autorelease];
	NSMenuItem *item = nil;

	item = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Clear All Marks", "clear all marks contextual menu item title" ) action:@selector( removeAllMarks ) keyEquivalent:@""] autorelease];
	[item setTarget:self];
	[menu addItem:item];

	if( sFlags.isHoriz ) {
		item = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Clear Marks from Here Left", "clear marks from here left contextual menu") action:@selector( clearMarksHereLess: ) keyEquivalent:@""] autorelease];
		[item setTarget:self];
		[menu addItem:item];
		
		item = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Clear Marks from Here Right", "clear marks from here right contextual menu") action:@selector( clearMarksHereGreater: ) keyEquivalent:@""] autorelease];
		[item setTarget:self];
		[menu addItem:item];
	} else {
		item = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Clear Marks from Here Up", "clear marks from here up contextual menu") action:@selector( clearMarksHereLess: ) keyEquivalent:@""] autorelease];
		[item setTarget:self];
		[menu addItem:item];
		
		item = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Clear Marks from Here Down", "clear marks from here up contextual menu") action:@selector( clearMarksHereGreater: ) keyEquivalent:@""] autorelease];
		[item setTarget:self];
		[menu addItem:item];
	}

	return menu;
}

- (IBAction) clearMarksHereLess:(id) sender {
	NSEvent *event = [[NSApplication sharedApplication] currentEvent];
	NSPoint where = [self convertPoint:[event locationInWindow] fromView:nil];
	NSRect clip = NSInsetRect( [self rectForPart:NSScrollerKnobSlot], ( sFlags.isHoriz ? 6. : 0. ), ( sFlags.isHoriz ? 0. : 6. ) );
	float scale = NSHeight( clip ) / ( NSHeight( [self frame] ) / [self knobProportion] );
	[self removeMarksLessThan:( ( sFlags.isHoriz ? where.x : where.y ) / scale )];
}

- (IBAction) clearMarksHereGreater:(id) sender {
	NSEvent *event = [[NSApplication sharedApplication] currentEvent];
	NSPoint where = [self convertPoint:[event locationInWindow] fromView:nil];
	NSRect clip = NSInsetRect( [self rectForPart:NSScrollerKnobSlot], ( sFlags.isHoriz ? 6. : 0. ), ( sFlags.isHoriz ? 0. : 6. ) );
	float scale = NSHeight( clip ) / ( NSHeight( [self frame] ) / [self knobProportion] );
	[self removeMarksGreaterThan:( ( sFlags.isHoriz ? where.x : where.y ) / scale )];
}

#pragma mark -

- (void) shiftMarksAndShadedAreasBy:(long long) displacement {
	NSAffineTransform *transform = [NSAffineTransform transform];
	[transform translateXBy:(float)( sFlags.isHoriz ? displacement : 0. ) yBy:(float)( sFlags.isHoriz ? 0. : displacement )];

	[_lines transformUsingAffineTransform:transform];
	[_shadedAreas transformUsingAffineTransform:transform];

	NSMutableSet *shiftedMarks = [NSMutableSet set];
	NSEnumerator *enumerator = [_marks objectEnumerator];
	NSNumber *location = nil;

	while( ( location = [enumerator nextObject] ) ) {
		long long shifted = ( [location unsignedLongLongValue] + displacement );
		if( shifted >= 0. ) [shiftedMarks addObject:[NSNumber numberWithUnsignedLongLong:shifted]];
	}

	[_marks setSet:shiftedMarks];

	NSMutableArray *shiftedShades = [NSMutableArray array];
	enumerator = [_shades objectEnumerator];
	location = nil;

	while( ( location = [enumerator nextObject] ) ) {
		long long shifted = ( [location unsignedLongLongValue] + displacement );
		[shiftedShades addObject:[NSNumber numberWithUnsignedLongLong:shifted]];
	}

	[_shades setArray:shiftedShades];

	[self setNeedsDisplayInRect:[self rectForPart:NSScrollerKnobSlot]];
}

#pragma mark -

- (void) buildLineAtLocation:(unsigned long long) location {
	float width = [[self class] scrollerWidthForControlSize:[self controlSize]];
	[_lines moveToPoint:NSMakePoint( ( sFlags.isHoriz ? location : 0. ), ( sFlags.isHoriz ? 0. : location ) )];
	[_lines relativeLineToPoint:NSMakePoint( ( sFlags.isHoriz ? 0. : width ), ( sFlags.isHoriz ? width : 0. ) )];
}

- (void) rebuildLines {
	NSEnumerator *enumerator = [_marks objectEnumerator];
	NSNumber *location = nil;

	[_lines removeAllPoints];

	while( ( location = [enumerator nextObject] ) )
		[self buildLineAtLocation:[location unsignedLongLongValue]];
}

#pragma mark -

- (void) addMarkAt:(unsigned long long) location {
	[_marks addObject:[NSNumber numberWithUnsignedLongLong:location]];
	[self buildLineAtLocation:location];
	[self setNeedsDisplayInRect:[self rectForPart:NSScrollerKnobSlot]];
}

- (void) removeMarkAt:(unsigned long long) location {
	[_marks removeObject:[NSNumber numberWithUnsignedLongLong:location]];
	[self rebuildLines];
	[self setNeedsDisplayInRect:[self rectForPart:NSScrollerKnobSlot]];
}

- (void) removeMarksGreaterThan:(unsigned long long) location {
	NSEnumerator *enumerator = [[[_marks copy] autorelease] objectEnumerator];
	NSNumber *number = nil;

	while( ( number = [enumerator nextObject] ) )
		if( [number unsignedIntValue] > location )
			[_marks removeObject:number];

	[self rebuildLines];
	[self setNeedsDisplayInRect:[self rectForPart:NSScrollerKnobSlot]];
}

- (void) removeMarksLessThan:(unsigned long long) location {
	NSEnumerator *enumerator = [[[_marks copy] autorelease] objectEnumerator];
	NSNumber *number = nil;

	while( ( number = [enumerator nextObject] ) )
		if( [number unsignedIntValue] < location )
			[_marks removeObject:number];

	[self rebuildLines];
	[self setNeedsDisplayInRect:[self rectForPart:NSScrollerKnobSlot]];
}

- (void) removeMarksInRange:(NSRange) range {
	NSEnumerator *enumerator = [[[_marks copy] autorelease] objectEnumerator];
	NSNumber *number = nil;

	while( ( number = [enumerator nextObject] ) )
		if( NSLocationInRange( [number unsignedIntValue], range ) )
			[_marks removeObject:number];

	[self rebuildLines];
	[self setNeedsDisplayInRect:[self rectForPart:NSScrollerKnobSlot]];
}

- (void) removeAllMarks {
	[_marks removeAllObjects];
	[_lines removeAllPoints];
	[self setNeedsDisplayInRect:[self rectForPart:NSScrollerKnobSlot]];
}

#pragma mark -

- (void) setMarks:(NSSet *) marks {
	[_marks autorelease];
	_marks = [[NSMutableSet setWithSet:marks] retain];
	[self rebuildLines];
}

- (NSSet *) marks {
	return [[_marks retain] autorelease];
}

#pragma mark -

- (void) buildShadedAreaBetween:(unsigned long long) start and:(unsigned long long) stop {
	NSRect rect = NSZeroRect;
	float width = [[self class] scrollerWidthForControlSize:[self controlSize]];
	if( sFlags.isHoriz ) rect = NSMakeRect( start, 0., ( stop - start ), width );
	else rect = NSMakeRect( 0., start, width, ( stop - start ) );
	[_shadedAreas appendBezierPathWithRect:rect];
}

- (void) rebuildShadedAreas {
	NSEnumerator *enumerator = [_marks objectEnumerator];
	NSNumber *start = nil;
	NSNumber *stop = nil;

	[_shadedAreas removeAllPoints];

	while( ( start = [enumerator nextObject] ) && ( stop = [enumerator nextObject] ) )
		[self buildShadedAreaBetween:[start unsignedLongLongValue] and:[stop unsignedLongLongValue]];
}

#pragma mark -

- (void) startShadedAreaAt:(unsigned long long) location {
	if( ! [_shades count] || ! ( [_shades count] % 2 ) ) {
		[_shades addObject:[NSNumber numberWithUnsignedLongLong:location]];
		[self setNeedsDisplayInRect:[self rectForPart:NSScrollerKnobSlot]];
	}
}

- (void) stopShadedAreaAt:(unsigned long long) location {
	if( [_shades count] && ( [_shades count] % 2 ) == 1 ) {
		NSNumber *start = [_shades lastObject];
		[_shades addObject:[NSNumber numberWithUnsignedLongLong:location]];
		[self buildShadedAreaBetween:[start unsignedLongLongValue] and:location];
		[self setNeedsDisplayInRect:[self rectForPart:NSScrollerKnobSlot]];
	}
}

#pragma mark -

- (void) removeAllShadedAreas {
	[_shades removeAllObjects];
	[_shadedAreas removeAllPoints];
	[self setNeedsDisplayInRect:[self rectForPart:NSScrollerKnobSlot]];
}
@end