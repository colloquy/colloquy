#import "JVSideSplitView.h"

@implementation JVSideSplitView
- (id) initWithCoder:(NSCoder *) decoder {
	if( ( self = [super initWithCoder:decoder] ) )
		_mainSubviewIndex = 1;
	return self;
}

- (CGFloat) dividerThickness {
	return 1.0;
}

- (BOOL) isVertical {
    return YES;
}

- (void) drawDividerInRect:(NSRect) rect {
	[[NSColor colorWithCalibratedWhite:0.65 alpha:1.] set];
	NSRectFill( rect );
}

- (void) resizeSubviewsWithOldSize:(NSSize) oldSize {
	[self adjustSubviews];
}

- (void) adjustSubviews {
	if( _mainSubviewIndex == -1 || [[self subviews] count] != 2 ) {
		[super adjustSubviews];
		return;
	}

	float dividerThickness = [self dividerThickness];
	NSRect newFrame = [self frame];

	NSView *mainView = [[self subviews] objectAtIndex:_mainSubviewIndex];
	NSView *otherView = ( _mainSubviewIndex ? [[self subviews] objectAtIndex:0] : [[self subviews] objectAtIndex:1] );

	NSRect mainFrame = [mainView frame];
	NSRect otherFrame = [otherView frame];

	if( [self isVertical] ) {
		mainFrame.size.width = NSWidth( newFrame ) - dividerThickness - NSWidth( otherFrame );
		mainFrame.size.height = NSHeight( newFrame );
		mainFrame.origin.x = ( _mainSubviewIndex ? NSWidth( otherFrame ) + dividerThickness : 0. );
		mainFrame.origin.y = 0.;
	} else {
		mainFrame.size.width = NSWidth( newFrame );
		mainFrame.size.height = NSHeight( newFrame ) - dividerThickness - NSHeight( otherFrame );
		mainFrame.origin.x = 0.;
		mainFrame.origin.y = ( _mainSubviewIndex ? NSHeight( otherFrame ) + dividerThickness : 0. );
	}

	if( [self isVertical] ) {
		otherFrame.size.width = NSWidth( otherFrame );
		otherFrame.size.height = NSHeight( newFrame );
		otherFrame.origin.x = ( _mainSubviewIndex ? 0. : NSWidth( mainFrame ) + dividerThickness );
		otherFrame.origin.y = 0.;
	} else {
		otherFrame.size.width = NSWidth( newFrame );
		otherFrame.size.height = NSHeight( otherFrame );
		otherFrame.origin.x = 0.;
		otherFrame.origin.y = ( _mainSubviewIndex ? 0. : NSWidth( mainFrame ) + dividerThickness );
	}

	[mainView setFrame:mainFrame];
	[otherView setFrame:otherFrame];

	[self setNeedsDisplay:YES];
}
@end
