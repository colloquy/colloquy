#import "JVChatController.h"
#import "JVTabbedChatWindowController.h"
#import "MVApplicationController.h"
#import "AICustomTabsView.h"
#import "JVChatTabItem.h"
#import "MVApplicationController.h"

@interface JVTabbedChatWindowController (JVTabbedChatWindowControllerPrivate)
- (void) _supressTabBarHiding:(BOOL) supress;
- (void) _resizeTabBarTimer:(NSTimer *) inTimer;
- (BOOL) _resizeTabBarAbsolute:(BOOL) absolute;
@end

#pragma mark -

@implementation JVTabbedChatWindowController
- (instancetype) init {
	return [self initWithWindowNibName:@"JVTabbedChatWindow"];
}

- (instancetype) initWithWindowNibName:(NSString *) windowNibName {
	if( ( self = [super initWithWindowNibName:windowNibName] ) ) {
		_tabItems = [NSMutableArray array];
		_tabIsShowing = YES;
		_supressHiding = NO;
		_autoHideTabBar = YES;
		_forceTabBarVisible = -1;
	}
	return self;
}

- (void) windowDidLoad {
	_tabHeight = NSHeight( [customTabsView frame] );

	// Remove any tabs from our tab view, it needs to start out empty
	while( [tabView numberOfTabViewItems] > 0 )
		[tabView removeTabViewItem:[tabView tabViewItemAtIndex:0]];

	[super windowDidLoad];

	[chatViewsOutlineView setRefusesFirstResponder:NO];
	[chatViewsOutlineView setAllowsEmptySelection:YES];

	[[self window] registerForDraggedTypes:@[TAB_CELL_IDENTIFIER]];
}

#pragma mark -

- (void) insertChatViewController:(id <JVChatViewController>) controller atIndex:(NSUInteger) index {
	NSParameterAssert( controller != nil );
	NSAssert1( ! [_views containsObject:controller], @"%@ already added.", controller );
	NSAssert( index <= [_views count], @"Index is beyond bounds." );
	NSAssert( index <= [_tabItems count], @"Index is beyond bounds." );

	[super insertChatViewController:controller atIndex:index];

	JVChatTabItem *newTab = [[JVChatTabItem alloc] initWithChatViewController:controller];

	[_tabItems insertObject:newTab atIndex:index];
	[tabView insertTabViewItem:newTab atIndex:index];
}

#pragma mark -

