#import "JVSidebarChatWindowController.h"
#import "JVSideSplitView.h"
#import "JVDetailCell.h"

@implementation JVSidebarChatWindowController
- (instancetype) init {
	return [self initWithWindowNibName:@"JVSidebarChatWindow"];
}

- (instancetype) initWithWindowNibName:(NSString *) windowNibName {
	if( ( self = [super initWithWindowNibName:windowNibName] ) )
		_forceSplitViewPosition = YES;
	return self;
}

- (void) windowDidLoad {
	[super windowDidLoad];

	[chatViewsOutlineView setAllowsEmptySelection:NO];

	[chatViewsOutlineView setSelectionHighlightStyle:NSTableViewSelectionHighlightStyleSourceList];

	if( ! [[NSUserDefaults standardUserDefaults] boolForKey:@"JVSidebarSelectedRowHasBlackText"] )
		[[[chatViewsOutlineView outlineTableColumn] dataCell] setBoldAndWhiteOnHighlight:YES];

	[splitView setMainSubviewIndex:1];
	[splitView setPositionUsingName:@"JVSidebarSplitViewPosition"];
}

- (CGFloat) outlineView:(NSOutlineView *) outlineView heightOfRowByItem:(id) item {
	BOOL smallIcons = ([outlineView levelForItem:item] || _usesSmallIcons);
	if( smallIcons )
		return 18.;
	return 34.;
}

- (void) outlineView:(NSOutlineView *) outlineView willDisplayCell:(id) cell forTableColumn:(NSTableColumn *) tableColumn item:(id) item {
	[super outlineView:outlineView willDisplayCell:cell forTableColumn:tableColumn item:item];

	if( [outlineView levelForItem:item] )
		[(JVDetailCell *)cell setLeftMargin:12.];
	else [(JVDetailCell *)cell setLeftMargin:0.];
}

- (CGFloat) splitView:(NSSplitView *) splitView constrainSplitPosition:(CGFloat) proposedPosition ofSubviewAt:(NSInteger) index {
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

- (CGFloat) splitView:(NSSplitView *) splitView constrainMinCoordinate:(CGFloat) proposedMin ofSubviewAt:(NSInteger) offset {
//	if( ! [[[chatViewsOutlineView enclosingScrollView] verticalScroller] isHidden] )
//		return 55. + NSWidth( [[[chatViewsOutlineView enclosingScrollView] verticalScroller] frame] );
	return 100.;
}

- (CGFloat) splitView:(NSSplitView *) splitView constrainMaxCoordinate:(CGFloat) proposedMax ofSubviewAt:(NSInteger) offset {
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
		id<JVChatViewController> lastActive = _activeViewController;
		if( [_activeViewController respondsToSelector:@selector( willUnselect )] )
			[(id<JVChatViewController>)_activeViewController willUnselect];
		if( [item respondsToSelector:@selector( willSelect )] )
			[(id<JVChatViewController>)item willSelect];

		_activeViewController = item;

		[[[bodyView subviews] lastObject] removeFromSuperview];

		NSView *newView = [_activeViewController view];
		[newView setAutoresizingMask:( NSViewWidthSizable | NSViewHeightSizable )];
		[newView setFrame:[bodyView bounds]];
		[bodyView addSubview:newView];

		[[self window] makeFirstResponder:[[_activeViewController view] nextKeyView]];

		[self _refreshToolbar];

		if( [lastActive respondsToSelector:@selector( didUnselect )] )
			[lastActive didUnselect];
		if( [_activeViewController respondsToSelector:@selector( didSelect )] )
			[_activeViewController didSelect];
	} else if( ! [_views count] || ! _activeViewController ) {
		[[[bodyView subviews] lastObject] removeFromSuperview];
		[[[self window] toolbar] setDelegate:nil];
		[[self window] setToolbar:nil];
		[[self window] makeFirstResponder:nil];
	}

	[self _refreshWindowTitle];
}
@end
