#import "CQDownloadCell.h"

// This is really a private category for methods and properties in CQTitleCell, if it is as such, the compiler throws warnings. Having it as a category for a subclass will
// cause the compiler to see that attributes is a NSMutableDictionary and not a NSDictionary and not throw any warnings.
@interface CQDownloadCell (Private)
@property (nonatomic, readonly) NSMutableDictionary *attributes;
- (NSRect) _titleCellFrameFromRect:(NSRect) cellFrame;
@end

@implementation CQDownloadCell
@synthesize subtitleText = _subtitleText;
@synthesize progressIndicator = _progressIndicator;

- (id) init {
	if (!(self = [super init]))
		return nil;

	_progressIndicator = [[NSProgressIndicator alloc] init];
	_progressIndicator.usesThreadedAnimation = YES;
	_progressIndicator.style = NSProgressIndicatorBarStyle;

	[_progressIndicator startAnimation:nil];

	return self;
}

- (void) dealloc {
	[_progressIndicator removeFromSuperview];
	[_progressIndicator release];
	[_subtitleText release];

	[super dealloc];
}

- (id) copyWithZone:(NSZone *) zone {
	CQDownloadCell *cell = (CQDownloadCell *)[super copyWithZone:zone];
	cell->_progressIndicator = [_progressIndicator retain];
	cell->_subtitleText = [_subtitleText retain];
	return cell;
}

- (NSRect) _progressIndicatorCellFrameFromRect:(NSRect) cellFrame {
	NSRect progressRect = [self _titleCellFrameFromRect:cellFrame];

#define CellTitleProgressIndicatorPadding 4.
	CGFloat offset = _progressIndicator.frame.size.height + CellTitleProgressIndicatorPadding;
	progressRect.origin.y += offset;
	progressRect.size.height -= offset;

	return progressRect;
}

- (NSRect) _subtitleCellFrameFromRect:(NSRect) cellFrame {
	NSRect textRect = [self _progressIndicatorCellFrameFromRect:cellFrame];

#define CellTitleSubtitlePadding 4.
	NSSize titleSize = [self.titleText sizeWithAttributes:self.attributes];
	CGFloat offset = titleSize.height + CellTitleSubtitlePadding;
	textRect.origin.y += offset;
	textRect.size.height -= offset;
	
	return textRect;
}

#pragma mark -

- (void) drawWithFrame:(NSRect) cellFrame inView:(NSView *) controlView {
	[super drawWithFrame:cellFrame inView:controlView];

	BOOL highlighted = ([self isHighlighted] && controlView.window.firstResponder == controlView && [controlView.window isKeyWindow] && [[NSApplication sharedApplication] isActive]);

	_progressIndicator.frame = [self _progressIndicatorCellFrameFromRect:cellFrame];
	if (_progressIndicator.superview != controlView)
		[controlView addSubview:_progressIndicator];

	if (!highlighted)
		[self.attributes setObject:[NSColor colorWithCalibratedRed:(121. / 255.) green:(121. / 255.) blue:(121. / 255.) alpha:1.] forKey:NSForegroundColorAttributeName];
	// else don't change the color; its already white from drawing the title
	[self.attributes setObject:[[NSFontManager sharedFontManager] fontWithFamily:@"Lucida Grande" traits:0 weight:5 size:10.] forKey:NSFontAttributeName];

	[_subtitleText drawInRect:[self _subtitleCellFrameFromRect:cellFrame] withAttributes:self.attributes];
}
@end