- (void) removeChatViewController:(id <JVChatViewController>) controller {
	NSUInteger index = [_views indexOfObjectIdenticalTo:controller];
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

- (void) replaceChatViewControllerAtIndex:(NSUInteger) index withController:(id <JVChatViewController>) controller {
	NSParameterAssert( controller != nil );
	NSAssert1( ! [_views containsObject:controller], @"%@ is already a member of this window controller.", controller );
	NSAssert( index <= [_views count], @"Index is beyond bounds." );
	NSAssert( index <= [_tabItems count], @"Index is beyond bounds." );

	JVChatTabItem *newTab = [[JVChatTabItem alloc] initWithChatViewController:controller];

	_tabItems[index] = newTab;
	[tabView removeTabViewItem:[tabView tabViewItemAtIndex:index]];
	[tabView insertTabViewItem:newTab atIndex:index];

	[super replaceChatViewControllerAtIndex:index withController:controller];
}

#pragma mark -

- (void) showChatViewController:(id <JVChatViewController>) controller {
	NSAssert1( [_views containsObject:controller], @"%@ is not a member of this window controller.", controller );

	NSUInteger index = [_views indexOfObjectIdenticalTo:controller];
	[tabView selectTabViewItemAtIndex:index];

	// [self _refreshWindow] is called in the customTabView:didSelectTabViewItem:
}

- (void) reloadListItem:(id <JVChatListItem>) item andChildren:(BOOL) children {
	if( item == _activeViewController ) {
		[customTabsView resizeTabForTabViewItem:[tabView selectedTabViewItem]];
		[self _refreshList];
		[self _refreshWindowTitle];
	} else if( [_views containsObject:item] ) {
		[customTabsView resizeTabForTabViewItem:[tabView tabViewItemAtIndex:[_views indexOfObjectIdenticalTo:item]]];
	} else {
		id selectItem = [self selectedListItem];

		[chatViewsOutlineView reloadItem:item reloadChildren:( children && [chatViewsOutlineView isItemExpanded:item] ? YES : NO )];
		[chatViewsOutlineView sizeLastColumnToFit];

		if( item == selectItem )
			[self _deferRefreshSelectionMenu];

		if( selectItem )
			[chatViewsOutlineView selectRowIndexes:[NSIndexSet indexSetWithIndex:[chatViewsOutlineView rowForItem:selectItem]] byExtendingSelection:NO];
	}
}

- (IBAction) openViewsDrawer:(id) sender {
	[super openViewsDrawer:sender];

	if( [_activeViewController respondsToSelector:@selector( setPreference:forKey: )] )
		[(id)_activeViewController setPreference:@YES forKey:@"expanded"];
}

- (IBAction) closeViewsDrawer:(id) sender {
	[super closeViewsDrawer:sender];

	if( [_activeViewController respondsToSelector:@selector( setPreference:forKey: )] )
		[(id)_activeViewController setPreference:@NO forKey:@"expanded"];
}

#pragma mark -

- (id <JVInspection>) objectToInspect {
	if( [chatViewsOutlineView numberOfSelectedRows] && [[chatViewsOutlineView window] firstResponder] == chatViewsOutlineView )
		return [super objectToInspect];
	else if( [_activeViewController conformsToProtocol:@protocol( JVInspection )] )
		return (id <JVInspection>)_activeViewController;
	return nil;
}

- (IBAction) getInfo:(id) sender {
	if( [chatViewsOutlineView numberOfSelectedRows] && [[chatViewsOutlineView window] firstResponder] == chatViewsOutlineView ) {
		[super getInfo:sender];
	} else if( [_activeViewController conformsToProtocol:@protocol( JVInspection )] ) {
		if( [[[NSApplication sharedApplication] currentEvent] modifierFlags] & NSAlternateKeyMask )
			[JVInspectorController showInspector:_activeViewController];
		else [[JVInspectorController inspectorOfObject:(id <JVInspection>)_activeViewController] show:sender];
	}
}

#pragma mark -

- (BOOL) validateMenuItem:(NSMenuItem *) menuItem {
	if( [menuItem action] == @selector( toggleSmallDrawerIcons: ) ) {
		[menuItem setState:NSOnState];
		return NO;
	} else if( [menuItem action] == @selector( toggleTabBarVisible: ) ) {
		if( ! _tabIsShowing ) {
			[menuItem setTitle:NSLocalizedString( @"Show Tab Bar", "show tab bar menu title" )];
		} else {
			[menuItem setTitle:NSLocalizedString( @"Hide Tab Bar", "hide tab bar menu title" )];
		}
		return YES;
	} else if( [menuItem action] == @selector( getInfo: ) ) {
		if( [chatViewsOutlineView numberOfSelectedRows] && [[chatViewsOutlineView window] firstResponder] == chatViewsOutlineView ) return [super validateMenuItem:menuItem];
		else if( [_activeViewController conformsToProtocol:@protocol( JVInspection )] ) return YES;
		else return NO;
	}
	return [super validateMenuItem:menuItem];
}

#pragma mark -

- (void) customTabView:(AICustomTabsView *) view didSelectTabViewItem:(NSTabViewItem *) tabViewItem {
	if( tabViewItem ) {
		[self _refreshWindow];
		[self _refreshList];
		[self _deferRefreshSelectionMenu];

		id controller = [(JVChatTabItem *)tabViewItem chatViewController];
		if( [controller respondsToSelector:@selector( preferenceForKey: )] && [controller preferenceForKey:@"expanded"] ) {
			BOOL expanded = [[controller preferenceForKey:@"expanded"] boolValue];
			if( expanded ) [self openViewsDrawer:nil];
			else [self closeViewsDrawer:nil];
		}
	}
}

- (void) customTabViewDidChangeNumberOfTabViewItems:(AICustomTabsView *) view {
	[self updateTabBarVisibilityAndAnimate:NO];
}

- (void) customTabViewDidChangeOrderOfTabViewItems:(AICustomTabsView *) view {
	[_views removeAllObjects];

	for( JVChatTabItem *tab in [tabView tabViewItems] )
		[_views addObject:[tab chatViewController]];
}

- (void) customTabView:(AICustomTabsView *) view closeTabViewItem:(NSTabViewItem *) tabViewItem {
	[[JVChatController defaultController] disposeViewController:[(JVChatTabItem *)tabViewItem chatViewController]];
}

- (void) customTabView:(AICustomTabsView *) view didMoveTabViewItem:(NSTabViewItem *) tabViewItem toCustomTabView:(AICustomTabsView *) destTabView index:(NSInteger) index screenPoint:(NSPoint) screenPoint {
	id <JVChatViewController> chatController = [(JVChatTabItem *)tabViewItem chatViewController];
	id oldWindowController = [chatController windowController];
	id newWindowController = [[destTabView window] windowController];

	// check if we are dragging the only view from a window, if so just move the original window
	if( ! newWindowController && [[oldWindowController allChatViewControllers] count] == 1 ) {
		NSRect newFrame = [[oldWindowController window] frame];
		newFrame.origin = screenPoint;
		[[oldWindowController window] setFrame:newFrame display:NO];
		[[oldWindowController window] setAlphaValue:1.];
		[self _supressTabBarHiding:NO];
		return;
	}

	if( oldWindowController != newWindowController ) {
		if( ! newWindowController ) { // need to make a new window
			NSRect newFrame;
			newWindowController = [[JVChatController defaultController] createChatWindowController];
			newFrame.origin = screenPoint;
			newFrame.size = [[oldWindowController window] frame].size;

			NSToolbar *toolbar = [[oldWindowController window] toolbar];
			if( toolbar && [toolbar isVisible] ) {
				NSWindow *window = [oldWindowController window];
				NSRect windowFrame = [NSWindow contentRectForFrameRect:[window frame] styleMask:[window styleMask]];
				newFrame.size.height -= NSHeight( windowFrame ) - NSHeight( [[window contentView] frame] );
			}

			[[newWindowController window] setFrame:newFrame display:NO];
			[[newWindowController window] saveFrameUsingName:[NSString stringWithFormat:@"Chat Window %@", [chatController identifier]]];
		}

		[[chatController windowController] removeChatViewController:chatController];

		if( index > 0 ) [newWindowController insertChatViewController:chatController atIndex:index];
		else [newWindowController addChatViewController:chatController];
	}

	[self _supressTabBarHiding:NO];
}

- (NSMenu *) customTabView:(AICustomTabsView *) view menuForTabViewItem:(NSTabViewItem *) tabViewItem {
	if( [[(JVChatTabItem *)tabViewItem chatViewController] respondsToSelector:@selector( menu )] ) {
		[[self window] makeFirstResponder:[[_activeViewController view] nextKeyView]];
		id object = [(JVChatTabItem *)tabViewItem chatViewController];
		NSMenu *menu = [object menu];

		NSMethodSignature *signature = [NSMethodSignature methodSignatureWithReturnAndArgumentTypes:@encode( NSArray * ), @encode( id ), @encode( id ), nil];
		NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];

		[invocation setSelector:@selector( contextualMenuItemsForObject:inView: )];
		MVAddUnsafeUnretainedAddress(object, 2);
		MVAddUnsafeUnretainedAddress(object, 3);

		NSArray *results = [[MVChatPluginManager defaultManager] makePluginsPerformInvocation:invocation];
		if( [results count] ) {
			if( [menu numberOfItems ] && ! [[[menu itemArray] lastObject] isSeparatorItem] )
				[menu addItem:[NSMenuItem separatorItem]];

			for( NSArray *items in results ) {
				if( ![items conformsToProtocol:@protocol(NSFastEnumeration)] ) continue;

				for( NSMenuItem *item in items ) 
					if( [item isKindOfClass:[NSMenuItem class]] )
						[menu addItem:item];
			}

			if( [[[menu itemArray] lastObject] isSeparatorItem] )
				[menu removeItem:[[menu itemArray] lastObject]];
		}

		return menu;
	}

	return nil;
}

