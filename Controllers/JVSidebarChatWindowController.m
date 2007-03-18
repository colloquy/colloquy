#import "JVSidebarChatWindowController.h"
#import "JVSideSplitView.h"
#import "JVDetailCell.h"

@interface JVChatWindowController (JVChatWindowControllerPrivate)
- (void) _refreshToolbar;
- (void) _refreshWindowTitle;
@end

#pragma mark -

@implementation JVSidebarChatWindowController
- (id) init {
	return ( self = [self initWithWindowNibName:@"JVSidebarChatWindow"] );
}

- (id) initWithWindowNibName:(NSString *) windowNibName {
	if( ( self = [super initWithWindowNibName:windowNibName] ) )
		_forceSplitViewPosition = YES;
	return self;
}

- (void) windowDidLoad {
	[super windowDidLoad];

	[chatViewsOutlineView setAllowsEmptySelection:NO];

	if( ! [[NSUserDefaults standardUserDefaults] boolForKey:@"JVSidebarSelectedRowHasBlackText"] )
		[[[chatViewsOutlineView outlineTableColumn] dataCell] setBoldAndWhiteOnHighlight:YES];

	[splitView setMainSubviewIndex:1];
	[splitView setPositionUsingName:@"JVSidebarSplitViewPosition"];
}

- (float) outlineView:(NSOutlineView *) outlineView heightOfRowByItem:(id) item {
	return ( [outlineView levelForItem:item] || _usesSmallIcons ? 16. : 34. );
}

- (float) splitView:(NSSplitView *) splitView constrainSplitPosition:(float) proposedPosition ofSubviewAt:(int) index {
	// don't do anything here
	return proposedPosition;
}

- (void) splitViewWillResizeSubviews:(NSNotification *) notification {
	// don't do anything here
}

- (void) splitViewDidResizeSubviews:(NSNotification *) notification {
	if( ! _forceSplitViewPosition )
		[splitView savePositionUsingName:@"JVSidebarSplitViewPosition"];
	_forceSplitViewPosition = NO;
}

- (float) splitView:(NSSplitView *) splitView constrainMinCoordinate:(float) proposedMin ofSubviewAt:(int) offset {
//	if( ! [[[chatViewsOutlineView enclosingScrollView] verticalScroller] isHidden] )
//		return 55. + NSWidth( [[[chatViewsOutlineView enclosingScrollView] verticalScroller] frame] );
	return 100.;
}

- (float) splitView:(NSSplitView *) splitView constrainMaxCoordinate:(float) proposedMax ofSubviewAt:(int) offset {
	return 300.;
}

- (BOOL) splitView:(NSSplitView *) splitView canCollapseSubview:(NSView *) subview {
	return NO;
}

- (NSToolbarItem *) toggleChatDrawerToolbarItem {
	return nil;
}

- (void) _refreshWindow {
	id item = [self selectedListItem];
	if( ! item ) return;

	if( ( [item conformsToProtocol:@protocol( JVChatViewController )] && item != (id) _activeViewController ) || ( ! _activeViewController && [[item parent] conformsToProtocol:@protocol( JVChatViewController )] && ( item = [item parent] ) ) ) {
		id lastActive = _activeViewController;
		if( [_activeViewController respondsToSelector:@selector( willUnselect )] )
			[(NSObject *)_activeViewController willUnselect];
		if( [item respondsToSelector:@selector( willSelect )] )
			[(NSObject *)item willSelect];

		id old = _activeViewController;
		_activeViewController = [item retain];
		[old release];

		[[[bodyView subviews] lastObject] removeFromSuperview];

		NSView *newView = [_activeViewController view];
		[newView setAutoresizingMask:( NSViewWidthSizable | NSViewHeightSizable )];
		[newView setFrame:[bodyView bounds]];
		[bodyView addSubview:newView];

		[[self window] makeFirstResponder:[[_activeViewController view] nextKeyView]];

		[self _refreshToolbar];

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
}
@end
