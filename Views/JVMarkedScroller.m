#import "JVMarkedScroller.h"

static NSMapTable *scrollers = NULL;

struct _instanceVars {
	NSMutableSet *marks;
	NSMutableArray *shades;
	unsigned long long nearestPreviousMark;
	unsigned long long nearestNextMark;
	unsigned long long currentMark;
};

struct _mark {
	unsigned long long location;
	NSString *identifier;
	NSColor *color;
};

@implementation JVMarkedScroller
+ (void) initialize {
	static BOOL tooLate = NO;
	if( ! tooLate ) {
		// setup our global NSMapTable to hold our instance variables. This is so we can poseAsClass:
		// no need for the callbacks, we don't want to retain/release anything we add, etc
		NSMapTableKeyCallBacks keyCallbacks = { NULL, NULL, NULL, NULL, NULL, NULL };
		NSMapTableValueCallBacks valueCallbacks = { NULL, NULL, NULL };
		scrollers = NSCreateMapTable( keyCallbacks, valueCallbacks, 100 );
		tooLate = YES;
	}
}

- (id) initWithFrame:(NSRect) frame {
	if( ( self = [super initWithFrame:frame] ) ) {
		struct _instanceVars *vars = malloc( sizeof( struct _instanceVars ) );
		if( ! vars ) {
			[self release];
			return nil;
		}

		// insert our instance variables structure
		NSMapInsert( scrollers, self, vars );

		vars -> marks = [[NSMutableSet set] retain];
		vars -> shades = [[NSMutableArray array] retain];
		vars -> nearestPreviousMark = NSNotFound;
		vars -> nearestNextMark = NSNotFound;
		vars -> currentMark = NSNotFound;
	}
	return self;
}

- (void) dealloc {
	struct _instanceVars *vars = NSMapGet( scrollers, self );
	if( ! vars ) {
		[super dealloc];
		return;
	}

	[vars -> marks release];
	[vars -> shades release];

	vars -> marks = nil;
	vars -> shades = nil;

	NSMapRemove( scrollers, self );

	free( vars );

	[super dealloc];
}

#pragma mark -