- (NSString *) customTabView:(AICustomTabsView *) view toolTipForTabViewItem:(NSTabViewItem *) tabViewItem {
	if( [[(JVChatTabItem *)tabViewItem chatViewController] respondsToSelector:@selector( toolTip )] )
		return [(id<JVChatViewController>)[(JVChatTabItem *)tabViewItem chatViewController] toolTip];
	return nil;
}

- (NSArray *) customTabViewAcceptableDragTypes:(AICustomTabsView *) tabsView {
	return @[NSFilenamesPboardType];
}

- (BOOL) customTabView:(AICustomTabsView *) tabsView didAcceptDragPasteboard:(NSPasteboard *) pasteboard onTabViewItem:(NSTabViewItem *) tabViewItem {
	if( ! [[(JVChatTabItem *)tabViewItem chatViewController] respondsToSelector:@selector( acceptsDraggedFileOfType: )] ) return NO;

	NSArray *files = [pasteboard propertyListForType:NSFilenamesPboardType];
	BOOL accepted = NO;

	for( id file in files ) {
		if( [(id<JVChatViewController>)[(JVChatTabItem *)tabViewItem chatViewController] acceptsDraggedFileOfType:[file pathExtension]] ) {
			[(id<JVChatViewController>)[(JVChatTabItem *)tabViewItem chatViewController] handleDraggedFile:file];
			accepted = YES;
		}
	}

	return accepted;
}

