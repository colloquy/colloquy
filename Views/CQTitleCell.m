#import "CQTitleCell.h"

@interface CQButtonCell (Private)
- (NSRect) _leftButtonCellFrameFromRect:(NSRect) cellFrame;
- (NSRect) _rightButtonCellFrameFromRect:(NSRect) cellFrame;
@end

@implementation CQTitleCell
@synthesize titleText = _titleText;
@synthesize subtitleText = _subtitleText;

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
	[_subtitleText release];

	[super dealloc];
}

- (id) copyWithZone:(NSZone *) zone {
	CQTitleCell *cell = (CQTitleCell *)[super copyWithZone:zone];
	cell->_attributes = [_attributes retain];
	cell->_titleText = [_titleText copy];
	cell->_subtitleText = [_subtitleText copy];
	return cell;
}

#pragma mark -

- (void) drawWithFrame:(NSRect) cellFrame inView:(NSView *) controlView {
	[super drawWithFrame:cellFrame inView:controlView];

	NSRect textRect = cellFrame;
	if (self.hidesLeftButton) {
		NSRect leftRect = [self _leftButtonCellFrameFromRect:cellFrame];
		textRect.size.width -= (textRect.size.width - leftRect.origin.x);
	} else {
		NSRect rightRect = [self _rightButtonCellFrameFromRect:cellFrame];
		textRect.size.width -= (textRect.size.width - rightRect.origin.x);
	}

	if (self.image) {
#define ImageTextPadding 10.
		CGFloat offset = (self.image.size.width + ImageTextPadding);
		textRect.origin.x += offset;
		textRect.size.width -= offset;
	}

#define CellTopPadding 4.
	textRect.origin.y += CellTopPadding;
	textRect.size.height -= CellTopPadding;

	BOOL highlighted = ([self isHighlighted] && controlView.window.firstResponder == controlView && [controlView.window isKeyWindow] && [[NSApplication sharedApplication] isActive]);
	if (!highlighted)
		[_attributes setObject:[NSColor colorWithCalibratedRed:(66 / 255.) green:(66 / 255.) blue:(66 / 255.) alpha:1.] forKey:NSForegroundColorAttributeName];
	else [_attributes setObject:[NSColor whiteColor] forKey:NSForegroundColorAttributeName];
	[_attributes setObject:[[NSFontManager sharedFontManager] fontWithFamily:@"Lucida Grande" traits:0 weight:5 size:12.] forKey:NSFontAttributeName];

	[_titleText drawInRect:textRect withAttributes:_attributes];

	if (!highlighted)
		[_attributes setObject:[NSColor colorWithCalibratedRed:(121. / 255.) green:(121. / 255.) blue:(121. / 255.) alpha:1.] forKey:NSForegroundColorAttributeName];
	// else don't change the color; its already white from drawing the title
	[_attributes setObject:[[NSFontManager sharedFontManager] fontWithFamily:@"Lucida Grande" traits:0 weight:5 size:10.] forKey:NSFontAttributeName];

#define CellTitleSubtitlePadding 4.
	NSSize titleSize = [_titleText sizeWithAttributes:_attributes];
	CGFloat offset = titleSize.height + CellTitleSubtitlePadding;
	textRect.origin.y += offset;
	textRect.size.height -= offset;

	[_subtitleText drawInRect:textRect withAttributes:_attributes];
}
@end