- (void) drawRect:(NSRect) rect {
	[super drawRect:rect];

	struct _instanceVars *vars = NSMapGet( scrollers, self );
	if( ! vars || ( ! [vars -> marks count] && ! [vars -> shades count] ) ) return;

	NSAffineTransform *transform = [NSAffineTransform transform];
	float width = [[self class] scrollerWidthForControlSize:[self controlSize]];

	float scale = [self scaleToContentView];
	[transform scaleXBy:( sFlags.isHoriz ? scale : 1. ) yBy:( sFlags.isHoriz ? 1. : scale )];

	float offset = [self rectForPart:NSScrollerKnobSlot].origin.y;
	[transform translateXBy:( sFlags.isHoriz ? offset / scale : 0. ) yBy:( sFlags.isHoriz ? 0. : offset / scale )];

	NSBezierPath *shades = [NSBezierPath bezierPath];
	NSEnumerator *enumerator = [vars -> shades objectEnumerator];
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

	if( ( [vars -> shades count] % 2 ) == 1 ) {
		NSRect rect = NSZeroRect;
		unsigned long long start = [[vars -> shades lastObject] unsignedLongLongValue];
		unsigned long long stop = ( NSHeight( [self frame] ) / [self knobProportion] );

		if( sFlags.isHoriz ) rect = NSMakeRect( start, 0., ( stop - start ), width );
		else rect = NSMakeRect( 0., start, width, ( stop - start ) );

		rect.origin = [transform transformPoint:rect.origin];
		rect.size = [transform transformSize:rect.size];

		[shades appendBezierPathWithRect:NSIntegralRect( rect )];
	}

	NSRectClip( NSInsetRect( [self rectForPart:NSScrollerKnobSlot], ( sFlags.isHoriz ? 4. : 3. ), ( sFlags.isHoriz ? 3. : 4. ) ) );

	if( ! [shades isEmpty ] ) {
		[[[NSColor knobColor] colorWithAlphaComponent:0.45] set];
		[shades fill];
	}

	NSBezierPath *lines = [NSBezierPath bezierPath];
	NSMutableArray *lineArray = [NSMutableArray array];
	NSValue *currentMark = nil;
	enumerator = [vars -> marks objectEnumerator];

	unsigned long long currentPosition = ( vars -> currentMark != NSNotFound ? vars -> currentMark : [self floatValue] * [self contentViewLength] );
	BOOL foundNext = NO, foundPrevious = NO;
	NSRect knobRect = [self rectForPart:NSScrollerKnob];

	while( ( currentMark = [enumerator nextObject] ) ) {
		struct _mark mark;
		[currentMark getValue:&mark];
		unsigned long long value = mark.location;

		if( value < currentPosition && ( ! foundPrevious || value > vars -> nearestPreviousMark ) ) {
			vars -> nearestPreviousMark = value;
			foundPrevious = YES;
		}

		if( value > currentPosition && ( ! foundNext || value < vars -> nearestNextMark ) ) {
			vars -> nearestNextMark = value;
			foundNext = YES;
		}

		NSPoint point = NSMakePoint( ( sFlags.isHoriz ? value : 0. ), ( sFlags.isHoriz ? 0. : value ) );
		point = [transform transformPoint:point];
		point.x = ( sFlags.isHoriz ? roundf( point.x ) + 0.5 : point.x );
		point.y = ( sFlags.isHoriz ? point.y : roundf( point.y ) + 0.5 );

		if( ! NSPointInRect( point, knobRect ) ) {
			if( mark.color != nil ) {
				NSBezierPath *line = [NSBezierPath bezierPath];
				[line moveToPoint:point];

				point = NSMakePoint( ( sFlags.isHoriz ? 0. : width ), ( sFlags.isHoriz ? width : 0. ) );
				[line relativeLineToPoint:point];
				[lineArray addObject:mark.color];
				[lineArray addObject:line];
			} else {
				[lines moveToPoint:point];

				point = NSMakePoint( ( sFlags.isHoriz ? 0. : width ), ( sFlags.isHoriz ? width : 0. ) );
				[lines relativeLineToPoint:point];
			}
		}
	}

	if( ! foundPrevious ) vars -> nearestPreviousMark = NSNotFound;
	if( ! foundNext ) vars -> nearestNextMark = NSNotFound;

	if( ! [lines isEmpty] ) {
		[[NSColor selectedKnobColor] set];
		[lines stroke];
	}

	// This is so we can draw the colored lines after the regular lines
	enumerator = [lineArray objectEnumerator];
	NSColor *lineColor = nil;
	while( lineColor = [enumerator nextObject] ) {
		[lineColor set];
		[[enumerator nextObject] stroke];
	}

	if( ! [shades isEmpty] )
		[self drawKnob];
}

- (void) setFloatValue:(float) position knobProportion:(float) percent {
	struct _instanceVars *vars = NSMapGet( scrollers, self );
	if( vars ) vars -> currentMark = NSNotFound;
	if( vars && ( [self floatValue] != position || [self knobProportion] != percent ) && ( [vars -> marks count] || [vars -> shades count] ) )
		[self setNeedsDisplayInRect:[self rectForPart:NSScrollerKnobSlot]];
	[super setFloatValue:position knobProportion:percent];
}

/* - (NSMenu *) menuForEvent:(NSEvent *) event {
	struct _instanceVars *vars = NSMapGet( scrollers, self );
	if( ! vars || ! [vars -> marks count] ) return nil;

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
} */

#pragma mark -

- (void) updateNextAndPreviousMarks {
	struct _instanceVars *vars = NSMapGet( scrollers, self );
	if( ! vars ) return;

	NSEnumerator *enumerator = [vars -> marks objectEnumerator];
	NSValue *currentMark = nil;

	unsigned long long currentPosition = ( vars -> currentMark != NSNotFound ? vars -> currentMark : [self floatValue] * [self contentViewLength] );
	BOOL foundNext = NO, foundPrevious = NO;

	while( ( currentMark = [enumerator nextObject] ) ) {
		struct _mark mark;
		[currentMark getValue:&mark];
		unsigned long long value = mark.location;

		if( value < currentPosition && ( ! foundPrevious || value > vars -> nearestPreviousMark ) ) {
			vars -> nearestPreviousMark = value;
			foundPrevious = YES;
		}

		if( value > currentPosition && ( ! foundNext || value < vars -> nearestNextMark ) ) {
			vars -> nearestNextMark = value;
			foundNext = YES;
		}
	}

	if( ! foundPrevious ) vars -> nearestPreviousMark = NSNotFound;
	if( ! foundNext ) vars -> nearestNextMark = NSNotFound;
}