#pragma mark -

- (NSInteger) outlineView:(NSOutlineView *) outlineView numberOfChildrenOfItem:(id) item {
	if( item && [item respondsToSelector:@selector( numberOfChildren )] ) return [item numberOfChildren];
	else if( [_activeViewController respondsToSelector:@selector( numberOfChildren )] ) return [(id)_activeViewController numberOfChildren];
	else return 0;
}

- (id) outlineView:(NSOutlineView *) outlineView child:(NSInteger) index ofItem:(id) item {
	if( item ) {
		if( [item respondsToSelector:@selector( childAtIndex: )] )
			return [item childAtIndex:index];
		else return nil;
	}

	if( [_activeViewController respondsToSelector:@selector( childAtIndex: )] )
		return [(id)_activeViewController childAtIndex:index];
	return nil;
}

- (id) outlineView:(NSOutlineView *) outlineView objectValueForTableColumn:(NSTableColumn *) tableColumn byItem:(id) item {
	NSImage *ret = [[item icon] copy];
	[ret setSize:NSMakeSize( 16., 16. )];
	return ret;
}

- (BOOL) outlineView:(NSOutlineView *) outlineView shouldCollapseItem:(id) item {
	return YES;
}

- (int) outlineView:(NSOutlineView *) outlineView heightOfRow:(int) row {
	return 16;
}

#pragma mark -

- (void) windowDidResize:(NSNotification *) notification {
	[super windowDidResize:notification];
	[customTabsView resetCursorTracking];
}

#pragma mark -
#pragma mark Tab Bar Visibility toggle

// Toggles whether we should hide or show the tab bar
- (IBAction) toggleTabBarVisible:(id) sender {
	if( _forceTabBarVisible < 0 ) {
		if( _tabIsShowing ) _forceTabBarVisible = 0;
		else _forceTabBarVisible = 1;
	} else if( ! _forceTabBarVisible ) _forceTabBarVisible = 1;
	else if( _forceTabBarVisible > 0 ) _forceTabBarVisible = 0;

	if( ! [[NSUserDefaults standardUserDefaults] boolForKey:@"JVTabBarAlwaysVisible"] )
		[self setPreference:( _forceTabBarVisible == 1 ? @1UL : nil ) forKey:@"tab bar visible"];
	else [self setPreference:@(_forceTabBarVisible) forKey:@"tab bar visible"];

	[self updateTabBarVisibilityAndAnimate:NO];
}

// Update the visibility of our tab bar (tab bar is visible if there are 2 or more tabs present)
- (void) updateTabBarVisibilityAndAnimate:(BOOL) animate {
	if( tabView ) { // Ignore if our tabs haven't loaded yet
		BOOL shouldShowTabs = ( _supressHiding || ! _autoHideTabBar || ( [tabView numberOfTabViewItems] > 1 ) );

		if( _forceTabBarVisible != -1 ) shouldShowTabs = ( _forceTabBarVisible || _supressHiding );

		if( shouldShowTabs != _tabIsShowing ) {
			_tabIsShowing = shouldShowTabs;
			if( animate ) [self _resizeTabBarTimer:nil];
			else [self _resizeTabBarAbsolute:YES];
		}
	}
}

