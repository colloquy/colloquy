#import "JVSidebarChatWindowController.h"
#import "JVSideSplitView.h"

@interface JVChatWindowController (JVChatWindowControllerPrivate)
- (void) _claimMenuCommands;
- (void) _resignMenuCommands;
- (void) _refreshSelectionMenu;
- (void) _refreshWindow;
- (void) _refreshWindowTitle;
- (void) _refreshList;
- (void) _refreshPreferences;
@end

#pragma mark -

@implementation JVSidebarChatWindowController
- (id) init {
	return ( self = [self initWithWindowNibName:@"JVSidebarChatWindow"] );
}

- (id) initWithWindowNibName:(NSString *) windowNibName {
	if( ( self = [super initWithWindowNibName:windowNibName] ) ) {
		_forceSplitViewPosition = YES;
	}

	return self;
}

- (void) windowDidLoad {
	[super windowDidLoad];

	NSRect sideFrame = [sideView frame];
	_sideWidth = sideFrame.size.width;

	[chatViewsOutlineView setAllowsEmptySelection:NO];

	[splitView adjustSubviews];
	[splitView setPositionUsingName:@"JVSidebarSplitViewPosition"];
}

- (float) outlineView:(NSOutlineView *) outlineView heightOfRowByItem:(id) item {
	return ( [outlineView levelForItem:item] || _usesSmallIcons ? 16. : 34. );
}

- (void) splitViewDidResizeSubviews:(NSNotification *) notification {
	// Cache the height of the send box so we can keep it constant during window resizes.
	NSRect sideFrame = [sideView frame];
	_sideWidth = sideFrame.size.width;

	if( ! _forceSplitViewPosition )
		[splitView savePositionUsingName:@"JVSidebarSplitViewPosition"];

	_forceSplitViewPosition = NO;
}

- (void) splitView:(NSSplitView *) sender resizeSubviewsWithOldSize:(NSSize) oldSize {
	float dividerThickness = [sender dividerThickness];
	NSRect newFrame = [sender frame];

	// Keep the size of the send box constant during window resizes

	// We need to resize the scroll view frames of the webview and the textview.
	// The scroll views are two superviews up: NSTextView(WebView) -> NSClipView -> NSScrollView
	NSRect sideFrame = [sideView frame];
	NSRect bodyFrame = [bodyView frame];

	// Set size of the web view to the maximum size possible
	bodyFrame.size.height = NSHeight( newFrame );
	bodyFrame.size.width = NSWidth( newFrame ) - dividerThickness - _sideWidth;
	bodyFrame.origin.x = _sideWidth + dividerThickness;

	// Keep the send box the same size
	sideFrame.size.height = NSHeight( newFrame );
	sideFrame.size.width = _sideWidth;

	// Commit the changes
	[sideView setFrame:sideFrame];
	[bodyView setFrame:bodyFrame];
}

- (float) splitView:(NSSplitView *) sender constrainMinCoordinate:(float) proposedMin ofSubviewAt:(int) offset {
	if( ! [[[chatViewsOutlineView enclosingScrollView] verticalScroller] isHidden] )
		return 55. + NSWidth( [[[chatViewsOutlineView enclosingScrollView] verticalScroller] frame] );
	return 55.;
}

- (float) splitView:(NSSplitView *) sender constrainMaxCoordinate:(float) proposedMax ofSubviewAt:(int) offset {
	return 300.;
}

- (NSToolbarItem *) toggleChatDrawerToolbarItem {
	return nil;
}

- (void) _refreshWindow {
	[[self window] disableFlushWindow];

	id item = [self selectedListItem];
	if( ! item ) goto end;

	if( ( [item conformsToProtocol:@protocol( JVChatViewController )] && item != (id) _activeViewController ) || ( ! _activeViewController && [[item parent] conformsToProtocol:@protocol( JVChatViewController )] && ( item = [item parent] ) ) ) {
		id lastActive = _activeViewController;
		if( [_activeViewController respondsToSelector:@selector( willUnselect )] )
			[(NSObject *)_activeViewController willUnselect];
		if( [item respondsToSelector:@selector( willSelect )] )
			[(NSObject *)item willSelect];

		[_activeViewController autorelease];
		_activeViewController = [item retain];

		[[[bodyView subviews] lastObject] removeFromSuperview];

		NSView *newView = [_activeViewController view];
		[newView setAutoresizingMask:( NSViewWidthSizable | NSViewHeightSizable )];
		[newView setFrame:[bodyView bounds]];
		[bodyView addSubview:newView];

		[[self window] setToolbar:[_activeViewController toolbar]];
		[[self window] makeFirstResponder:[[_activeViewController view] nextKeyView]];

		if( [lastActive respondsToSelector:@selector( didUnselect )] )
			[(NSObject *)lastActive didUnselect];
		if( [_activeViewController respondsToSelector:@selector( didSelect )] )
			[(NSObject *)_activeViewController didSelect];
	} else if( ! [_views count] || ! _activeViewController ) {
		[[[bodyView subviews] lastObject] removeFromSuperview];
		[[[self window] toolbar] setDelegate:nil];
		[[self window] setToolbar:nil];
		[[self window] makeFirstResponder:nil];
	}

	[self _refreshWindowTitle];

end:
	[[self window] enableFlushWindow];
	[[self window] displayIfNeeded];
}
@end
