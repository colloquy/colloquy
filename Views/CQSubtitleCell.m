#import "CQSubtitleCell.h"

// This is really a private category for methods and properties in CQTitleCell, if it is as such, the compiler throws warnings. Having it as a category for a subclass will
// cause the compiler to see that attributes is a NSMutableDictionary and not a NSDictionary and not throw any warnings.
@interface CQSubtitleCell (Private)
@property (nonatomic, readonly) NSMutableDictionary *attributes;
- (NSRect) _titleCellFrameFromRect:(NSRect) cellFrame;
@end

@implementation CQSubtitleCell
@synthesize subtitleText = _subtitleText;

- (void) dealloc {
	[_subtitleText release];

	[super dealloc];
}

- (id) copyWithZone:(NSZone *) zone {
	CQSubtitleCell *cell = (CQSubtitleCell *)[super copyWithZone:zone];
	cell->_subtitleText = [_subtitleText retain];
	return cell;
}

#pragma mark -

- (NSRect) _subtitleCellFrameFromRect:(NSRect) cellFrame {
	NSRect textRect = [self _titleCellFrameFromRect:cellFrame];
	
#define CellTitleSubtitlePadding 4.
	NSSize titleSize = [self.titleText sizeWithAttributes:self.attributes];
	CGFloat offset = titleSize.height + CellTitleSubtitlePadding;
	textRect.origin.y += offset;
	textRect.size.height -= offset;
	
	return textRect;
}

- (void) drawWithFrame:(NSRect) cellFrame inView:(NSView *) controlView {
	[super drawWithFrame:cellFrame inView:controlView];

	BOOL highlighted = ([self isHighlighted] && controlView.window.firstResponder == controlView && [controlView.window isKeyWindow] && [[NSApplication sharedApplication] isActive]);

	if (!highlighted)
		[self.attributes setObject:[NSColor colorWithCalibratedRed:(121. / 255.) green:(121. / 255.) blue:(121. / 255.) alpha:1.] forKey:NSForegroundColorAttributeName];
	// else don't change the color; its already white from drawing the title
	[self.attributes setObject:[[NSFontManager sharedFontManager] fontWithFamily:@"Lucida Grande" traits:0 weight:5 size:10.] forKey:NSFontAttributeName];

	[_subtitleText drawInRect:[self _subtitleCellFrameFromRect:cellFrame] withAttributes:self.attributes];
}
@end