#pragma mark -

- (IBAction) clearMarksHereLess:(id) sender {
	NSEvent *event = [[NSApplication sharedApplication] currentEvent];
	NSPoint where = [self convertPoint:[event locationInWindow] fromView:nil];
	NSRect slotRect = [self rectForPart:NSScrollerKnobSlot];
	float scale = [self scaleToContentView];
	[self removeMarksLessThan:( ( sFlags.isHoriz ? where.x - NSMinX( slotRect ) : where.y - NSMinY( slotRect ) ) / scale )];
}

- (IBAction) clearMarksHereGreater:(id) sender {
	NSEvent *event = [[NSApplication sharedApplication] currentEvent];
	NSPoint where = [self convertPoint:[event locationInWindow] fromView:nil];
	NSRect slotRect = [self rectForPart:NSScrollerKnobSlot];
	float scale = [self scaleToContentView];
	[self removeMarksGreaterThan:( ( sFlags.isHoriz ? where.x - NSMinX( slotRect ) : where.y - NSMinY( slotRect ) ) / scale )];
}

#pragma mark -

- (void) setLocationOfCurrentMark:(unsigned long long) location {
	struct _instanceVars *vars = NSMapGet( scrollers, self );
	if( ! vars ) return;
	if( vars -> currentMark != location ) {
		vars -> currentMark = location;
		[self updateNextAndPreviousMarks];
	}
}

- (unsigned long long) locationOfCurrentMark {
	struct _instanceVars *vars = NSMapGet( scrollers, self );
	if( ! vars ) return NSNotFound;
	return vars -> currentMark;
}

#pragma mark -

- (unsigned long long) locationOfPreviousMark {
	struct _instanceVars *vars = NSMapGet( scrollers, self );
	if( ! vars ) return NSNotFound;
	return vars -> nearestPreviousMark;
}

- (unsigned long long) locationOfNextMark {
	struct _instanceVars *vars = NSMapGet( scrollers, self );
	if( ! vars ) return NSNotFound;
	return vars -> nearestNextMark;
}

- (unsigned long long) locationOfMarkWithIdentifier:(NSString *) identifier {
	struct _instanceVars *vars = NSMapGet( scrollers, self );
	if( ! vars ) return NSNotFound;

	NSEnumerator *enumerator = [vars -> marks objectEnumerator];
	unsigned long long currentMark = NSNotFound;
	NSValue *obj = nil;

	while( obj = [enumerator nextObject] ) {
		struct _mark mark;
		[obj getValue:&mark];
		if( [mark.identifier isEqualToString:identifier] ) {
			currentMark = mark.location;
			break;
		}
	}

	return currentMark;
}

#pragma mark -

- (void) shiftMarksAndShadedAreasBy:(long long) displacement {
	BOOL negative = ( displacement >= 0 ? NO : YES );
	NSMutableSet *shiftedMarks = [NSMutableSet set];
	NSValue *location = nil;

	struct _instanceVars *vars = NSMapGet( scrollers, self );
	if( ! vars ) return;

	if( ! ( negative && vars -> nearestPreviousMark < ABS( displacement ) ) ) vars -> nearestPreviousMark += displacement;
	else vars -> nearestPreviousMark = NSNotFound;

	if( ! ( negative && vars -> nearestNextMark < ABS( displacement ) ) ) vars -> nearestNextMark += displacement;
	else vars -> nearestNextMark = NSNotFound;

	if( ! ( negative && vars -> currentMark < ABS( displacement ) ) ) vars -> currentMark += displacement;
	else vars -> currentMark = NSNotFound;

	NSEnumerator *enumerator = [vars -> marks objectEnumerator];
	while( ( location = [enumerator nextObject] ) ) {
		struct _mark mark;
		[location getValue:&mark];
		if( ! ( negative && mark.location < ABS( displacement ) ) ) {
			mark.location += displacement;
			[shiftedMarks addObject:[NSValue value:&mark withObjCType:@encode( struct _mark )]];
		}
	}

	[vars -> marks setSet:shiftedMarks];

	NSMutableArray *shiftedShades = [NSMutableArray array];
	NSNumber *start = nil;
	NSNumber *stop = nil;

	enumerator = [vars -> shades objectEnumerator];
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

	[vars -> shades setArray:shiftedShades];

	[self setNeedsDisplayInRect:[self rectForPart:NSScrollerKnobSlot]];
}

