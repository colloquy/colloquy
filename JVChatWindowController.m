#import <Cocoa/Cocoa.h>
#import "JVChatWindowController.h"
#import "JVChatController.h"
#import "JVChatRoom.h"
#import "JVDetailCell.h"

NSString *JVToolbarToggleChatDrawerItemIdentifier = @"JVToolbarToggleChatDrawerItem";
NSString *JVChatViewPboardType = @"Colloquy Chat View v1.0 pasteboard type";

@interface NSToolbar (NSToolbarPrivate)
- (NSView *) _toolbarView;
@end

#pragma mark -

@interface JVChatWindowController (JVChatWindowControllerPrivate)
- (void) _refreshSelectionMenu;
- (void) _refreshWindow;
- (void) _refreshWindowTitle;
- (void) _refreshList;
@end

#pragma mark -

@interface NSOutlineView (ASEntendedOutlineView)
- (void) redisplayItemEqualTo:(id) item;
@end

#pragma mark -

@implementation JVChatWindowController
- (id) initWithWindowNibName:(NSString *) windowNibName {
	if( ( self = [super initWithWindowNibName:@"JVChatWindow"] ) ) {
		viewsDrawer = nil;
		chatViewsOutlineView = nil;
		viewActionButton = nil;
		_activeViewController = nil;
		_views = [[NSMutableArray array] retain];

		[[self window] makeKeyAndOrderFront:nil];
	}
	return self;
}

- (void) windowDidLoad {
	NSTableColumn *column = nil;
	id prototypeCell = nil;

	_placeHolder = [[[self window] contentView] retain];
	[[viewActionButton cell] setArrowPosition:NSPopUpNoArrow];

	column = [chatViewsOutlineView outlineTableColumn];
	prototypeCell = [[JVDetailCell new] autorelease];
	[prototypeCell setFont:[NSFont toolTipsFontOfSize:11.]];
	[column setDataCell:prototypeCell];

	[chatViewsOutlineView setAutoresizesOutlineColumn:YES];
	[chatViewsOutlineView setMenu:[[[NSMenu alloc] initWithTitle:@""] autorelease]];
	[chatViewsOutlineView registerForDraggedTypes:[NSArray arrayWithObject:JVChatViewPboardType]];
	[self _refreshList];
	
	[viewsDrawer open];
}

- (void) dealloc {
	[[self window] setToolbar:nil];
	[[self window] setContentView:_placeHolder];

	[chatViewsOutlineView setDelegate:nil];
	[chatViewsOutlineView setDataSource:nil];

	[_placeHolder autorelease];
	[_activeViewController autorelease];
	[_views autorelease];

	[[NSNotificationCenter defaultCenter] removeObserver:self];

	_placeHolder = nil;
	_activeViewController = nil;
	_views = nil;

	[super dealloc];
}

#pragma mark -

- (BOOL) respondsToSelector:(SEL) selector {
	if( [_activeViewController respondsToSelector:selector] )
		return [_activeViewController respondsToSelector:selector];
	else return [super respondsToSelector:selector];
}

- (void) forwardInvocation:(NSInvocation *) invocation {
	if( [_activeViewController respondsToSelector:[invocation selector]] )
		[invocation invokeWithTarget:_activeViewController];
	else [super forwardInvocation:invocation];
}

- (NSMethodSignature *) methodSignatureForSelector:(SEL) selector {
	if( [_activeViewController respondsToSelector:selector] )
		return [(NSObject *)_activeViewController methodSignatureForSelector:selector];
	else return [super methodSignatureForSelector:selector];
}

#pragma mark -

- (void) showChatViewController:(id <JVChatViewController>) controller {
	NSAssert1( [_views containsObject:controller], @"%@ is not a member of this window controller.", controller );
	[chatViewsOutlineView selectRow:[chatViewsOutlineView rowForItem:controller] byExtendingSelection:NO];
	[self _refreshList];
	[self _refreshWindow];
}

#pragma mark -

- (IBAction) closeCurrentPanel:(id) sender {
	[[JVChatController defaultManager] disposeViewController:_activeViewController];
	[self removeChatViewController:_activeViewController];
}

- (IBAction) selectPreviousPanel:(id) sender {
	int currentIndex = [_views indexOfObject:_activeViewController];
	int index = 0;

	if( currentIndex - 1 >= 0 ) index = ( currentIndex - 1 );
	else index = ( [_views count] - 1 );

	[self showChatViewController:[_views objectAtIndex:index]];
}

