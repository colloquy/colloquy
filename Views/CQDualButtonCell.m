#import "CQDualButtonCell.h"

#define CQMouseStateDefault 0
#define CQMouseStateHover 1
#define CQMouseStateClick 2

NSString *CQDualButtonLeftDictionaryKey = @"CQDualButtonLeftDictionaryKey";
NSString *CQDualButtonRightDictionaryKey = @"CQDualButtonRightDictionaryKey";

NSString *CQMouseStateDefaultKey = @"CQMouseStateDefaultKey";
NSString *CQMouseStateHoverKey = @"CQMouseStateHoverKey";
NSString *CQMouseStateClickKey = @"CQMouseStateClickKey";

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
@synthesize mouseStates = _mouseStates;

#pragma mark -

+ (BOOL) prefersTrackingUntilMouseUp {
	return YES;
}

#pragma mark -

- (id) init {
	if (!(self = [super init]))
		return nil;

	_rightButtonCell = [[NSButtonCell alloc] init];
	_rightButtonCell.buttonType = NSSwitchButton;
	_rightButtonCell.bezelStyle = NSSmallSquareBezelStyle;
	_rightButtonCell.imagePosition = NSImageRight;
	_rightButtonCell.bordered = NO;
	_rightButtonCell.continuous = NO;
	[_rightButtonCell sendActionOn:NSLeftMouseUp];

	_leftButtonCell = [[NSButtonCell alloc] init];
	_leftButtonCell.buttonType = NSSwitchButton;
	_leftButtonCell.bezelStyle = NSSmallSquareBezelStyle;
	_leftButtonCell.imagePosition = NSImageRight;
	_leftButtonCell.bordered = NO;
	_leftButtonCell.continuous = NO;
	[_leftButtonCell sendActionOn:NSLeftMouseUp];

	return self;
}

- (id) copyWithZone:(NSZone *) zone {
	CQDualButtonCell *cell = (CQDualButtonCell *)[super copyWithZone:zone];
	cell->_rightButtonCell = [_rightButtonCell retain];
	cell->_leftButtonCell = [_leftButtonCell retain];
	cell->_hideLeftButton = _hideLeftButton;
	cell->_leftButtonMouseState = _leftButtonMouseState;
	cell->_rightButtonMouseState = _rightButtonMouseState;
	cell->_mouseStates = [_mouseStates retain];
	return cell;
}

- (void) dealloc {
	[_mouseStates release];
	[_rightButtonCell release];
	[_leftButtonCell release];

	[super dealloc];
}

#pragma mark -

- (void) setHidesLeftButton:(BOOL) hidesLeftButton {
	_hideLeftButton = hidesLeftButton;

	[(NSControl *)self.controlView updateCell:self];
}

