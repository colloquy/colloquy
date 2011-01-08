#import "CQTitleCell.h"

@interface CQButtonCell (Private)
- (NSRect) _leftButtonCellFrameFromRect:(NSRect) cellFrame;
- (NSRect) _rightButtonCellFrameFromRect:(NSRect) cellFrame;
@end

@implementation CQTitleCell
@synthesize titleText = _titleText;
@synthesize attributes = _attributes;

- (id) init {
	if (!(self = [super init]))
		return nil;

	_attributes = [[NSMutableDictionary alloc] init];

	NSMutableParagraphStyle *paragraphStyle = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
	paragraphStyle.lineBreakMode = NSLineBreakByTruncatingTail;
	[_attributes setObject:paragraphStyle forKey:NSParagraphStyleAttributeName];
	[paragraphStyle release];

	[_attributes setObject:[NSColor clearColor] forKey:NSBackgroundColorAttributeName];

	return self;
}

- (void) dealloc {
	[_attributes release];
	[_titleText release];

	[super dealloc];
}

- (id) copyWithZone:(NSZone *) zone {
	CQTitleCell *cell = (CQTitleCell *)[super copyWithZone:zone];
	cell->_attributes = [_attributes retain];
	cell->_titleText = [_titleText retain];
	return cell;
}

#pragma mark -

- (NSRect) _titleCellFrameFromRect:(NSRect) cellFrame {
	NSRect textRect = cellFrame;
	NSRect workingRect = { { 0, 0 }, { 0, 0 } };

	if (self.hidesLeftButton)
		workingRect = [self _rightButtonCellFrameFromRect:cellFrame];
	else workingRect = [self _leftButtonCellFrameFromRect:cellFrame];

	textRect.size.width = (cellFrame.size.width + cellFrame.origin.x) - textRect.origin.x;
	textRect.size.width -= (cellFrame.size.width + cellFrame.origin.x) - workingRect.origin.x;
#define ButtonPadding 5.;
	textRect.size.width -= ButtonPadding;

	if (self.image) {
#define ImageTextPadding 10.
		CGFloat offset = (self.image.size.width + ImageTextPadding);
		textRect.origin.x += offset;
		textRect.size.width -= offset;
	}
	
#define CellTopPadding 2.
	textRect.origin.y += CellTopPadding;
	textRect.size.height -= CellTopPadding;

	return textRect;
}

#pragma mark -

- (void) drawWithFrame:(NSRect) cellFrame inView:(NSView *) controlView {
	[super drawWithFrame:cellFrame inView:controlView];

	BOOL highlighted = ([self isHighlighted] && controlView.window.firstResponder == controlView && [controlView.window isKeyWindow] && [[NSApplication sharedApplication] isActive]);
	if (!highlighted)
		[_attributes setObject:[NSColor colorWithCalibratedRed:(66 / 255.) green:(66 / 255.) blue:(66 / 255.) alpha:1.] forKey:NSForegroundColorAttributeName];
	else [_attributes setObject:[NSColor whiteColor] forKey:NSForegroundColorAttributeName];
	[_attributes setObject:[[NSFontManager sharedFontManager] fontWithFamily:@"Lucida Grande" traits:0 weight:5 size:12.] forKey:NSFontAttributeName];

	[_titleText drawInRect:[self _titleCellFrameFromRect:cellFrame] withAttributes:_attributes];
}
@end