- (IBAction) selectNextPanel:(id) sender {
	int currentIndex = [_views indexOfObject:_activeViewController];
	int index = 0;

	if( currentIndex + 1 < [_views count] ) index = ( currentIndex + 1 );
	else index = 0;

	[self showChatViewController:[_views objectAtIndex:index]];
}

#pragma mark -

- (void) addChatViewController:(id <JVChatViewController>) controller {
	NSParameterAssert( controller != nil );
	NSAssert1( ! [_views containsObject:controller], @"%@ already added.", controller );

	[_views addObject:controller];
	[controller setWindowController:self];

	[self _refreshList];
	[self _refreshWindow];
}

- (void) insertChatViewController:(id <JVChatViewController>) controller atIndex:(unsigned int) index {
	NSParameterAssert( controller != nil );
	NSAssert1( ! [_views containsObject:controller], @"%@ already added.", controller );
	NSAssert( index >= 0 && index <= [_views count], @"Index is beyond bounds." );

	[_views insertObject:controller atIndex:index];
	[controller setWindowController:self];

	[self _refreshList];
	[self _refreshWindow];
}

#pragma mark -

- (void) removeChatViewController:(id <JVChatViewController>) controller {
	NSParameterAssert( controller != nil );
	NSAssert1( [_views containsObject:controller], @"%@ is not a member of this window controller.", controller );

	if( _activeViewController == controller ) {
		[_activeViewController autorelease];
		_activeViewController = nil;
	}

	[controller setWindowController:nil];
	[_views removeObjectIdenticalTo:controller];

	[self _refreshList];
	[self _refreshWindow];

	if( ! [_views count] ) {
		NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:[[JVChatController defaultManager] methodSignatureForSelector:@selector( disposeChatWindowController: )]];
		[invocation setTarget:[JVChatController defaultManager]];
		[invocation setSelector:@selector( disposeChatWindowController: )];
		[invocation setArgument:&self atIndex:2];
		[NSTimer scheduledTimerWithTimeInterval:0. invocation:invocation repeats:NO];
		[[self window] orderOut:nil];
//		[[JVChatController defaultManager] disposeChatWindowController:self];
	}
}

- (void) removeChatViewControllerAtIndex:(unsigned int) index {
	NSAssert( index >= 0 && index <= [_views count], @"Index is beyond bounds." );
	[self removeChatViewController:[_views objectAtIndex:index]];
}

- (void) removeAllChatViewControllers {
	NSInvocation *invocation = nil;

	[_activeViewController autorelease];
	_activeViewController = nil;

	[_views removeAllObjects];

	[self _refreshList];
	[self _refreshWindow];

	invocation = [NSInvocation invocationWithMethodSignature:[[JVChatController defaultManager] methodSignatureForSelector:@selector( disposeChatWindowController: )]];
	[invocation setTarget:[JVChatController defaultManager]];
	[invocation setSelector:@selector( disposeChatWindowController: )];
	[invocation setArgument:&self atIndex:2];
	[NSTimer scheduledTimerWithTimeInterval:0. invocation:invocation repeats:NO];
	[[self window] orderOut:nil];
//	[[JVChatController defaultManager] disposeChatWindowController:self];
}

#pragma mark -

- (void) replaceChatViewController:(id <JVChatViewController>) controller withController:(id <JVChatViewController>) newController {
	NSParameterAssert( controller != nil );
	NSParameterAssert( newController != nil );
	NSAssert1( [_views containsObject:controller], @"%@ is not a member of this window controller.", controller );
	NSAssert1( ! [_views containsObject:newController], @"%@ is already a member of this window controller.", newController );

	[self replaceChatViewControllerAtIndex:[_views indexOfObjectIdenticalTo:controller] withController:newController];
}

- (void) replaceChatViewControllerAtIndex:(unsigned int) index withController:(id <JVChatViewController>) controller {
	id <JVChatViewController> oldController = nil;
	NSParameterAssert( controller != nil );
	NSAssert1( ! [_views containsObject:controller], @"%@ is already a member of this window controller.", controller );
	NSAssert( index >= 0 && index <= [_views count], @"Index is beyond bounds." );

	oldController = [_views objectAtIndex:index];

	if( _activeViewController == oldController ) {
		[_activeViewController autorelease];
		_activeViewController = nil;
	}

	[oldController setWindowController:nil];
	[_views replaceObjectAtIndex:index withObject:controller];
	[controller setWindowController:self];

	[self _refreshList];
	[self _refreshWindow];
}

#pragma mark -