// Drag entered, enable suppression
- (NSDragOperation) draggingEntered:(id <NSDraggingInfo>) sender {
	NSString *type = [[sender draggingPasteboard] availableTypeFromArray:@[TAB_CELL_IDENTIFIER]];
	NSDragOperation	operation = NSDragOperationNone;

	if( ! sender || type ) {
		[self _supressTabBarHiding:YES]; // show the tab bar
		if( ! [[self window] isKeyWindow] ) [[self window] makeKeyAndOrderFront:nil]; // bring our window to the front
		operation = NSDragOperationPrivate;
	}

	return operation;
}

// Drag exited, disable suppression
- (void) draggingExited:(id <NSDraggingInfo>) sender {
	NSString *type = [[sender draggingPasteboard] availableTypeFromArray:@[TAB_CELL_IDENTIFIER]];
	if( ! sender || type ) [self _supressTabBarHiding:NO]; // hide the tab bar
}
@end

#pragma mark -

@implementation JVTabbedChatWindowController (JVTabbedChatWindowControllerPrivate)
- (void) _claimMenuCommands {
	[super _claimMenuCommands];

	unichar left = NSLeftArrowFunctionKey;
	unichar right = NSRightArrowFunctionKey;

	NSMenu *windowMenu = [[[[NSApplication sharedApplication] mainMenu] itemWithTag:5] submenu];
	NSInteger index = [windowMenu indexOfItemWithTarget:nil andAction:@selector( selectPreviousPanel: )];
	id item = [windowMenu itemAtIndex:index];
	[item setKeyEquivalent:[NSString stringWithCharacters:&left length:1]];

	windowMenu = [[[[NSApplication sharedApplication] mainMenu] itemWithTag:5] submenu];
	index = [windowMenu indexOfItemWithTarget:nil andAction:@selector( selectPreviousActivePanel: )];
	item = [windowMenu itemAtIndex:index];
	[item setKeyEquivalent:[NSString stringWithCharacters:&left length:1]];

	windowMenu = [[[[NSApplication sharedApplication] mainMenu] itemWithTag:5] submenu];
	index = [windowMenu indexOfItemWithTarget:nil andAction:@selector( selectNextPanel: )];
	item = [windowMenu itemAtIndex:index];
	[item setKeyEquivalent:[NSString stringWithCharacters:&right length:1]];

	windowMenu = [[[[NSApplication sharedApplication] mainMenu] itemWithTag:5] submenu];
	index = [windowMenu indexOfItemWithTarget:nil andAction:@selector( selectNextActivePanel: )];
	item = [windowMenu itemAtIndex:index];
	[item setKeyEquivalent:[NSString stringWithCharacters:&right length:1]];
}

- (void) _resignMenuCommands {
	[super _resignMenuCommands];

	unichar up = NSUpArrowFunctionKey;
	unichar down = NSDownArrowFunctionKey;

	NSMenu *windowMenu = [[[[NSApplication sharedApplication] mainMenu] itemWithTag:5] submenu];
	NSInteger index = [windowMenu indexOfItemWithTarget:nil andAction:@selector( selectPreviousPanel: )];
	id item = [windowMenu itemAtIndex:index];
	[item setKeyEquivalent:[NSString stringWithCharacters:&up length:1]];

	windowMenu = [[[[NSApplication sharedApplication] mainMenu] itemWithTag:5] submenu];
	index = [windowMenu indexOfItemWithTarget:nil andAction:@selector( selectPreviousActivePanel: )];
	item = [windowMenu itemAtIndex:index];
	[item setKeyEquivalent:[NSString stringWithCharacters:&up length:1]];

	windowMenu = [[[[NSApplication sharedApplication] mainMenu] itemWithTag:5] submenu];
	index = [windowMenu indexOfItemWithTarget:nil andAction:@selector( selectNextPanel: )];
	item = [windowMenu itemAtIndex:index];
	[item setKeyEquivalent:[NSString stringWithCharacters:&down length:1]];

	windowMenu = [[[[NSApplication sharedApplication] mainMenu] itemWithTag:5] submenu];
	index = [windowMenu indexOfItemWithTarget:nil andAction:@selector( selectNextActivePanel: )];
	item = [windowMenu itemAtIndex:index];
	[item setKeyEquivalent:[NSString stringWithCharacters:&down length:1]];
}