- (NSRect) _rightButtonCellFrameFromRect:(NSRect) cellFrame {
#define rightButtonBorderMargin 9.
	NSRect rightFrame = NSMakeRect(0, 0, _rightButtonCell.image.size.width, _rightButtonCell.image.size.height);
	rightFrame.origin.x = (cellFrame.origin.x + cellFrame.size.width) - (rightFrame.size.width + rightButtonBorderMargin);
	rightFrame.origin.y = floorf(((cellFrame.size.height / 2) + rightFrame.size.height));
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

- (NSImage *) _imageFromState:(NSInteger) state inDictionary:(NSDictionary *) dictionary {
	if (!dictionary)
		return nil;

	switch (_leftButtonMouseState) {
	case CQMouseStateDefault:
		return [dictionary objectForKey:CQMouseStateDefaultKey];
	case CQMouseStateHover:
		return [dictionary objectForKey:CQMouseStateHoverKey];
	case CQMouseStateClick:
		return [dictionary objectForKey:CQMouseStateClickKey];
	}

	return nil;
}

- (void) drawWithFrame:(NSRect) cellFrame inView:(NSView *) controlView {
	if (!_hideLeftButton) {
		NSImage *image = [self _imageFromState:_leftButtonMouseState inDictionary:[_mouseStates objectForKey:CQDualButtonLeftDictionaryKey]];
		if (image)
			_leftButtonCell.image = image;
		[_leftButtonCell drawWithFrame:[self _leftButtonCellFrameFromRect:cellFrame] inView:controlView];
	}

	NSImage *image = [self _imageFromState:_rightButtonMouseState inDictionary:[_mouseStates objectForKey:CQDualButtonRightDictionaryKey]];
	if (image)
		_rightButtonCell.image = image;
	[_rightButtonCell drawWithFrame:[self _rightButtonCellFrameFromRect:cellFrame] inView:controlView];
}

- (NSUInteger) hitTestForEvent:(NSEvent *) event inRect:(NSRect) cellFrame ofView:(NSView *) controlView {
	CGPoint point = [controlView convertPoint:event.locationInWindow fromView:nil];

	if (!_hideLeftButton && NSMouseInRect(point, [self _leftButtonCellFrameFromRect:cellFrame], [controlView isFlipped]))
		return (NSCellHitContentArea | NSCellHitTrackableArea);
	if (NSMouseInRect(point, [self _rightButtonCellFrameFromRect:cellFrame], [controlView isFlipped]))
		return (NSCellHitContentArea | NSCellHitTrackableArea);
	return [super hitTestForEvent:event inRect:cellFrame ofView:controlView];
}

#pragma mark -

- (void) _addTrackingAreasForView:(NSView *) controlView inRect:(NSRect) cellFrame withUserInfo:(NSDictionary *) userInfo mouseLocation:(NSPoint) mouseLocation forButtonFrame:(NSRect) buttonFrame {
	NSTrackingAreaOptions options = (NSTrackingEnabledDuringMouseDrag | NSTrackingMouseEnteredAndExited | NSTrackingActiveAlways);

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

#pragma mark -

- (BOOL) trackMouse:(NSEvent *) mouseEvent inRect:(NSRect) cellFrame ofView:(NSView *) controlView untilMouseUp:(BOOL) untilMouseUp {
	self.controlView = controlView;

	NSRect leftButtonRect = [self _leftButtonCellFrameFromRect:cellFrame];
	NSRect rightButtonRect = [self _rightButtonCellFrameFromRect:cellFrame];

	while (mouseEvent.type != NSLeftMouseUp) {
		NSPoint point = [controlView convertPoint:[mouseEvent locationInWindow] fromView:nil];
		if (NSMouseInRect(point, leftButtonRect, [controlView isFlipped]) && (_leftButtonMouseState != CQMouseStateClick)) {
			_leftButtonMouseState = CQMouseStateClick;
			[controlView setNeedsDisplayInRect:cellFrame];
		}

		if (NSMouseInRect(point, rightButtonRect, [controlView isFlipped]) && (_rightButtonMouseState != CQMouseStateClick)) {
			_rightButtonMouseState = CQMouseStateClick;
			[controlView setNeedsDisplayInRect:cellFrame];
		}

		if (mouseEvent.type == NSMouseEntered || mouseEvent.type == NSMouseExited)
			[NSApp sendEvent:mouseEvent];

		mouseEvent = [controlView.window nextEventMatchingMask:(NSLeftMouseUpMask | NSLeftMouseDraggedMask | NSMouseEnteredMask | NSMouseExitedMask)];
	}

	if (_leftButtonMouseState == CQMouseStateClick) {
		[_leftButtonCell trackMouse:mouseEvent inRect:leftButtonRect ofView:controlView untilMouseUp:untilMouseUp];
		_leftButtonMouseState = CQMouseStateHover;
		[controlView setNeedsDisplayInRect:cellFrame];
	}

	if (_rightButtonMouseState == CQMouseStateClick) {
		[_rightButtonCell trackMouse:mouseEvent inRect:rightButtonRect ofView:controlView untilMouseUp:untilMouseUp];
		_rightButtonMouseState = CQMouseStateHover;
		[controlView setNeedsDisplayInRect:cellFrame];
	}

	return YES;
}

- (void) mouseEntered:(NSEvent *) event {
	if ([[event.trackingArea.userInfo objectForKey:@"Position"] isEqualToString:@"Left"])
		_leftButtonMouseState = CQMouseStateHover;
	else _rightButtonMouseState = CQMouseStateHover;

	[(NSControl *)self.controlView updateCell:self];
}

- (void) mouseExited:(NSEvent *) event {
	if ([[event.trackingArea.userInfo objectForKey:@"Position"] isEqualToString:@"Left"])
		_leftButtonMouseState = CQMouseStateDefault;
	else _rightButtonMouseState = CQMouseStateDefault;

	[(NSControl *)self.controlView updateCell:self];
}
@end
