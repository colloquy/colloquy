#import "CQDualButtonCell.h"

@interface NSButtonCell (Properties)
@property (nonatomic) NSButtonType buttonType;
@property (nonatomic) BOOL bordered;
@property (nonatomic) BOOL continuous;
@end

#pragma mark -

@implementation CQDualButtonCell
@synthesize rightButtonCell = _rightButtonCell;
@synthesize leftButtonCell = _leftButtonCell;
@synthesize hidesLeftButton = _hideLeftButton;

#pragma mark -

+ (BOOL) prefersTrackingUntilMouseUp {
	return YES;
}

- (id) init {
	if (!(self = [super init]))
		return nil;

	_rightButtonCell = [[NSButtonCell alloc] init];
	_rightButtonCell.buttonType = NSSwitchButton;
	_rightButtonCell.bezelStyle = NSSmallSquareBezelStyle;
	_rightButtonCell.imagePosition = NSImageRight;
	_rightButtonCell.bordered = NO;
	_rightButtonCell.continuous = NO;
	[_rightButtonCell sendActionOn:NSLeftMouseUp];;

	_leftButtonCell = [[NSButtonCell alloc] init];
	_leftButtonCell.buttonType = NSSwitchButton;
	_leftButtonCell.bezelStyle = NSSmallSquareBezelStyle;
	_leftButtonCell.imagePosition = NSImageRight;
	_leftButtonCell.bordered = NO;
	_leftButtonCell.continuous = NO;
	[_leftButtonCell sendActionOn:NSLeftMouseUp];;

	return self;
}

- (id) copyWithZone:(NSZone *) zone {
	CQDualButtonCell *cell = (CQDualButtonCell *)[super copyWithZone:zone];
	cell->_rightButtonCell = [_rightButtonCell retain];
	cell->_leftButtonCell = [_leftButtonCell retain];
	cell->_hideLeftButton = _hideLeftButton;
	cell->_mouseoverInLeftButton = _mouseoverInLeftButton;
	cell->_mouseoverInRightButton = _mouseoverInRightButton;
	return cell;
}

- (void) dealloc {
	[_rightButtonCell release];
	[_leftButtonCell release];
	
	[super dealloc];
}

#pragma mark -

- (NSRect) _rightButtonCellFrameFromRect:(NSRect) cellFrame {
#define rightButtonBorderMargin 9.
	NSRect rightFrame = NSMakeRect(0, 0, _rightButtonCell.image.size.width, _rightButtonCell.image.size.height);
	rightFrame.origin.x = (cellFrame.origin.x + cellFrame.size.width) - (rightFrame.size.width + rightButtonBorderMargin);
	rightFrame.origin.y = cellFrame.size.height - (floorf((cellFrame.size.height / 2) - (rightFrame.size.height / 2)));
	return rightFrame;
}

- (NSRect) _leftButtonCellFrameFromRect:(NSRect) cellFrame {
#define BetweenButtonBorderMargin 7.
	NSRect rightFrame = [self _rightButtonCellFrameFromRect:cellFrame];
	NSRect leftFrame = NSMakeRect(0, 0, _leftButtonCell.image.size.width, _leftButtonCell.image.size.height);
	leftFrame.origin.x = rightFrame.origin.x - (leftFrame.size.width + BetweenButtonBorderMargin);
	leftFrame.origin.y = rightFrame.origin.y;
	return leftFrame;
}

#pragma mark -

- (void) drawWithFrame:(NSRect) cellFrame inView:(NSView *) controlView {
	NSRect rightFrame = [self _rightButtonCellFrameFromRect:cellFrame];

	[_rightButtonCell drawWithFrame:rightFrame inView:controlView];

	if (!_hideLeftButton)
		[_leftButtonCell drawWithFrame:[self _leftButtonCellFrameFromRect:cellFrame] inView:controlView];
}

- (NSUInteger) hitTestForEvent:(NSEvent *) event inRect:(NSRect) cellFrame ofView:(NSView *) controlView {
	CGPoint point = [controlView convertPoint:event.locationInWindow fromView:nil];

	if (!_hideLeftButton && NSMouseInRect(point, [self _leftButtonCellFrameFromRect:cellFrame], [controlView isFlipped])) {
		_leftButtonCell.state = NSOnState;
		return (NSCellHitContentArea | NSCellHitTrackableArea);
	} else {
		_leftButtonCell.state = NSOffState;
	}

	if (NSMouseInRect(point, [self _rightButtonCellFrameFromRect:cellFrame], [controlView isFlipped])) {
		_rightButtonCell.state = NSOnState;
		return (NSCellHitContentArea | NSCellHitTrackableArea);
	} else {
		_rightButtonCell.state = NSOffState;
	}

	return [super hitTestForEvent:event inRect:cellFrame ofView:controlView];
}

