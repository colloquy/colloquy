#import "JVMarkedScroller.h"

@implementation JVMarkedScroller
- (id) initWithFrame:(NSRect) frame {
	if( ( self = [super initWithFrame:frame] ) ) {
		_marks = [[NSMutableSet set] retain];
		_shades = [[NSMutableArray array] retain];
		_nearestPreviousMark = NSNotFound;
		_nearestNextMark = NSNotFound;
		_currentMark = NSNotFound;
	}
	return self;
}

- (void) dealloc {
	[_marks release];
	[_shades release];

	_marks = nil;
	_shades = nil;

	[super dealloc];
}

#pragma mark -

- (void) drawRect:(NSRect) rect {
	[super drawRect:rect];

	NSAffineTransform *transform = [NSAffineTransform transform];
	float width = [[self class] scrollerWidthForControlSize:[self controlSize]];

	float scale = NSHeight( [self rectForPart:NSScrollerKnobSlot] ) / ( NSHeight( [self frame] ) / [self knobProportion] );
	[transform scaleXBy:( sFlags.isHoriz ? scale : 1. ) yBy:( sFlags.isHoriz ? 1. : scale )];

	float offset = [self rectForPart:NSScrollerKnobSlot].origin.y;
	[transform translateXBy:( sFlags.isHoriz ? offset / scale : 0. ) yBy:( sFlags.isHoriz ? 0. : offset / scale )];

	NSRectClip( NSInsetRect( [self rectForPart:NSScrollerKnobSlot], ( sFlags.isHoriz ? 0. : 3. ), ( sFlags.isHoriz ? 3. : 0. ) ) );

	NSBezierPath *shades = [NSBezierPath bezierPath];
	NSEnumerator *enumerator = [_shades objectEnumerator];
	NSNumber *startNum = nil;
	NSNumber *stopNum = nil;

	while( ( startNum = [enumerator nextObject] ) && ( stopNum = [enumerator nextObject] ) ) {
		unsigned long long start = [startNum unsignedLongLongValue];
		unsigned long long stop = [stopNum unsignedLongLongValue];

		NSRect rect = NSZeroRect;
		if( sFlags.isHoriz ) rect = NSMakeRect( start, 0., ( stop - start ), width );
		else rect = NSMakeRect( 0., start, width, ( stop - start ) );

		rect.origin = [transform transformPoint:rect.origin];
		rect.size = [transform transformSize:rect.size];

		[shades appendBezierPathWithRect:rect];
	}

	if( ( [_shades count] % 2 ) == 1 ) {
		NSRect rect = NSZeroRect;
		unsigned long long start = [[_shades lastObject] unsignedLongLongValue];
		unsigned long long stop = ( NSHeight( [self frame] ) / [self knobProportion] );

		if( sFlags.isHoriz ) rect = NSMakeRect( start, 0., ( stop - start ), width );
		else rect = NSMakeRect( 0., start, width, ( stop - start ) );

		rect.origin = [transform transformPoint:rect.origin];
		rect.size = [transform transformSize:rect.size];

		[shades appendBezierPathWithRect:NSIntegralRect( rect )];
	}

	[[[NSColor knobColor] colorWithAlphaComponent:0.45] set];
	[shades fill];

	NSRectClip( NSInsetRect( [self rectForPart:NSScrollerKnobSlot], ( sFlags.isHoriz ? 4. : 3. ), ( sFlags.isHoriz ? 3. : 4. ) ) );

	NSBezierPath *lines = [NSBezierPath bezierPath];
	enumerator = [_marks objectEnumerator];

	unsigned long long currentPosition = ( _currentMark != NSNotFound ? _currentMark : [self floatValue] * ( NSHeight( [self frame] ) / [self knobProportion] ) );
	BOOL foundNext = NO, foundPrevious = NO;
	NSRect knobRect = [self rectForPart:NSScrollerKnob];

	while( ( startNum = [enumerator nextObject] ) ) {
		unsigned long long value = [startNum unsignedLongLongValue];

		if( value < currentPosition && ( ! foundPrevious || value > _nearestPreviousMark ) ) {
			_nearestPreviousMark = value;
			foundPrevious = YES;
		}

		if( value > currentPosition && ( ! foundNext || value < _nearestNextMark ) ) {
			_nearestNextMark = value;
			foundNext = YES;
		}

		NSPoint point = NSMakePoint( ( sFlags.isHoriz ? value : 0. ), ( sFlags.isHoriz ? 0. : value ) );
		point = [transform transformPoint:point];
		point.x = ( sFlags.isHoriz ? roundf( point.x ) + 0.5 : point.x );
		point.y = ( sFlags.isHoriz ? point.y : roundf( point.y ) + 0.5 );

		if( ! NSPointInRect( point, knobRect ) ) {
			[lines moveToPoint:point];

			point = NSMakePoint( ( sFlags.isHoriz ? 0. : width ), ( sFlags.isHoriz ? width : 0. ) );
			[lines relativeLineToPoint:point];
		}
	}

	if( ! foundPrevious ) _nearestPreviousMark = NSNotFound;
	if( ! foundNext ) _nearestNextMark = NSNotFound;

	[[NSColor selectedKnobColor] set];
	[lines stroke];
}

