#import "JVMarkedScroller.h"

@interface JVMark : NSObject
+ (JVMark *) markWithLocation:(unsigned long long) location identifier:(NSString *) identifier color:(NSColor *) color;

@property (nonatomic) unsigned long long location;
@property (nonatomic, copy) NSString *identifier;
@property (nonatomic, strong) NSColor *color;
@end

@implementation JVMark
+ (JVMark *) markWithLocation:(unsigned long long) location identifier:(NSString *) identifier color:(NSColor *) color {
	JVMark *mark = [[JVMark alloc] init];
	mark.location = location;
	mark.identifier = identifier;
	mark.color = color;
	return mark;
}
@end

@implementation JVMarkedScroller
- (instancetype) initWithFrame:(NSRect) frame {
	if( ( self = [super initWithFrame:frame] ) ) {
		_marks = [NSMutableSet set];
		_shades = [NSMutableArray array];
		_nearestPreviousMark = NSNotFound;
		_nearestNextMark = NSNotFound;
		_currentMark = NSNotFound;
	}
	return self;
}

#pragma mark -

- (void) drawRect:(NSRect) rect {
	[super drawRect:rect];

	NSAffineTransform *transform = [NSAffineTransform transform];
	float width = [[self class] scrollerWidthForControlSize:[self controlSize] scrollerStyle:NSScrollerStyleOverlay];

	float scale = [self scaleToContentView];
	[transform scaleXBy:( sFlags.isHoriz ? scale : 1. ) yBy:( sFlags.isHoriz ? 1. : scale )];

	float offset = [self rectForPart:NSScrollerKnobSlot].origin.y;
	[transform translateXBy:( sFlags.isHoriz ? offset / scale : 0. ) yBy:( sFlags.isHoriz ? 0. : offset / scale )];

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
		unsigned long long stop = [self contentViewLength];

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

	unsigned long long currentPosition = ( _currentMark != NSNotFound ? _currentMark : [self floatValue] * [self contentViewLength] );
	BOOL foundNext = NO, foundPrevious = NO;
	NSRect knobRect = [self rectForPart:NSScrollerKnob];

	for( JVMark *mark in _marks ) {
		unsigned long long value = mark.location;

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
			if( mark.color ) {
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

	if( ! foundPrevious ) _nearestPreviousMark = NSNotFound;
	if( ! foundNext ) _nearestNextMark = NSNotFound;

	if( ! [lines isEmpty] ) {
		[[NSColor selectedKnobColor] set];
		[lines stroke];
	}

	// This is so we can draw the colored lines after the regular lines
	enumerator = [lineArray objectEnumerator];
	NSColor *lineColor = nil;
	while( ( lineColor = [enumerator nextObject] ) ) {
		[lineColor set];
		[[enumerator nextObject] stroke];
	}

	if( ! [shades isEmpty] )
		[self drawKnob];
}

- (void) setDoubleValue:(double) position {
	if( ! _jumpingToMark ) _currentMark = NSNotFound;
	if( ( [self doubleValue] != position ) && ( [_marks count] || [_shades count] ) )
		[self setNeedsDisplayInRect:[self rectForPart:NSScrollerKnobSlot]];
	[super setDoubleValue:position];
}

- (void) setKnobProportion:(CGFloat) proportion {
	if( ! _jumpingToMark ) _currentMark = NSNotFound;
	if( ( [self knobProportion] != proportion ) && ( [_marks count] || [_shades count] ) )
		[self setNeedsDisplayInRect:[self rectForPart:NSScrollerKnobSlot]];
	[super setKnobProportion:proportion];
}

- (NSMenu *) menuForEvent:(NSEvent *) event {
	NSMenu *menu = [[NSMenu alloc] initWithTitle:@""];
	NSMenuItem *item = nil;

	item = [[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Clear All Marks", "clear all marks contextual menu item title" ) action:@selector( removeAllMarks ) keyEquivalent:@""];
	[item setTarget:self];
	[menu addItem:item];

	if( sFlags.isHoriz ) {
		item = [[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Clear Marks from Here Left", "clear marks from here left contextual menu") action:@selector( clearMarksHereLess: ) keyEquivalent:@""];
		[item setTarget:self];
		[menu addItem:item];

		item = [[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Clear Marks from Here Right", "clear marks from here right contextual menu") action:@selector( clearMarksHereGreater: ) keyEquivalent:@""];
		[item setTarget:self];
		[menu addItem:item];
	} else {
		item = [[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Clear Marks from Here Up", "clear marks from here up contextual menu") action:@selector( clearMarksHereLess: ) keyEquivalent:@""];
		[item setTarget:self];
		[menu addItem:item];

		item = [[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Clear Marks from Here Down", "clear marks from here up contextual menu") action:@selector( clearMarksHereGreater: ) keyEquivalent:@""];
		[item setTarget:self];
		[menu addItem:item];
	}

	[menu addItem:[NSMenuItem separatorItem]];

	item = [[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Jump to Previous Mark", "jump to previous mark contextual menu") action:@selector( jumpToPreviousMark: ) keyEquivalent:@"["];
	[item setTarget:self];
	[menu addItem:item];

	item = [[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Jump to Next Mark", "jump to next mark contextual menu") action:@selector( jumpToNextMark: ) keyEquivalent:@"]"];
	[item setTarget:self];
	[menu addItem:item];

	return menu;
}

#pragma mark -

+ (BOOL) isCompatibleWithOverlayScrollers {
	return YES;
}

#pragma mark -

- (void) updateNextAndPreviousMarks {
	unsigned long long currentPosition = ( _currentMark != NSNotFound ? _currentMark : [self floatValue] * [self contentViewLength] );
	BOOL foundNext = NO, foundPrevious = NO;

	for( JVMark *mark in _marks ) {
		unsigned long long value = mark.location;

		if( value < currentPosition && ( ! foundPrevious || value > _nearestPreviousMark ) ) {
			_nearestPreviousMark = value;
			foundPrevious = YES;
		}

		if( value > currentPosition && ( ! foundNext || value < _nearestNextMark ) ) {
			_nearestNextMark = value;
			foundNext = YES;
		}
	}

	if( ! foundPrevious ) _nearestPreviousMark = NSNotFound;
	if( ! foundNext ) _nearestNextMark = NSNotFound;
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
	if( _currentMark != location ) {
		_currentMark = location;
		[self updateNextAndPreviousMarks];
	}
}

- (unsigned long long) locationOfCurrentMark {
	return _currentMark;
}

#pragma mark -

- (IBAction) jumpToPreviousMark:(id) sender {
	if( _nearestPreviousMark != NSNotFound ) {
		_currentMark = _nearestPreviousMark;
		_jumpingToMark = YES;
		float shift = [self shiftAmountToCenterAlign];
		[[(NSScrollView *)[self superview] documentView] scrollPoint:NSMakePoint( 0., _currentMark - shift )];
		_jumpingToMark = NO;

		[self setNeedsDisplayInRect:[self rectForPart:NSScrollerKnobSlot]];
	}
}

- (IBAction) jumpToNextMark:(id) sender {
	if( _nearestNextMark != NSNotFound ) {
		_currentMark = _nearestNextMark;
		_jumpingToMark = YES;
		float shift = [self shiftAmountToCenterAlign];
		[[(NSScrollView *)[self superview] documentView] scrollPoint:NSMakePoint( 0., _currentMark - shift )];
		_jumpingToMark = NO;

		[self setNeedsDisplayInRect:[self rectForPart:NSScrollerKnobSlot]];
	}
}

- (void) jumpToMarkWithIdentifier:(NSString *) identifier {
	_jumpingToMark = YES;

	BOOL foundMark = NO;

	for( JVMark *mark in _marks ) {
		if( [mark.identifier isEqualToString:identifier] ) {
			_currentMark = mark.location;
			foundMark = YES;
			break;
		}
	}

	if( foundMark ) {
		float shift = [self shiftAmountToCenterAlign];
		[[(NSScrollView *)[self superview] documentView] scrollPoint:NSMakePoint( 0., _currentMark - shift )];
	}

	_jumpingToMark = NO;
}

#pragma mark -

- (void) shiftMarksAndShadedAreasBy:(long long) displacement {
	BOOL negative = ( displacement >= 0 ? NO : YES );
	NSMutableSet *shiftedMarks = [NSMutableSet set];
	unsigned long long unsignedDisplacement = (unsigned long long)ABS( displacement );

	if( ! ( negative && _nearestPreviousMark < unsignedDisplacement ) ) _nearestPreviousMark += unsignedDisplacement;
	else _nearestPreviousMark = NSNotFound;

	if( ! ( negative && _nearestNextMark < unsignedDisplacement ) ) _nearestNextMark += unsignedDisplacement;
	else _nearestNextMark = NSNotFound;

	if( ! ( negative && _currentMark < unsignedDisplacement ) ) _currentMark += unsignedDisplacement;
	else _currentMark = NSNotFound;

	for( JVMark *mark in _marks ) {
		if( ! ( negative && mark.location < unsignedDisplacement ) ) {
			mark.location += unsignedDisplacement;
			[shiftedMarks addObject:mark];
		}
	}

	[_marks setSet:shiftedMarks];

	NSMutableArray *shiftedShades = [NSMutableArray array];
	NSNumber *start = nil;
	NSNumber *stop = nil;

	NSEnumerator *enumerator = [_shades objectEnumerator];
	while( ( start = [enumerator nextObject] ) && ( ( stop = [enumerator nextObject] ) || YES ) ) {
		unsigned long long shiftedStart = [start unsignedLongLongValue];

		if( stop ) {
			unsigned long long shiftedStop = [stop unsignedLongLongValue];
			if( ! ( negative && shiftedStart < unsignedDisplacement ) && ! ( negative && shiftedStop < unsignedDisplacement ) ) {
				[shiftedShades addObject:@( shiftedStart + unsignedDisplacement )];
				[shiftedShades addObject:@( shiftedStop + unsignedDisplacement )];
			}
		} else if( ! ( negative && shiftedStart < unsignedDisplacement ) ) {
			[shiftedShades addObject:@( shiftedStart + unsignedDisplacement )];
		}
	}

	[_shades setArray:shiftedShades];

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
	[_marks addObject:[JVMark markWithLocation:location identifier:identifier color:color]];
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
	for( JVMark *mark in [_marks copy] ) {
		if (mark.location == location) {
			[_marks removeObject:mark];
			break;
		}
	}
	[self setNeedsDisplayInRect:[self rectForPart:NSScrollerKnobSlot]];
}

- (void) removeMarkWithIdentifier:(NSString *) identifier {
	for( JVMark *mark in [_marks copy] ) {
		if( [mark.identifier isEqualToString:identifier] ) {
			[_marks removeObject:mark];
		}
	}

	[self setNeedsDisplayInRect:[self rectForPart:NSScrollerKnobSlot]];
}

- (void) removeMarksGreaterThan:(unsigned long long) location {
	for( JVMark *mark in [_marks copy] ) {
		if( mark.location > location )
			[_marks removeObject:mark];
	}

	[self setNeedsDisplayInRect:[self rectForPart:NSScrollerKnobSlot]];
}

- (void) removeMarksLessThan:(unsigned long long) location {
	for( JVMark *mark in [_marks copy] ) {
		if( mark.location < location )
			[_marks removeObject:mark];
	}

	[self setNeedsDisplayInRect:[self rectForPart:NSScrollerKnobSlot]];
}

- (void) removeMarksInRange:(NSRange) range {
	for( JVMark *mark in [_marks copy] ) {
		if( NSLocationInRange( mark.location, range ) )
			[_marks removeObject:mark];
	}

	[self setNeedsDisplayInRect:[self rectForPart:NSScrollerKnobSlot]];
}

- (void) removeAllMarks {
	[_marks removeAllObjects];
	[self setNeedsDisplayInRect:[self rectForPart:NSScrollerKnobSlot]];
}

#pragma mark -

- (void) setMarks:(NSSet *) marks {
	[_marks setSet:marks];
	[self setNeedsDisplayInRect:[self rectForPart:NSScrollerKnobSlot]];
}

- (NSSet *) marks {
	return _marks;
}

#pragma mark -

- (void) startShadedAreaAt:(unsigned long long) location {
	if( ! [_shades count] || ! ( [_shades count] % 2 ) ) {
		[_shades addObject:@(location)];
		[self setNeedsDisplayInRect:[self rectForPart:NSScrollerKnobSlot]];
	}
}

- (void) stopShadedAreaAt:(unsigned long long) location {
	if( [_shades count] && ( [_shades count] % 2 ) == 1 ) {
		[_shades addObject:@(location)];
		[self setNeedsDisplayInRect:[self rectForPart:NSScrollerKnobSlot]];
	}
}

#pragma mark -

- (void) removeAllShadedAreas {
	[_shades removeAllObjects];
	[self setNeedsDisplayInRect:[self rectForPart:NSScrollerKnobSlot]];
}

#pragma mark -

- (unsigned long long) contentViewLength {
	if( sFlags.isHoriz ) return ( NSWidth( [self frame] ) / [self knobProportion] );
	else return ( NSHeight( [self frame] ) / [self knobProportion] );
}

- (CGFloat) scaleToContentView {
	if( sFlags.isHoriz ) return NSWidth( [self rectForPart:NSScrollerKnobSlot] ) / NSWidth( [[(NSScrollView *)[self superview] contentView] documentRect] );
	else return NSHeight( [self rectForPart:NSScrollerKnobSlot] ) / NSHeight( [[(NSScrollView *)[self superview] contentView] documentRect] );
}

- (CGFloat) shiftAmountToCenterAlign {
	float scale = [self scaleToContentView];
	if( sFlags.isHoriz ) return ( ( NSWidth( [self rectForPart:NSScrollerKnobSlot] ) * [self knobProportion] ) / 2. ) / scale;
	else return ( ( NSHeight( [self rectForPart:NSScrollerKnobSlot] ) * [self knobProportion] ) / 2. ) / scale;
}
@end