#pragma mark -

- (void) addMarkAt:(unsigned long long) location {
	[self addMarkAt:location withIdentifier:nil withColor:nil];
}

- (void) addMarkAt:(unsigned long long) location withIdentifier:(NSString *) identifier {
	[self addMarkAt:location withIdentifier:identifier withColor:nil];
}

- (void) addMarkAt:(unsigned long long) location withColor:(NSColor *) color {
	[self addMarkAt:location withIdentifier:nil withColor:color];
}

- (void) addMarkAt:(unsigned long long) location withIdentifier:(NSString *) identifier withColor:(NSColor *) color {
	struct _instanceVars *vars = NSMapGet( scrollers, self );
	if( ! vars ) return;

	struct _mark mark = { location, identifier, color };
	[vars -> marks addObject:[NSValue value:&mark withObjCType:@encode( struct _mark )]];
	[self setNeedsDisplayInRect:[self rectForPart:NSScrollerKnobSlot]];
}

- (void) removeMarkAt:(unsigned long long) location {
	[self removeMarkAt:location withIdentifier:nil withColor:nil];
}

- (void) removeMarkAt:(unsigned long long) location withIdentifier:(NSString *) identifier {
	[self removeMarkAt:location withIdentifier:identifier withColor:nil];
}

- (void) removeMarkAt:(unsigned long long) location withColor:(NSColor *) color {
	[self removeMarkAt:location withIdentifier:nil withColor:color];
}

- (void) removeMarkAt:(unsigned long long) location withIdentifier:(NSString *) identifier withColor:(NSColor *) color {
	struct _instanceVars *vars = NSMapGet( scrollers, self );
	if( ! vars ) return;

	struct _mark mark = { location, identifier, color };
	[vars -> marks removeObject:[NSValue value:&mark withObjCType:@encode( struct _mark )]];
	[self setNeedsDisplayInRect:[self rectForPart:NSScrollerKnobSlot]];
}

- (void) removeMarkWithIdentifier:(NSString *) identifier {
	struct _instanceVars *vars = NSMapGet( scrollers, self );
	if( ! vars ) return;

	NSEnumerator *e = [[[vars -> marks copy] autorelease] objectEnumerator];
	NSValue *obj = nil;

	while( obj = [e nextObject] ) {
		struct _mark mark;
		[obj getValue:&mark];
		if( [mark.identifier isEqualToString:identifier] ) {
			[vars -> marks removeObject:obj];
		}
	}

	[self setNeedsDisplayInRect:[self rectForPart:NSScrollerKnobSlot]];
}

- (void) removeMarksGreaterThan:(unsigned long long) location {
	struct _instanceVars *vars = NSMapGet( scrollers, self );
	if( ! vars ) return;

	NSEnumerator *enumerator = [[[vars -> marks copy] autorelease] objectEnumerator];
	NSValue *obj = nil;

	while( obj = [enumerator nextObject] ) {
		struct _mark mark;
		[obj getValue:&mark];
		if( mark.location > location )
			[vars -> marks removeObject:obj];
	}

	[self setNeedsDisplayInRect:[self rectForPart:NSScrollerKnobSlot]];
}