- (NSArray *) chatViewControllersForConnection:(MVChatConnection *) connection {
	NSMutableArray *ret = nil;
	NSEnumerator *enumerator = nil;
	id <JVChatViewController> controller = nil;

	NSParameterAssert( connection != nil );

	ret = [NSMutableArray array];
	while( ( controller = [enumerator nextObject] ) )
		if( [controller connection] == connection )
			[ret addObject:controller];

	return [[ret retain] autorelease];
}

- (NSArray *) chatViewControllersWithControllerClass:(Class) class {
	NSMutableArray *ret = nil;
	NSEnumerator *enumerator = nil;
	id <JVChatViewController> controller = nil;

	NSParameterAssert( class != NULL );
	NSAssert( [class conformsToProtocol:@protocol( JVChatViewController )], @"The tab controller class must conform to the JVChatViewController protocol." );

	ret = [NSMutableArray array];
	while( ( controller = [enumerator nextObject] ) )
		if( [controller isMemberOfClass:class] )
			[ret addObject:controller];

	return [[ret retain] autorelease];
}

- (NSArray *) allChatViewControllers {
	return [[_views retain] autorelease];
}

#pragma mark -

- (NSToolbarItem *) toggleChatDrawerToolbarItem {
	NSToolbarItem *toolbarItem = [[[NSToolbarItem alloc] initWithItemIdentifier:JVToolbarToggleChatDrawerItemIdentifier] autorelease];

	[toolbarItem setLabel:NSLocalizedString( @"Drawer", "chat panes drawer toolbar item name" )];
	[toolbarItem setPaletteLabel:NSLocalizedString( @"Panel Drawer", "chat panes drawer toolbar customize palette name" )];

	[toolbarItem setToolTip:NSLocalizedString( @"Toggle Chat Panel Drawer", "chat panes drawer toolbar item tooltip" )];
	[toolbarItem setImage:[NSImage imageNamed:@"showdrawer"]];

	[toolbarItem setTarget:self];
	[toolbarItem setAction:@selector( toggleViewsDrawer: )];

	return [[toolbarItem retain] autorelease];
}

- (IBAction) toggleViewsDrawer:(id) sender {
	[viewsDrawer toggle:sender];
}

#pragma mark -

- (void) reloadChatView:(id <JVChatViewController>) controller {
	[chatViewsOutlineView reloadItem:controller reloadChildren:YES];
	[self _refreshWindowTitle];
}

#pragma mark -

- (BOOL) validateMenuItem:(id <NSMenuItem>) menuItem {
	if( [menuItem action] == @selector( closeCurrentPanel: ) ) {
		[menuItem setTitle:[NSString stringWithFormat:NSLocalizedString( @"Close Panel %@", "close current panel menu title" ), [_activeViewController title]]];
		return YES;
	} else if( [menuItem action] == @selector( toggleViewsDrawer: ) ) {
		if( [viewsDrawer state] == NSDrawerClosedState || [viewsDrawer state] == NSDrawerClosingState ) {
			[menuItem setTitle:[NSString stringWithFormat:NSLocalizedString( @"Show Drawer", "show drawer menu title" )]];
		} else {
			[menuItem setTitle:[NSString stringWithFormat:NSLocalizedString( @"Hide Drawer", "hide drawer menu title" )]];
		}
		return YES;
	} else return YES;
}
@end

#pragma mark -

@implementation JVChatWindowController (JVChatWindowControllerDelegate)
- (void) windowWillClose:(NSNotification *) notification {
	NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:[[JVChatController defaultManager] methodSignatureForSelector:@selector( disposeChatWindowController: )]];
	[invocation setTarget:[JVChatController defaultManager]];
	[invocation setSelector:@selector( disposeChatWindowController: )];
	[invocation setArgument:&self atIndex:2];
	[NSTimer scheduledTimerWithTimeInterval:0. invocation:invocation repeats:NO];
//	[[JVChatController defaultManager] disposeChatWindowController:self];
}

- (void) windowDidBecomeMain:(NSNotification *) notification {
//	[window makeFirstResponder:sendText];
}

- (void) windowDidBecomeKey:(NSNotification *) notification {
//	[window makeFirstResponder:sendText];
}

- (void) windowDidResize:(NSNotification *) notification {
//	[displayText scrollRangeToVisible:NSMakeRange( [[displayText textStorage] length], 0 )];
}

#pragma mark -