#pragma mark -

- (void) _addTrackingAreasForView:(NSView *) controlView inRect:(NSRect) cellFrame withUserInfo:(NSDictionary *) userInfo mouseLocation:(NSPoint) mouseLocation forButtonFrame:(NSRect) buttonFrame {
    NSTrackingAreaOptions options = NSTrackingEnabledDuringMouseDrag | NSTrackingMouseEnteredAndExited | NSTrackingActiveAlways;

    if (NSMouseInRect(mouseLocation, buttonFrame, [controlView isFlipped])) {
        options |= NSTrackingAssumeInside;
        [controlView setNeedsDisplayInRect:cellFrame];
    }

    NSTrackingArea *buttonTrackingArea = [[NSTrackingArea alloc] initWithRect:buttonFrame options:options owner:controlView userInfo:userInfo];
    [controlView addTrackingArea:buttonTrackingArea];
	[buttonTrackingArea release];
}

- (void) addTrackingAreasForView:(NSView *) controlView inRect:(NSRect) cellFrame withUserInfo:(NSDictionary *) userInfo mouseLocation:(NSPoint) mouseLocation {
	NSMutableDictionary *modifiedUserInfo = [userInfo mutableCopy];
	[modifiedUserInfo setObject:@"Left" forKey:@"Position"];
	[self _addTrackingAreasForView:controlView inRect:cellFrame withUserInfo:modifiedUserInfo mouseLocation:mouseLocation forButtonFrame:[self _leftButtonCellFrameFromRect:cellFrame]];

	id old = modifiedUserInfo;
	modifiedUserInfo = [userInfo mutableCopy];
	[old release];
	[modifiedUserInfo setObject:@"Right" forKey:@"Position"];
	[self _addTrackingAreasForView:controlView inRect:cellFrame withUserInfo:modifiedUserInfo mouseLocation:mouseLocation forButtonFrame:[self _rightButtonCellFrameFromRect:cellFrame]];
	[modifiedUserInfo release];
}

- (void) mouseEntered:(NSEvent *) event {
	NSLog(@"%@", event.trackingArea.userInfo);
	// get event's trackingArea's frame and see which button it intersects. set that mouseover BOOL to YES

	[(NSControl *)self.controlView updateCell:self];
}

- (void) mouseExited:(NSEvent *) event {
	// get event's trackingArea's frame and see which button it intersects. set that mouseover BOOL to NO
	

	[(NSControl *)self.controlView updateCell:self];
}

/*- (BOOL) trackMouse:(NSEvent *) event inRect:(NSRect) cellFrame ofView:(NSView *) controlView untilMouseUp:(BOOL) untilMouseUp {
	[super trackMouse:event inRect:cellFrame ofView:controlView untilMouseUp:untilMouseUp];

	NSLog(@"tracking");

	if ([self hitTestForEvent:event inRect:cellFrame ofView:controlView] != (NSCellHitContentArea | NSCellHitTrackableArea))
		return YES;

	if (event.type != NSLeftMouseDown)
		return YES;

	BOOL clicked = NO;
	while (event.type != NSLeftMouseUp) {
		[controlView setNeedsDisplayInRect:cellFrame];

		clicked = [self hitTestForEvent:event inRect:cellFrame ofView:controlView] == (NSCellHitContentArea | NSCellHitTrackableArea);
		if (!clicked)
			[NSApp sendEvent:event];

		event = [controlView.window nextEventMatchingMask:(NSLeftMouseUpMask | NSLeftMouseDraggedMask | NSMouseEnteredMask | NSMouseExitedMask)];
	}

	if (!clicked)
		return YES;

	CGPoint point = [controlView convertPoint:event.locationInWindow fromView:nil];
	if (!_hideLeftButton && NSMouseInRect(point, [self _leftButtonCellFrameFromRect:cellFrame], [controlView isFlipped]))
		[_leftButtonCell.target performSelector:_leftButtonCell.action withObject:_leftButtonCell];
	else if (NSMouseInRect(point, [self _rightButtonCellFrameFromRect:cellFrame], [controlView isFlipped]))
		[_rightButtonCell.target performSelector:_rightButtonCell.action withObject:_rightButtonCell];
	return YES;
 }*/
@end
