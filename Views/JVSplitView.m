#import "JVSplitView.h"
#import "NSImageAdditions.h"

@implementation JVSplitView
- (NSString *) stringWithSavedPosition {
	NSMutableString *result = [NSMutableString string];
	NSEnumerator *subviews = [[self subviews] objectEnumerator];
	NSView *subview = nil;

	while( ( subview = [subviews nextObject] ) ) {
		if( [result length] ) [result appendString:@";"];
		[result appendString:NSStringFromRect( [subview frame] )];
	}

	return result;
}

- (void) setPositionFromString:(NSString *) string {
	if( ! [string length] ) return;

	NSEnumerator *subviews = [[self subviews] objectEnumerator];
	NSEnumerator *frames = [[string componentsSeparatedByString:@";"] objectEnumerator];
	NSView *subview = nil;
	NSString *frame = nil;

	while( ( subview = [subviews nextObject] ) && ( frame = [frames nextObject] ) ) {
		NSRect rect = NSRectFromString( frame );
		if( [self isVertical] ) [subview setFrame:NSMakeRect( NSMinX( rect ), NSMinY( [subview frame] ), NSWidth( rect ), NSHeight( [subview frame] ) )];
		else [subview setFrame:NSMakeRect( NSMinX( [subview frame] ), NSMinY( rect ), NSWidth( [subview frame] ), NSHeight( rect ) )];
	}

	[self adjustSubviews];
}

- (void) savePositionUsingName:(NSString *) name {
	NSParameterAssert( name != nil );
	NSParameterAssert( [name length] > 0 );

	[[NSUserDefaults standardUserDefaults] setObject:[self stringWithSavedPosition] forKey:name];
}

- (BOOL) setPositionUsingName:(NSString *) name {
	NSParameterAssert( name != nil );
	NSParameterAssert( [name length] > 0 );

	NSString *sizes = [[NSUserDefaults standardUserDefaults] objectForKey:name];
	if( [sizes length] ) {
		[self setPositionFromString:sizes];
		return YES;
	}

	return NO;
}

#pragma amrk -

- (void) setMainSubviewIndex:(long) index {
	_mainSubviewIndex = index;
}

- (BOOL) mainSubviewIndex {
	return _mainSubviewIndex;
}

#pragma amrk -

- (void) resetCursorRects {
	if( ! [self isPaneSplitter] )
		[super resetCursorRects];
}

- (float) dividerThickness {
	if( ! [self isVertical] ) return 10.;
	return [super dividerThickness];
}

- (void) drawDividerInRect:(NSRect) rect {
	if( ! [self isVertical] ) {
		rect.origin.y += 10.;
		[[NSImage imageNamed:@"splitviewDividerBackground"] tileInRect:rect];
		if( ! [self isPaneSplitter] )
			[[NSImage imageNamed:@"splitviewDimple"] compositeToPoint:NSMakePoint( ( NSWidth( rect ) / 2. ) - 3., rect.origin.y ) operation:NSCompositeCopy];
	} else [super drawDividerInRect:rect];
}

#pragma mark -

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

	NSLog( @"%f  %@   %@", dividerThickness, NSStringFromRect( otherFrame ), NSStringFromRect( mainFrame ) );

	if( ! ( [self inLiveResize] && [self preservesContentDuringLiveResize] ) )
		[self setNeedsDisplay:YES];
}
@end