- (void) setFloatValue:(float) position knobProportion:(float) percent {
	if( ! _jumpingToMark ) _currentMark = NSNotFound;
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

	[menu addItem:[NSMenuItem separatorItem]];

	item = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Jump to Previous Mark", "jump to previous mark contextual menu") action:@selector( jumpToPreviousMark: ) keyEquivalent:@"["] autorelease];
	[item setTarget:self];
	[menu addItem:item];

	item = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Jump to Next Mark", "jump to next mark contextual menu") action:@selector( jumpToNextMark: ) keyEquivalent:@"]"] autorelease];
	[item setTarget:self];
	[menu addItem:item];

	return menu;
}

#pragma mark -

- (IBAction) clearMarksHereLess:(id) sender {
	NSEvent *event = [[NSApplication sharedApplication] currentEvent];
	NSPoint where = [self convertPoint:[event locationInWindow] fromView:nil];
	float scale = NSHeight( [self rectForPart:NSScrollerKnobSlot] ) / ( NSHeight( [self frame] ) / [self knobProportion] );
	[self removeMarksLessThan:( ( sFlags.isHoriz ? where.x : where.y ) / scale )];
}

- (IBAction) clearMarksHereGreater:(id) sender {
	NSEvent *event = [[NSApplication sharedApplication] currentEvent];
	NSPoint where = [self convertPoint:[event locationInWindow] fromView:nil];
	float scale = NSHeight( [self rectForPart:NSScrollerKnobSlot] ) / ( NSHeight( [self frame] ) / [self knobProportion] );
	[self removeMarksGreaterThan:( ( sFlags.isHoriz ? where.x : where.y ) / scale )];
}

#pragma mark -

- (IBAction) jumpToPreviousMark:(id) sender {
	if( _nearestPreviousMark != NSNotFound ) {
		_currentMark = _nearestPreviousMark;
		_jumpingToMark = YES;
		float scale = NSHeight( [self rectForPart:NSScrollerKnobSlot] ) / ( NSHeight( [self frame] ) / [self knobProportion] );
		float shift = ( NSHeight( [self rectForPart:NSScrollerKnob] ) / 2. ) / scale;
		[[(NSScrollView *)[self superview] documentView] scrollPoint:NSMakePoint( 0., _nearestPreviousMark - shift )];
		_jumpingToMark = NO;
	}
}

- (IBAction) jumpToNextMark:(id) sender {
	if( _nearestNextMark != NSNotFound ) {
		_currentMark = _nearestNextMark;
		_jumpingToMark = YES;
		float scale = NSHeight( [self rectForPart:NSScrollerKnobSlot] ) / ( NSHeight( [self frame] ) / [self knobProportion] );
		float shift = ( NSHeight( [self rectForPart:NSScrollerKnob] ) / 2. ) / scale;
		[[(NSScrollView *)[self superview] documentView] scrollPoint:NSMakePoint( 0., _nearestNextMark - shift )];
		_jumpingToMark = NO;
	}
}

#pragma mark -

