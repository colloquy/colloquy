#import <Cocoa/Cocoa.h>
#import "JVChatController.h"
#import "JVTabbedChatWindowController.h"
#import "AICustomTabsView.h"
#import "JVChatTabItem.h"

@interface JVChatWindowController (JVChatWindowControllerPrivate)
- (void) _refreshSelectionMenu;
- (void) _refreshWindow;
- (void) _refreshWindowTitle;
- (void) _refreshList;
@end

#pragma mark -

@interface AICustomTabsView (AICustomTabsViewPrivate)
- (void) smoothlyArrangeTabs;
@end

#pragma mark -

@implementation JVTabbedChatWindowController
- (id) init {
	return ( self = [self initWithWindowNibName:@"JVTabbedChatWindow"] );
}

- (id) initWithWindowNibName:(NSString *) windowNibName {
	if( ( self = [super initWithWindowNibName:windowNibName] ) ) {
		_tabItems = [[NSMutableArray array] retain];
	}
	return self;
}

- (void) windowDidLoad {
	[super windowDidLoad];

	[chatViewsOutlineView setRefusesFirstResponder:NO];
	[chatViewsOutlineView setAllowsEmptySelection:YES];

    // Remove any tabs from our tab view, it needs to start out empty
    while( [tabView numberOfTabViewItems] > 0 )
        [tabView removeTabViewItem:[tabView tabViewItemAtIndex:0]];
}

#pragma mark -

- (void) insertChatViewController:(id <JVChatViewController>) controller atIndex:(unsigned int) index {
	NSParameterAssert( controller != nil );
	NSAssert1( ! [_views containsObject:controller], @"%@ already added.", controller );
	NSAssert( index >= 0 && index <= [_views count], @"Index is beyond bounds." );
	NSAssert( index >= 0 && index <= [_tabItems count], @"Index is beyond bounds." );

	JVChatTabItem *newTab = [[[JVChatTabItem alloc] initWithChatViewController:controller] autorelease];

	[_tabItems insertObject:newTab atIndex:index];
	[tabView insertTabViewItem:newTab atIndex:index];

	[super insertChatViewController:controller atIndex:index];
}

#pragma mark -

- (void) removeChatViewController:(id <JVChatViewController>) controller {
	unsigned int index = [_views indexOfObjectIdenticalTo:controller];
	[_tabItems removeObjectAtIndex:index];
	[tabView removeTabViewItem:[tabView tabViewItemAtIndex:index]];
	[super removeChatViewController:controller];
}

- (void) removeAllChatViewControllers {
	[_tabItems removeAllObjects];
	while( [tabView numberOfTabViewItems] > 0 )
        [tabView removeTabViewItem:[tabView tabViewItemAtIndex:0]];
	[super removeAllChatViewControllers];
}

#pragma mark -

- (void) replaceChatViewControllerAtIndex:(unsigned int) index withController:(id <JVChatViewController>) controller {
	NSParameterAssert( controller != nil );
	NSAssert1( ! [_views containsObject:controller], @"%@ is already a member of this window controller.", controller );
	NSAssert( index >= 0 && index <= [_views count], @"Index is beyond bounds." );
	NSAssert( index >= 0 && index <= [_tabItems count], @"Index is beyond bounds." );

	JVChatTabItem *newTab = [[[JVChatTabItem alloc] initWithChatViewController:controller] autorelease];

	[_tabItems replaceObjectAtIndex:index withObject:newTab];
	[tabView removeTabViewItem:[tabView tabViewItemAtIndex:index]];
	[tabView insertTabViewItem:newTab atIndex:index];

	[super replaceChatViewControllerAtIndex:index withController:controller];
}

#pragma mark -

- (void) showChatViewController:(id <JVChatViewController>) controller {
	NSAssert1( [_views containsObject:controller], @"%@ is not a member of this window controller.", controller );

	unsigned int index = [_views indexOfObjectIdenticalTo:controller];
	[tabView selectTabViewItemAtIndex:index];

	[self _refreshWindow];
	[self _refreshList];
}

- (void) reloadListItem:(id <JVChatListItem>) item andChildren:(BOOL) children {
	if( item == _activeViewController ) {
		[customTabsView smoothlyArrangeTabs];
		[customTabsView resetCursorTracking];
//		[customTabsView redisplayTabForTabViewItem:[tabView selectedTabViewItem]];
		[self _refreshList];
		[self _refreshWindowTitle];
	} else if( [_views containsObject:item] ) {
		[customTabsView smoothlyArrangeTabs];
		[customTabsView resetCursorTracking];
//		[customTabsView redisplayTabForTabViewItem:[tabView tabViewItemAtIndex:[_views indexOfObjectIdenticalTo:item]]];
	} else {
		[chatViewsOutlineView reloadItem:item reloadChildren:( children && [chatViewsOutlineView isItemExpanded:item] ? YES : NO )];
		[chatViewsOutlineView sizeLastColumnToFit];
		if( item == [self selectedListItem] )
			[self _refreshSelectionMenu];
	}
}

#pragma mark -

- (id <JVInspection>) objectToInspect {
	if( [[chatViewsOutlineView window] firstResponder] == chatViewsOutlineView )
		return [super objectToInspect];
	if( [_activeViewController conformsToProtocol:@protocol( JVInspection )] )
		return (id <JVInspection>)_activeViewController;
	return nil;
}

