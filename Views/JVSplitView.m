#import "JVSplitView.h"
#import "NSImageAdditions.h"

@implementation JVSplitView
- (NSString *) stringWithSavedPosition {
	NSMutableString *result = [NSMutableString string];
	for( NSView *subview in [self subviews]) {
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

#pragma mark -

- (void) setMainSubviewIndex:(long) index {
	_mainSubviewIndex = index;
}

- (BOOL) mainSubviewIndex {
	return _mainSubviewIndex;
}

#pragma mark -

- (void) resetCursorRects {
	if( [self dividerStyle] != NSSplitViewDividerStylePaneSplitter )
		[super resetCursorRects];
}

- (CGFloat) dividerThickness {
	if( ! [self isVertical] ) return 10.;
	return [super dividerThickness];
}

- (void) drawDividerInRect:(NSRect) rect {
	if( ! [self isVertical] ) {
		rect.origin.y += 10.;
		[[NSImage imageNamed:@"splitviewDividerBackground"] tileInRect:rect];
		if( [self dividerStyle] != NSSplitViewDividerStylePaneSplitter )
			[[NSImage imageNamed:@"splitviewDimple"] drawAtPoint:NSMakePoint( ( NSWidth( rect ) / 2. ) - 3., rect.origin.y ) fromRect:NSZeroRect operation:NSCompositeCopy fraction:1.];
	} else [super drawDividerInRect:rect];
}
@end