- (void) removeMarksLessThan:(unsigned long long) location {
	struct _instanceVars *vars = NSMapGet( scrollers, self );
	if( ! vars ) return;

	NSEnumerator *enumerator = [[[vars -> marks copy] autorelease] objectEnumerator];
	NSValue *obj = nil;

	while( obj = [enumerator nextObject] ) {
		struct _mark mark;
		[obj getValue:&mark];
		if( mark.location < location )
			[vars -> marks removeObject:obj];
	}

	[self setNeedsDisplayInRect:[self rectForPart:NSScrollerKnobSlot]];
}

- (void) removeMarksInRange:(NSRange) range {
	struct _instanceVars *vars = NSMapGet( scrollers, self );
	if( ! vars ) return;

	NSEnumerator *enumerator = [[[vars -> marks copy] autorelease] objectEnumerator];
	NSValue *obj = nil;

	while( obj = [enumerator nextObject] ) {
		struct _mark mark;
		[obj getValue:&mark];
		if( NSLocationInRange( (unsigned int)mark.location, range ) )
			[vars -> marks removeObject:obj];
	}

	[self setNeedsDisplayInRect:[self rectForPart:NSScrollerKnobSlot]];
}

- (void) removeAllMarks {
	struct _instanceVars *vars = NSMapGet( scrollers, self );
	if( ! vars ) return;

	[vars -> marks removeAllObjects];
	[self setNeedsDisplayInRect:[self rectForPart:NSScrollerKnobSlot]];
}

#pragma mark -

- (void) setMarks:(NSSet *) marks {
	struct _instanceVars *vars = NSMapGet( scrollers, self );
	if( ! vars ) return;

	[vars -> marks setSet:marks];
	[self setNeedsDisplayInRect:[self rectForPart:NSScrollerKnobSlot]];
}

- (NSSet *) marks {
	struct _instanceVars *vars = NSMapGet( scrollers, self );
	if( ! vars ) return nil;
	return [[vars -> marks retain] autorelease];
}

#pragma mark -

- (void) startShadedAreaAt:(unsigned long long) location {
	struct _instanceVars *vars = NSMapGet( scrollers, self );
	if( ! vars ) return;

	if( ! [vars -> shades count] || ! ( [vars -> shades count] % 2 ) ) {
		[vars -> shades addObject:[NSNumber numberWithUnsignedLongLong:location]];
		[self setNeedsDisplayInRect:[self rectForPart:NSScrollerKnobSlot]];
	}
}

- (void) stopShadedAreaAt:(unsigned long long) location {
	struct _instanceVars *vars = NSMapGet( scrollers, self );
	if( ! vars ) return;

	if( [vars -> shades count] && ( [vars -> shades count] % 2 ) == 1 ) {
		[vars -> shades addObject:[NSNumber numberWithUnsignedLongLong:location]];
		[self setNeedsDisplayInRect:[self rectForPart:NSScrollerKnobSlot]];
	}
}

#pragma mark -

- (void) removeAllShadedAreas {
	struct _instanceVars *vars = NSMapGet( scrollers, self );
	if( ! vars ) return;

	[vars -> shades removeAllObjects];
	[self setNeedsDisplayInRect:[self rectForPart:NSScrollerKnobSlot]];
}

#pragma mark -

- (unsigned long long) contentViewLength {
	if( sFlags.isHoriz ) return ( NSWidth( [self frame] ) / [self knobProportion] );
	else return ( NSHeight( [self frame] ) / [self knobProportion] );
}

- (float) scaleToContentView {
	if( sFlags.isHoriz ) return NSWidth( [self rectForPart:NSScrollerKnobSlot] ) / ( NSWidth( [self frame] ) / [self knobProportion] );
	else return NSHeight( [self rectForPart:NSScrollerKnobSlot] ) / ( NSHeight( [self frame] ) / [self knobProportion] );
}

- (long) shiftAmountToCenterAlign {
	float scale = [self scaleToContentView];
	if( sFlags.isHoriz ) return ( ( NSWidth( [self rectForPart:NSScrollerKnobSlot] ) * [self knobProportion] ) / 2. ) / scale;
	else return ( ( NSHeight( [self rectForPart:NSScrollerKnobSlot] ) * [self knobProportion] ) / 2. ) / scale;
}
@end