- (IBAction) getInfo:(id) sender {
	if( [[chatViewsOutlineView window] firstResponder] == chatViewsOutlineView ) {
		[super getInfo:sender];
	} else if( [_activeViewController conformsToProtocol:@protocol( JVInspection )] && [_activeViewController conformsToProtocol:@protocol( JVInspection )] ) {
		if( [[[NSApplication sharedApplication] currentEvent] modifierFlags] & NSAlternateKeyMask )
			[JVInspectorController showInspector:_activeViewController];
		else [[JVInspectorController inspectorOfObject:(id <JVInspection>)_activeViewController] show:sender];
	}
}

#pragma mark -

- (void) customTabView:(AICustomTabsView *) view didSelectTabViewItem:(NSTabViewItem *) tabViewItem {
	if( tabViewItem ) {
		[self _refreshWindow];
		[self _refreshList];
	}
}

- (void) customTabViewDidChangeOrderOfTabViewItems:(AICustomTabsView *) view {
	[_views removeAllObjects];

	NSEnumerator *tabs = [[tabView tabViewItems] objectEnumerator];
	JVChatTabItem *tab = nil;
	while( ( tab = [tabs nextObject] ) )
		[_views addObject:[tab chatViewController]];
}

- (void) customTabView:(AICustomTabsView *) view closeTabViewItem:(NSTabViewItem *) tabViewItem {
	[[JVChatController defaultManager] disposeViewController:[(JVChatTabItem *)tabViewItem chatViewController]];
}

- (void) customTabView:(AICustomTabsView *) view didMoveTabViewItem:(NSTabViewItem *) tabViewItem toCustomTabView:(AICustomTabsView *) destTabView index:(int) index screenPoint:(NSPoint) screenPoint {
	id chatController = [(JVChatTabItem *)tabViewItem chatViewController];
	id oldWindowController = [chatController windowController];
	id newWindowController = [[destTabView window] windowController];

	if( oldWindowController != newWindowController ) {
		[chatController retain];
		[[chatController windowController] removeChatViewController:chatController];

		if( ! newWindowController ) {
			NSRect newFrame;
			newWindowController = [[JVChatController defaultManager] newChatWindowController];
			newFrame.origin = screenPoint;
			newFrame.size = [[oldWindowController window] frame].size;
			[[newWindowController window] setFrame:newFrame display:NO];
		}

		if( index > 0 ) [newWindowController insertChatViewController:chatController atIndex:index];
		else [newWindowController addChatViewController:chatController];
		[chatController release];
	}
}

- (NSMenu *) customTabView:(AICustomTabsView *) view menuForTabViewItem:(NSTabViewItem *) tabViewItem {
	[[self window] makeFirstResponder:[[_activeViewController view] nextKeyView]];
	return [[(JVChatTabItem *)tabViewItem chatViewController] menu];
}

#pragma mark -

- (int) outlineView:(NSOutlineView *) outlineView numberOfChildrenOfItem:(id) item {
	if( item && [item respondsToSelector:@selector( numberOfChildren )] ) return [item numberOfChildren];
	else if( [_activeViewController respondsToSelector:@selector( numberOfChildren )] ) return [(id)_activeViewController numberOfChildren];
	else return 0;
}

- (id) outlineView:(NSOutlineView *) outlineView child:(int) index ofItem:(id) item {
	if( item ) {
		if( [item respondsToSelector:@selector( childAtIndex: )] )
			return [item childAtIndex:index];
		else return nil;
	} else return [(id)_activeViewController childAtIndex:index];
}

- (id) outlineView:(NSOutlineView *) outlineView objectValueForTableColumn:(NSTableColumn *) tableColumn byItem:(id) item {
	NSImage *ret = [[[item icon] copy] autorelease];
	[ret setScalesWhenResized:YES];
	[ret setSize:NSMakeSize( 16., 16. )];
	return ret;
}

- (BOOL) outlineView:(NSOutlineView *) outlineView shouldCollapseItem:(id) item {
	return YES;
}

- (int) outlineView:(NSOutlineView *) outlineView heightOfRow:(int) row {
	return 18;
}
@end

#pragma mark -

@implementation JVTabbedChatWindowController (JVTabbedChatWindowControllerPrivate)
- (void) _refreshList {
	[super _refreshList];
	[customTabsView smoothlyArrangeTabs];
	[customTabsView resetCursorTracking];
}

- (void) _refreshWindow {
	id item = [(JVChatTabItem *)[tabView selectedTabViewItem] chatViewController];

	if( ( [item conformsToProtocol:@protocol( JVChatViewController )] && item != (id) _activeViewController ) || ( ! _activeViewController && [[item parent] conformsToProtocol:@protocol( JVChatViewController )] && ( item = [item parent] ) ) ) {
		id lastActive = _activeViewController;
		if( [_activeViewController respondsToSelector:@selector( willUnselect )] )
			[(NSObject *)_activeViewController willUnselect];
		if( [item respondsToSelector:@selector( willSelect )] )
			[(NSObject *)item willSelect];

		[_activeViewController autorelease];
		_activeViewController = [item retain];

		[[self window] setToolbar:[_activeViewController toolbar]];
		[[self window] makeFirstResponder:[[_activeViewController view] nextKeyView]];

		if( [lastActive respondsToSelector:@selector( didUnselect )] )
			[(NSObject *)lastActive didUnselect];
		if( [_activeViewController respondsToSelector:@selector( didSelect )] )
			[(NSObject *)_activeViewController didSelect];
	} else if( ! [_views count] || ! _activeViewController ) {
		[[self window] setContentView:_placeHolder];
		[[[self window] toolbar] setDelegate:nil];
		[[self window] setToolbar:nil];
		[[self window] makeFirstResponder:nil];
	}

	[self _refreshWindowTitle];
}
@end