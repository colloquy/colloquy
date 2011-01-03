#import "CQDownloadCell.h"

// This is really a private category for methods and properties in CQTitleCell, if it is as such, the compiler throws warnings. Having it as a category for a subclass will
// cause the compiler to see that attributes is a NSMutableDictionary and not a NSDictionary and not throw any warnings.

#define CellPadding 3.

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
	_progressIndicator.style = NSProgressIndicatorBarStyle;
	_progressIndicator.minValue = 0.;
	_progressIndicator.maxValue = 1.;

	[_progressIndicator setIndeterminate:NO];
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

#pragma mark -

- (NSRect) _progressIndicatorCellFrameFromRect:(NSRect) cellFrame {
	NSRect progressRect = [self _titleCellFrameFromRect:cellFrame];

	progressRect.origin.y += (CellPadding + _progressIndicator.frame.size.height + CellPadding);
	progressRect.size.height = NSProgressIndicatorPreferredAquaThickness;

	return progressRect;
}

- (NSRect) _subtitleCellFrameFromRect:(NSRect) cellFrame {
	NSRect textRect = [self _titleCellFrameFromRect:cellFrame];
	NSRect progressRect = [self _progressIndicatorCellFrameFromRect:cellFrame];

	NSSize titleSize = [self.subtitleText sizeWithAttributes:self.attributes];
	textRect.size.height = titleSize.height;
	textRect.origin.y = progressRect.origin.y + progressRect.size.height + CellPadding;

	return textRect;
}

#pragma mark -

- (void) drawWithFrame:(NSRect) cellFrame inView:(NSView *) controlView {
	[super drawWithFrame:cellFrame inView:controlView];

	_progressIndicator.frame = [self _progressIndicatorCellFrameFromRect:cellFrame];
	if (_progressIndicator.superview != controlView)
		[controlView addSubview:_progressIndicator];

	NSRect newProgressRect = [self _progressIndicatorCellFrameFromRect:cellFrame];
	if (!NSEqualRects(newProgressRect, _progressIndicator.frame))
		_progressIndicator.frame = newProgressRect;
	BOOL highlighted = ([self isHighlighted] && controlView.window.firstResponder == controlView && [controlView.window isKeyWindow] && [[NSApplication sharedApplication] isActive]);
	if (!highlighted)
		[self.attributes setObject:[NSColor colorWithCalibratedRed:(121. / 255.) green:(121. / 255.) blue:(121. / 255.) alpha:1.] forKey:NSForegroundColorAttributeName];
	// else don't change the color; its already white from drawing the title
	[self.attributes setObject:[[NSFontManager sharedFontManager] fontWithFamily:@"Lucida Grande" traits:0 weight:5 size:10.] forKey:NSFontAttributeName];

	[_subtitleText drawInRect:[self _subtitleCellFrameFromRect:cellFrame] withAttributes:self.attributes];
}

#pragma mark -

- (void) hideProgressIndicator {
	[_progressIndicator removeFromSuperview];
}
@end