- (void) outlineView:(NSOutlineView *) outlineView willDisplayCell:(id) cell forTableColumn:(NSTableColumn *) tableColumn item:(id) item {
	[(JVDetailCell *) cell setMainText:[item title]];
	[(JVDetailCell *) cell setInformationText:[item information]];
	[(JVDetailCell *) cell setStatusImage:[item statusImage]];

	[chatViewsOutlineView sizeLastColumnToFit];

	if( ! ( [[chatViewsOutlineView window] firstResponder] == chatViewsOutlineView && [[NSApplication sharedApplication] isActive] ) && [outlineView itemAtRow:[outlineView selectedRow]] == item && ! [item conformsToProtocol:@protocol( JVChatViewController )] ) {
		[outlineView selectRow:[outlineView rowForItem:_activeViewController] byExtendingSelection:NO];
		[outlineView reloadItem:_activeViewController reloadChildren:YES];
		[outlineView redisplayItemEqualTo:_activeViewController];
		[outlineView setNeedsDisplay:YES];
	}
}

- (int) outlineView:(NSOutlineView *) outlineView numberOfChildrenOfItem:(id) item {
	if( item ) {
		return [item numberOfChildren];
	} else return [_views count];
}

- (BOOL) outlineView:(NSOutlineView *) outlineView isItemExpandable:(id) item {
	return ( [item numberOfChildren] ? YES : NO );
}

- (id) outlineView:(NSOutlineView *) outlineView child:(int) index ofItem:(id) item {
	if( item ) {
		return [item childAtIndex:index];
	} else return [_views objectAtIndex:index];
}

- (id) outlineView:(NSOutlineView *) outlineView objectValueForTableColumn:(NSTableColumn *) tableColumn byItem:(id) item {
	return [item icon];
}

- (BOOL) outlineView:(NSOutlineView *) outlineView shouldEditTableColumn:(NSTableColumn *) tableColumn item:(id) item {
	return NO;
}

- (int) outlineView:(NSOutlineView *) outlineView heightOfRow:(int) row {
	return ( [outlineView levelForRow:row] ? 17 : 36 );
}

- (void) outlineViewSelectionDidChange:(NSNotification *) notification {
	id item = [[notification object] itemAtRow:[[notification object] selectedRow]];

	if( [item conformsToProtocol:@protocol( JVChatViewController )] && item != (id) _activeViewController )
		[self _refreshWindow];

	[self _refreshSelectionMenu];
}

- (BOOL) outlineView:(NSOutlineView *) outlineView writeItems:(NSArray *) items toPasteboard:(NSPasteboard *) board {
	id item = [items lastObject];
	NSData *data = [NSData dataWithBytes:&item length:sizeof( &item )];
	if( ! [item conformsToProtocol:@protocol( JVChatViewController )] ) return NO;
	[board declareTypes:[NSArray arrayWithObjects:JVChatViewPboardType/*, NSStringPboardType*/, nil] owner:self];
	[board setData:data forType:JVChatViewPboardType];
//	[board setString:string forType:NSStringPboardType];
	return YES;
}

- (NSDragOperation) outlineView:(NSOutlineView *) outlineView validateDrop:(id <NSDraggingInfo>) info proposedItem:(id) item proposedChildIndex:(int) index {
	if( ! item ) return NSDragOperationMove;
	else return NSDragOperationNone;
}

- (BOOL) outlineView:(NSOutlineView *) outlineView acceptDrop:(id <NSDraggingInfo>) info item:(id) item childIndex:(int) index {
	NSPasteboard *board = [info draggingPasteboard];
	NSData *pointerData = [board dataForType:JVChatViewPboardType];
	id <JVChatViewController> dragedController = nil;
	[pointerData getBytes:&dragedController];

	[[dragedController retain] autorelease];

	if( [_views containsObject:dragedController] ) {
		if( index != NSOutlineViewDropOnItemIndex && index >= [_views indexOfObjectIdenticalTo:dragedController] ) index--;
		[_views removeObjectIdenticalTo:dragedController];
	} else {
		[[dragedController windowController] removeChatViewController:dragedController];
	}

//	NSLog( @"%@ %d %@ %d", item, index, dragedController, [dragedController retainCount] );

	if( index == NSOutlineViewDropOnItemIndex ) [self addChatViewController:dragedController];
	else [self insertChatViewController:dragedController atIndex:index];

	return YES;
}