- (void) shiftMarksAndShadedAreasBy:(long long) displacement {
	BOOL negative = ( displacement >= 0 ? NO : YES );
	NSMutableSet *shiftedMarks = [NSMutableSet set];
	NSNumber *location = nil;

	NSEnumerator *enumerator = [_marks objectEnumerator];
	while( ( location = [enumerator nextObject] ) ) {
		unsigned long long shifted = [location unsignedLongLongValue];
		if( ! ( negative && shifted < ABS( displacement ) ) )
			[shiftedMarks addObject:[NSNumber numberWithUnsignedLongLong:( shifted + displacement )]];
	}

	[_marks setSet:shiftedMarks];

	NSMutableArray *shiftedShades = [NSMutableArray array];
	NSNumber *start = nil;
	NSNumber *stop = nil;

	enumerator = [_shades objectEnumerator];
	while( ( start = [enumerator nextObject] ) && ( ( stop = [enumerator nextObject] ) || YES ) ) {
		unsigned long long shiftedStart = [start unsignedLongLongValue];

		if( stop ) {
			unsigned long long shiftedStop = [stop unsignedLongLongValue];
			if( ! ( negative && shiftedStart < ABS( displacement ) ) && ! ( negative && shiftedStop < ABS( displacement ) ) ) {
				[shiftedShades addObject:[NSNumber numberWithUnsignedLongLong:( shiftedStart + displacement )]];
				[shiftedShades addObject:[NSNumber numberWithUnsignedLongLong:( shiftedStop + displacement )]];
			}
		} else if( ! ( negative && shiftedStart < ABS( displacement ) ) ) {
			[shiftedShades addObject:[NSNumber numberWithUnsignedLongLong:( shiftedStart + displacement )]];
		}
	}

	[_shades setArray:shiftedShades];

	[self setNeedsDisplayInRect:[self rectForPart:NSScrollerKnobSlot]];
}

#pragma mark -

- (void) addMarkAt:(unsigned long long) location {
	[_marks addObject:[NSNumber numberWithUnsignedLongLong:location]];
	[self setNeedsDisplayInRect:[self rectForPart:NSScrollerKnobSlot]];
}

- (void) removeMarkAt:(unsigned long long) location {
	[_marks removeObject:[NSNumber numberWithUnsignedLongLong:location]];
	[self setNeedsDisplayInRect:[self rectForPart:NSScrollerKnobSlot]];
}

- (void) removeMarksGreaterThan:(unsigned long long) location {
	NSEnumerator *enumerator = [[[_marks copy] autorelease] objectEnumerator];
	NSNumber *number = nil;

	while( ( number = [enumerator nextObject] ) )
		if( [number unsignedIntValue] > location )
			[_marks removeObject:number];

	[self setNeedsDisplayInRect:[self rectForPart:NSScrollerKnobSlot]];
}

- (void) removeMarksLessThan:(unsigned long long) location {
	NSEnumerator *enumerator = [[[_marks copy] autorelease] objectEnumerator];
	NSNumber *number = nil;

	while( ( number = [enumerator nextObject] ) )
		if( [number unsignedIntValue] < location )
			[_marks removeObject:number];

	[self setNeedsDisplayInRect:[self rectForPart:NSScrollerKnobSlot]];
}

- (void) removeMarksInRange:(NSRange) range {
	NSEnumerator *enumerator = [[[_marks copy] autorelease] objectEnumerator];
	NSNumber *number = nil;

	while( ( number = [enumerator nextObject] ) )
		if( NSLocationInRange( [number unsignedIntValue], range ) )
			[_marks removeObject:number];

	[self setNeedsDisplayInRect:[self rectForPart:NSScrollerKnobSlot]];
}

- (void) removeAllMarks {
	[_marks removeAllObjects];
	[self setNeedsDisplayInRect:[self rectForPart:NSScrollerKnobSlot]];
}

#pragma mark -

- (void) setMarks:(NSSet *) marks {
	[_marks autorelease];
	_marks = [[NSMutableSet setWithSet:marks] retain];
	[self setNeedsDisplayInRect:[self rectForPart:NSScrollerKnobSlot]];
}

- (NSSet *) marks {
	return [[_marks retain] autorelease];
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
		[_shades addObject:[NSNumber numberWithUnsignedLongLong:location]];
		[self setNeedsDisplayInRect:[self rectForPart:NSScrollerKnobSlot]];
	}
}

#pragma mark -

- (void) removeAllShadedAreas {
	[_shades removeAllObjects];
	[self setNeedsDisplayInRect:[self rectForPart:NSScrollerKnobSlot]];
}
@end