- (void) _supressTabBarHiding:(BOOL) supress {
	_supressHiding = supress; // temporarily suppress bar hiding
	[self updateTabBarVisibilityAndAnimate:NO];
}

// Smoothly resize the tab bar (calls itself with a timer until the tabbar is correctly positioned)
- (void) _resizeTabBarTimer:(NSTimer *) inTimer {
	// If the tab bar isn't at the right height, we set ourself to adjust it again
	if( inTimer == nil || ! [self _resizeTabBarAbsolute:NO] ) { //Do nothing when called from outside a timer.  This prevents the tabs from jumping when set from show to hide, and back rapidly.
		[NSTimer scheduledTimerWithTimeInterval:( 1. / 30. ) target:self selector:@selector( _resizeTabBarTimer: ) userInfo:nil repeats:NO];
	}
}

// Resize the tab bar towards it's desired height
- (BOOL) _resizeTabBarAbsolute:(BOOL) absolute {
	NSSize tabSize = [customTabsView frame].size;
	CGFloat destHeight = 0.;
	NSRect newFrame = NSZeroRect;

	// determine the desired height
	destHeight = ( _tabIsShowing ? _tabHeight : 0. );

	// move the tab view's height towards this desired height
	NSInteger distance = ( destHeight - tabSize.height ) * 0.6;
	if( absolute || ( distance > -1 && distance < 1 ) ) distance = destHeight - tabSize.height;

	tabSize.height += distance;
	[customTabsView setFrameSize:tabSize];
	[customTabsView setNeedsDisplay:YES];

	// adjust other views
	newFrame = [tabView frame];
	newFrame.size.height -= distance;
	newFrame.origin.y += distance;
	[tabView setFrame:newFrame];
	[tabView setNeedsDisplay:YES];

	// return YES when the desired height is reached
	return ( tabSize.height == destHeight );
}

- (void) _refreshWindow {
	id item = [(JVChatTabItem *)[tabView selectedTabViewItem] chatViewController];
	if( ! item ) return;

	if( ( [item conformsToProtocol:@protocol( JVChatViewController )] && item != (id) _activeViewController ) || ( ! _activeViewController && [[item parent] conformsToProtocol:@protocol( JVChatViewController )] && ( item = [item parent] ) ) ) {
		id<JVChatViewController> lastActive = _activeViewController;
		if( [_activeViewController respondsToSelector:@selector( willUnselect )] )
			[(id<JVChatViewController>)_activeViewController willUnselect];
		if( [item respondsToSelector:@selector( willSelect )] )
			[(id<JVChatViewController>)item willSelect];

		_activeViewController = item;

		[[self window] makeFirstResponder:[[_activeViewController view] nextKeyView]];

		[self _refreshToolbar];

		if( [lastActive respondsToSelector:@selector( didUnselect )] )
			[lastActive didUnselect];
		if( [_activeViewController respondsToSelector:@selector( didSelect )] )
			[_activeViewController didSelect];
	} else if( ! [_views count] || ! _activeViewController ) {
		[[self window] setContentView:[[NSView alloc] initWithFrame:[[[self window] contentView] frame]]];
		[[[self window] toolbar] setDelegate:nil];
		[[self window] setToolbar:nil];
		[[self window] makeFirstResponder:nil];
	}

	[self _refreshWindowTitle];
}

- (void) _refreshPreferences {
	[super _refreshPreferences];

	_autoHideTabBar = ! [[NSUserDefaults standardUserDefaults] boolForKey:@"JVTabBarAlwaysVisible"];
	_forceTabBarVisible = ( [self preferenceForKey:@"tab bar visible"] ? [[self preferenceForKey:@"tab bar visible"] intValue] : -1 );

	[self updateTabBarVisibilityAndAnimate:NO];
}
@end