/*- (BOOL) tableView:(NSTableView *) view writeRows:(NSArray *) rows toPasteboard:(NSPasteboard *) board {
	NSEnumerator *enumerator = [rows objectEnumerator];
	NSMutableArray *array = [NSMutableArray array];
	NSMutableString *string = [NSMutableString string];
	id row;
	unsigned i = 0;
	[board declareTypes:[NSArray arrayWithObjects:MVSongPboardType,NSStringPboardType,nil] owner:self];
	while( ( row = [enumerator nextObject] ) ) {
		i = [row unsignedIntValue];
		[array addObject:[[sortedData objectAtIndex:i] report]];
		[string appendFormat:NSLocalizedString( @"%@ by %@", song info text format - Song Title by Artist format ), [[sortedData objectAtIndex:i] title], [[sortedData objectAtIndex:i] artist]];
		if( ! [[rows lastObject] isEqual:row] ) [string appendString:@"\n"];
	}
	[board setPropertyList:array forType:MVSongPboardType];
	[board setString:string forType:NSStringPboardType];
	return YES;
}

- (NSDragOperation) tableView:(NSTableView *) view validateDrop:(id <NSDraggingInfo>) info proposedRow:(int) row proposedDropOperation:(NSTableViewDropOperation) operation {
	if( operation == NSTableViewDropAbove && ! [view isEqual:[info draggingSource]] ) return NSDragOperationEvery;
	return NSDragOperationNone;
}

- (BOOL) tableView:(NSTableView *) view acceptDrop:(id <NSDraggingInfo>) info row:(int) row dropOperation:(NSTableViewDropOperation) operation {
	NSArray *reports = [[info draggingPasteboard] propertyListForType:MVSongPboardType];
	MVSong *song = [MVSong song];
	NSEnumerator *enumerator = [reports objectEnumerator];
	id report;
	while( ( report = [enumerator nextObject] ) ) {
		[song setReport:report];
		if( ! [song hasPriorRequest] ) [data requestSong:song];
	}
	return YES;
}*/
@end

#pragma mark -

@implementation JVChatWindowController (JVChatWindowControllerPrivate)
- (void) _refreshSelectionMenu {
	id item = [chatViewsOutlineView itemAtRow:[chatViewsOutlineView selectedRow]];
	id menuItem = nil;
	NSMenu *menu = [chatViewsOutlineView menu];
	NSMenu *newMenu = [item menu];
	NSEnumerator *enumerator = [[[[menu itemArray] copy] autorelease] objectEnumerator];

	while( ( menuItem = [enumerator nextObject] ) )
		[menu removeItem:menuItem];

	enumerator = [[[[newMenu itemArray] copy] autorelease] objectEnumerator];
	while( ( menuItem = [enumerator nextObject] ) ) {
		[newMenu removeItem:menuItem];
		[menu addItem:menuItem];
	}
}

- (void) _refreshWindow {
	id item = [chatViewsOutlineView itemAtRow:[chatViewsOutlineView selectedRow]];

	if( ( [item conformsToProtocol:@protocol( JVChatViewController )] && item != (id) _activeViewController ) || ( ! _activeViewController && [[item parent] conformsToProtocol:@protocol( JVChatViewController )] && ( item = [item parent] ) ) ) {
		id lastActive = _activeViewController;
		if( [_activeViewController respondsToSelector:@selector( willUnselect )] )
			[(NSObject *)_activeViewController willUnselect];
		if( [item respondsToSelector:@selector( willSelect )] )
			[(NSObject *)item willSelect];

		[_activeViewController autorelease];
		_activeViewController = [item retain];

		[[self window] setContentView:[item view]];
		[[self window] setToolbar:[item toolbar]];
		[[self window] makeFirstResponder:[[item view] nextKeyView]];

		if( [lastActive respondsToSelector:@selector( didUnselect )] )
			[(NSObject *)lastActive didUnselect];
		if( [_activeViewController respondsToSelector:@selector( didSelect )] )
			[(NSObject *)_activeViewController didSelect];
	} else if( ! [_views count] || ! _activeViewController ) {
//		NSToolbar *placeHolder = [[[NSToolbar alloc] initWithIdentifier:@"chat.placeHolder"] autorelease];
		[[self window] setContentView:_placeHolder];
//		[placeHolder setVisible:[[[self window] toolbar] isVisible]];
//		[[self window] setToolbar:placeHolder];
//		[[[self window] toolbar] setVisible:NO];
		[[self window] setToolbar:nil];
		[[self window] makeFirstResponder:nil];
	}

	[self _refreshWindowTitle];
}

- (void) _refreshWindowTitle {
	NSString *title = [_activeViewController windowTitle];
	if( ! title ) title = @"";
	[[self window] setTitle:title];
}

- (void) _refreshList {
	[chatViewsOutlineView reloadData];
	[chatViewsOutlineView noteNumberOfRowsChanged];
	[chatViewsOutlineView sizeLastColumnToFit];
	[self _refreshSelectionMenu];
}
@end