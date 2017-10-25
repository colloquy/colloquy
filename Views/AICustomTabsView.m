/*-------------------------------------------------------------------------------------------------------*\
| Adium, Copyright (C) 2001-2004, Adam Iser  (adamiser@mac.com | http://www.adiumx.com)                   |
\---------------------------------------------------------------------------------------------------------/
| This program is free software; you can redistribute it and/or modify it under the terms of the GNU
| General Public License as published by the Free Software Foundation; either version 2 of the License,
| or (at your option) any later version.
|
| This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even
| the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General
| Public License for more details.
|
| You should have received a copy of the GNU General Public License along with this program; if not,
| write to the Free Software Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
\------------------------------------------------------------------------------------------------------ */

#import "AICustomTabsView.h"
#import "AICustomTabCell.h"
#import "AICustomTabDragging.h"
#import "NSImageAdditions.h"
#import "NSWindow+CQMCoordinateSpaceConversion.h"

#define TAB_DRAG_DISTANCE 		3					//Distance required before a drag kicks in
#define CUSTOM_TABS_FPS			30.0				//Animation speed
#define CUSTOM_TABS_STEP        0.5					//Step size per frame
#define CUSTOM_TABS_SLOW_STEP   0.1					//Step size per frame (When shift is held)
#define CUSTOM_TABS_GAP			1					//Gap between tabs
#define CUSTOM_TABS_INDENT		3					//Indent on left and right of tabbar

//Images shared by all instances of AICustomTabsView
static  NSImage			*tabBackground = nil;
static  NSImage			*tabDivider = nil;

@interface AICustomTabsView (PRIVATE)
- (instancetype)initWithFrame:(NSRect)frameRect;

//Positioning
- (void)arrangeTabs;
- (void)smoothlyArrangeTabs;
- (void)smoothlyArrangeTabsWithGapOfWidth:(int)width atIndex:(NSInteger)index;
- (void)_arrangeCellTimer:(NSTimer *)inTimer;
- (BOOL)_arrangeCellsAbsolute:(BOOL)absolute;

//Dragging
@property (readonly, copy) NSArray *acceptableDragTypes;
- (NSPoint)_dropPointForTabOfWidth:(int)dragTabWidth hoveredAtScreenPoint:(NSPoint)inPoint dropIndex:(NSInteger *)outIndex;
- (BOOL)allowsTabRearranging;

//Tab Data Access (Guarded)
- (void)removeTabCell:(AICustomTabCell *)inCell;
@property (readonly, copy) NSArray *tabCellArray;

//Cursor tracking
- (void)startCursorTracking;
- (void)stopCursorTracking;
@end

@implementation AICustomTabsView

//Create a new custom tab view
+ (id)customTabViewWithFrame:(NSRect)frameRect
{
    return([[self alloc] initWithFrame:frameRect]);
}

//init
- (instancetype)initWithFrame:(NSRect)frameRect
{
    //Init
    if (!(self = [super initWithFrame:frameRect])) return nil;
    arrangeCellTimer = nil;
    removingLastTabHidesWindow = YES;
	allowsTabRearranging = YES;
    tabCellArray = nil;
    selectedCustomTabCell = nil;
	ignoreTabNumberChange = NO;

    //register as a drag observer
    [self registerForDraggedTypes:[self acceptableDragTypes]];
    [self rebuildTabCells];

    return(self);
}

//Dealloc
- (void)dealloc
{
	_self = nil;
    [arrangeCellTimer invalidate];
}

//Allow tab switching from the background
- (BOOL)acceptsFirstMouse:(NSEvent *)theEvent
{
    return(YES);
}

//Prevent dragging on metal windows
- (BOOL)mouseDownCanMoveWindow
{
    return(NO);
}


//Configure ------------------------------------------------------------------------------------------------------------
#pragma mark Configure
//Set our delegate
@synthesize delegate;
- (void)setDelegate:(id<AICustomTabsViewDelegate>)inDelegate
{
    delegate = inDelegate;

    //Update our accepted drag types
    [self unregisterDraggedTypes];
    [self registerForDraggedTypes:[self acceptableDragTypes]];
}

//Does removing the last tab of a window cause that window to hide?
- (void)setRemovingLastTabHidesWindow:(BOOL)inValue
{
    removingLastTabHidesWindow = inValue;
}
- (BOOL)removingLastTabHidesWindow
{
    return(removingLastTabHidesWindow);
}

//Can the user close inactive tabs?
- (void)setAllowsInactiveTabClosing:(BOOL)inValue
{
    //Save the value
    allowsInactiveTabClosing = inValue;

    //Pass it onto our tabs
    for (AICustomTabCell *tabCell in tabCellArray) {
		[tabCell setAllowsInactiveTabClosing:allowsInactiveTabClosing];
    }
}
- (BOOL)allowsInactiveTabClosing
{
    return(allowsInactiveTabClosing);
}

//Is the user allowed to rearrange tabs within the window?
- (void)setAllowsTabRearranging:(BOOL)inValue
{
	allowsTabRearranging = inValue;
}
- (BOOL)allowsTabRearranging
{
	return(allowsTabRearranging);
}


//Additional Public Methods --------------------------------------------------------------------------------------------
#pragma mark Additional Public Methods
//Redisplay a tab
- (void)redisplayTabForTabViewItem:(NSTabViewItem *)inTabViewItem
{
	[self setNeedsDisplayInRect:[[self tabCellForTabViewItem:inTabViewItem] frame]];
}

//Resize a tab
- (void)resizeTabForTabViewItem:(NSTabViewItem *)inTabViewItem
{
	[self smoothlyArrangeTabs];
}

//Move a tab
- (void)moveTab:(NSTabViewItem *)tabViewItem toIndex:(NSInteger)index
{
	[self moveTab:tabViewItem toIndex:index selectTab:NO animate:YES];
}

//Returns number of tab view items
- (NSInteger)numberOfTabViewItems
{
	return([tabView numberOfTabViewItems]);
}


//Tabs -----------------------------------------------------------------------------------------------------------------
#pragma mark Tabs
//Tell our delegate to close a tab
- (void)closeTab:(AICustomTabCell *)tabCell
{
    if([delegate respondsToSelector:@selector(customTabView:closeTabViewItem:)]){
        [delegate customTabView:self closeTabViewItem:[tabCell tabViewItem]];
    }
}

//Tell our delegate to close all tabs except for the one passed
- (void)closeAllTabsExceptFor:(AICustomTabCell *)targetCell
{
    if([delegate respondsToSelector:@selector(customTabView:closeTabViewItem:)]){
		NSEnumerator 	*enumerator = [tabCellArray objectEnumerator];
		AICustomTabCell *tabCell;

		while( ( tabCell = [enumerator nextObject] ) ) {
			if(tabCell != targetCell){
				[delegate customTabView:self closeTabViewItem:[tabCell tabViewItem]];
			}
		}
    }
}

//Reposition a tab
- (void)moveTab:(NSTabViewItem *)tabViewItem toIndex:(NSInteger)index selectTab:(BOOL)shouldSelect animate:(BOOL)animate
{
	//Ignore the move request if the tab is already at the proper index
	if([tabView indexOfTabViewItem:tabViewItem] != index){
		AICustomTabCell		*tabCell = [self tabCellForTabViewItem:tabViewItem];

		//Ignore the 'shouldSelect' choice if this cell is already selected
		if(tabViewItem == [tabView selectedTabViewItem]) shouldSelect = YES;

		//Move the tab cell
		NSUInteger	currentIndex = [tabCellArray indexOfObject:tabCell];
		NSUInteger	newIndex = index;

		//Account for shifting
		if(currentIndex < newIndex) newIndex--;

		//Move via a remove and add :(
		[tabCellArray removeObject:tabCell];
		[tabCellArray insertObject:tabCell atIndex:newIndex];

		//Move the tab
		ignoreTabNumberChange = YES;
		if([tabView indexOfTabViewItem:tabViewItem] < index) index--;
		[tabView removeTabViewItem:tabViewItem];
		[tabView insertTabViewItem:tabViewItem atIndex:index];
		ignoreTabNumberChange = NO;

		//Inform our delegate of the re-order
		if([delegate respondsToSelector:@selector(customTabViewDidChangeOrderOfTabViewItems:)]){
			[delegate customTabViewDidChangeOrderOfTabViewItems:self];
		}

		//Smoothly animate into place
		if(animate){
			[self smoothlyArrangeTabs];
		}else{
			[self rebuildTabCells];
		}
	}

	if(shouldSelect) [tabView selectTabViewItem:tabViewItem];
}

//Returns tab cell at the specified point
- (AICustomTabCell *)tabAtPoint:(NSPoint)clickLocation
{
    NSEnumerator	*enumerator;
    AICustomTabCell	*tabCell;

    enumerator = [tabCellArray objectEnumerator];
    while((tabCell = [enumerator nextObject])){
		if(tabCell != dragCell && NSPointInRect(clickLocation, [tabCell frame])) break;
    }

    return(tabCell);
}

//Returns the total width of our tabs
- (int)totalWidthOfTabs
{
    int				totalWidth = (CUSTOM_TABS_INDENT * 2);

    for (AICustomTabCell *tabCell in tabCellArray) {
		if(tabCell != dragCell) totalWidth += [tabCell size].width + CUSTOM_TABS_GAP;
    }

    return(totalWidth);
}

//Change our selection to match the current selected tabViewItem
- (void)tabView:(NSTabView *)inTabView didSelectTabViewItem:(NSTabViewItem *)tabViewItem
{
    NSEnumerator	*enumerator;
    AICustomTabCell	*tabCell;
    NSTabViewItem	*selectedTab = [inTabView selectedTabViewItem];

    //Set old cell for a redisplay
    [self setNeedsDisplayInRect:NSInsetRect([selectedCustomTabCell frame], -(CUSTOM_TABS_GAP * 2), 0)];

    //Record the new selected tab cell, and correctly set it as selected
    enumerator = [tabCellArray objectEnumerator];
    while((tabCell = [enumerator nextObject])){
        if([tabCell tabViewItem] == selectedTab){
            [tabCell setSelected:YES];
			selectedCustomTabCell = tabCell;
        }else{
            [tabCell setSelected:NO];
        }
    }

    //Redisplay new cell
    [self setNeedsDisplayInRect:NSInsetRect([selectedCustomTabCell frame], -(CUSTOM_TABS_GAP * 2), 0)];

    //Inform our delegate of the selection change
    if([delegate respondsToSelector:@selector(customTabView:didSelectTabViewItem:)]){
        [delegate customTabView:self didSelectTabViewItem:tabViewItem];
    }
}

//Rebuild our tab list to match the tabView
- (void)tabViewDidChangeNumberOfTabViewItems:(NSTabView *)inTabView
{
	if(!ignoreTabNumberChange){
		//Reset our tab list
		[self rebuildTabCells];

		//Inform our delegate of the tab count change
		if([delegate respondsToSelector:@selector(customTabViewDidChangeNumberOfTabViewItems:)]){
			[delegate customTabViewDidChangeNumberOfTabViewItems:self];
		}
	}
}

//Intercept frame changes and correctly resize our tabs
- (void)setFrame:(NSRect)frameRect
{
    [super setFrame:frameRect];
    [self arrangeTabs];
	[self resetCursorTracking];
}

//Rebuild the tab cells for this view
- (void)rebuildTabCells
{
	//Clean up existing cells
	[self stopCursorTracking];
     tabCellArray = [[NSMutableArray alloc] init];
	selectedCustomTabCell = nil;

	//Create a tab cell for each tabViewItem
	int	loop;
	for(loop = 0;loop < [tabView numberOfTabViewItems];loop++){
		NSTabViewItem		*tabViewItem = [tabView tabViewItemAtIndex:loop];
		AICustomTabCell		*tabCell;

		//Create a new tab cell
		 tabCell = [AICustomTabCell customTabForTabViewItem:(NSTabViewItem <AICustomTabViewItem> *)tabViewItem customTabsView:self];
		[tabCell setSelected:(tabViewItem == [tabView selectedTabViewItem])];
		[tabCell setAllowsInactiveTabClosing:allowsInactiveTabClosing];

		//Update our direct reference to the selected cell
		if(tabViewItem == [tabView selectedTabViewItem]){
			selectedCustomTabCell = tabCell;
		}

		//Add the tab cell to our array
		[tabCellArray addObject:tabCell];
	}

	[self arrangeTabs];
	[self startCursorTracking];
}

- (AICustomTabCell *)tabCellForTabViewItem:(NSTabViewItem *)tabViewItem
{
	NSEnumerator	*enumerator = [tabCellArray objectEnumerator];
	AICustomTabCell	*tabCell;

	while((tabCell = [enumerator nextObject]) && [tabCell tabViewItem] != tabViewItem);

	return(tabCell);
}


//Positioning ----------------------------------------------------------------------------------------------------------
#pragma mark Positioning
//More our tabs instantly into the correct positions
- (void)arrangeTabs
{
	tabGapWidth = 0;
	tabGapIndex = 0;
	[self _arrangeCellsAbsolute:YES];
}

//Slowly move our tabs into the correct positions
- (void)smoothlyArrangeTabs
{
	[self smoothlyArrangeTabsWithGapOfWidth:0 atIndex:0];
}

//Slowly move our tabs to make a gap
- (void)smoothlyArrangeTabsWithGapOfWidth:(int)width atIndex:(NSInteger)index
{
	tabGapWidth = width;
	tabGapIndex = index;

	if(!arrangeCellTimer){ //Ignore the request if animation is already occuring
		arrangeCellTimer = [NSTimer scheduledTimerWithTimeInterval:(1.0/CUSTOM_TABS_FPS)
															 target:self
														   selector:@selector(_arrangeCellTimer:)
														   userInfo:nil
															repeats:YES];
		[self _arrangeCellsAbsolute:NO];
	}
}

//Animation timer.  Continue arranging cells until they are in the correct position
- (void)_arrangeCellTimer:(NSTimer *)inTimer
{
    if([self _arrangeCellsAbsolute:NO]){
        [arrangeCellTimer invalidate];  arrangeCellTimer = nil;
    }
}

//Re-arrange our cells to their correct positions.  Returns YES is finished.  Pass NO for a partial movement
- (BOOL)_arrangeCellsAbsolute:(BOOL)absolute
{
    NSEnumerator	*enumerator;
    AICustomTabCell	*tabCell;
    int				xLocation;
    BOOL			finished = YES;
    int				tabExtraWidth;
    int				totalTabWidth;
    int				reducedWidth = 0;
    int				reduceThreshold = 1000000;

    //Get the total tab width
    totalTabWidth = [self totalWidthOfTabs] + tabGapWidth;

    //If the tabs are too wide, we need to shrink the bigger ones down
    tabExtraWidth = totalTabWidth - [self frame].size.width;
    if(tabExtraWidth > 0){
        NSArray			*sortedTabArray;
        int				tabCount = 0;
        int				totalTabWidthForShrinking = 0;

        //Make a copy of the tabArray sorted by width
        sortedTabArray = [tabCellArray sortedArrayUsingSelector:@selector(compareWidth:)];

        //Process each tab to determine how many should be squished, and the size they should squish to
        enumerator = [sortedTabArray reverseObjectEnumerator];
        tabCell = [enumerator nextObject];
        do{
			if(tabCell != dragCell){
				tabCount++;
				totalTabWidthForShrinking += [tabCell size].width;
				reducedWidth = ( tabCount ? ( (totalTabWidthForShrinking - tabExtraWidth) / tabCount ) : 0 );
			}

        }while((tabCell = [enumerator nextObject]) && (reducedWidth <= [tabCell size].width));

        //Remember the treshold at which tabs are squished
        reduceThreshold = (tabCell ? [tabCell size].width : 0);
    }

    //Position the tabs
    xLocation = CUSTOM_TABS_INDENT;
    enumerator = [tabCellArray objectEnumerator];
    unsigned index = 0;

    while((tabCell = [enumerator nextObject])){
		if(tabCell != dragCell){
			NSSize	size;
			NSPoint	origin;

			//Make a gap to signify that the dragged cell can be dropped here
			if(index == tabGapIndex) xLocation += tabGapWidth;

			//Get the object's size
			size = [tabCell size];

			//If this tab is > next biggest, use the 'reduced' width calculated above
			if(size.width > reduceThreshold){
				size.width = reducedWidth;
			}

			//Move the tab closer to its desired location
			origin = NSMakePoint(xLocation, 0 );
			if(!absolute){
				if(origin.x > [tabCell frame].origin.x){
					NSInteger distance = (origin.x - [tabCell frame].origin.x) * (( [[[NSApplication sharedApplication] currentEvent] modifierFlags] & NSShiftKeyMask ) ? CUSTOM_TABS_SLOW_STEP : CUSTOM_TABS_STEP);
					if(distance < 1) distance = 1;

					origin.x = [tabCell frame].origin.x + distance;

					if(finished) finished = NO;
				}else if(origin.x < [tabCell frame].origin.x){
					NSInteger distance = ([tabCell frame].origin.x - origin.x) * (( [[[NSApplication sharedApplication] currentEvent] modifierFlags] & NSShiftKeyMask ) ? CUSTOM_TABS_SLOW_STEP : CUSTOM_TABS_STEP);
					if(distance < 1) distance = 1;

					origin.x = [tabCell frame].origin.x - distance;
					if(finished) finished = NO;
				}
			}
			[tabCell setFrame:NSMakeRect((int)origin.x, (int)origin.y, (int)size.width, (int)size.height)];

			//Move to the next tab
			xLocation += size.width + CUSTOM_TABS_GAP; //overlap the tabs a bit
		}
		index++;
	}

	//When we finish, update the cursor tracking
	if(finished) [self resetCursorTracking];

    [self setNeedsDisplay:YES];
    return(finished);
}


//Drawing --------------------------------------------------------------------------------------------------------------
//Draw
- (void)drawRect:(NSRect)rect
{
    static  BOOL	haveLoadedImages = NO;
    NSEnumerator	*enumerator;
    AICustomTabCell	*tabCell, *nextTabCell;

	[[NSColor windowBackgroundColor] set];
	[NSBezierPath fillRect:rect];

    //Load our images (Images are shared between all AICustomTabsView instances)
    if(!haveLoadedImages){
		tabDivider = [NSImage imageNamed:@"aquaTabDivider"];
		tabBackground = [NSImage imageNamed:@"aquaTabBackground"];
        haveLoadedImages = YES;
    }

    //Draw our background
    [self drawBackgroundInRect:rect withFrame:[self frame] selectedTabRect:[selectedCustomTabCell frame]];

    //Draw our tabs
    enumerator = [tabCellArray objectEnumerator];
    tabCell = [enumerator nextObject];
    while((nextTabCell = [enumerator nextObject]) || tabCell){
        NSRect	cellFrame = [tabCell frame];

        if(NSIntersectsRect(cellFrame, rect)){
			if(tabCell != dragCell){
				BOOL	ignoreSelection = ([[AICustomTabDragging sharedInstance] destinationTabView] == self ||
										   [[AICustomTabDragging sharedInstance] sourceTabView] == self);

				//Draw the tab cell
				[tabCell drawWithFrame:cellFrame inView:self ignoreSelection:ignoreSelection];

				//Draw the divider
				//We don't draw the divider for the selected tab, or the tab to the right of the selected tab
				//We also don't draw it for the index behind hovered
				if((ignoreSelection ||
					(tabCell != selectedCustomTabCell && (!nextTabCell || nextTabCell != selectedCustomTabCell)))
				   && (NSInteger)[tabCellArray indexOfObject:tabCell] != tabGapIndex - 1){
					[tabDivider drawAtPoint:NSMakePoint(cellFrame.origin.x + cellFrame.size.width, cellFrame.origin.y) fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0];
				}
			}
		}

        tabCell = nextTabCell;
	}
}

//Constrain a rect horizontally
static NSRect AIConstrainRectWidth(NSRect rect, CGFloat left, CGFloat right)
{
	if(rect.origin.x < left){
		rect.size.width -= left - rect.origin.x;
		rect.origin.x = left;
	}
	if(NSMaxX(rect) > right){
		rect.size.width -= NSMaxX(rect) - right;
	}

	return(rect);
}

//Draw our background strip
- (void)drawBackgroundInRect:(NSRect)rect withFrame:(NSRect)viewFrame selectedTabRect:(NSRect)tabFrame
{
	NSRect		drawRect;

	if([[AICustomTabDragging sharedInstance] destinationTabView] == self ||
	   [[AICustomTabDragging sharedInstance] sourceTabView] == self){ //Draw dark gradient across entire view
		if(NSIntersectsRect(viewFrame, rect)){
			[tabBackground tileInRect:AIConstrainRectWidth(viewFrame, NSMinX(rect), NSMaxX(rect))];
		}

	}else{ //Draw dark gradient left and right of active tab
		drawRect = NSMakeRect(viewFrame.origin.x,
							  viewFrame.origin.y,
							  tabFrame.origin.x - viewFrame.origin.x,
							  viewFrame.size.height);
		if(NSIntersectsRect(drawRect, rect)){
			[tabBackground tileInRect:AIConstrainRectWidth(drawRect, NSMinX(rect), NSMaxX(rect))];
		}

		drawRect = NSMakeRect(tabFrame.origin.x + tabFrame.size.width,
							  viewFrame.origin.y,
							  (viewFrame.origin.x + viewFrame.size.width) - (tabFrame.origin.x + tabFrame.size.width),
							  viewFrame.size.height);
		if(NSIntersectsRect(drawRect, rect)){
			[tabBackground tileInRect:AIConstrainRectWidth(drawRect, NSMinX(rect), NSMaxX(rect))];
		}
	}
}


//Contextual menu ------------------------------------------------------------------------------------------------------
#pragma mark Contextual menu
//Return a contextual menu
- (NSMenu *)menuForEvent:(NSEvent *)theEvent
{
    NSPoint		clickLocation = [self convertPoint:[theEvent locationInWindow] fromView:nil];
    AICustomTabCell	*tabCell = [self tabAtPoint:clickLocation];

    //Pass this on to our delegate
    if(tabCell && [delegate respondsToSelector:@selector(customTabView:menuForTabViewItem:)]){
        return([delegate customTabView:self menuForTabViewItem:[tabCell tabViewItem]]);
    }
    return(nil);
}


//Tooltip ------------------------------------------------------------------------------------------------------
#pragma mark Tooltip
//Return a tooltip
- (NSString *) view:(NSView *) view stringForToolTip:(NSToolTipTag) tag point:(NSPoint) point userData:(void *) userData {
	NSPoint		location = [self convertPoint:point fromView:nil];
    AICustomTabCell	*tabCell = [self tabAtPoint:location];

	//Pass this on to our delegate
    if(tabCell && [delegate respondsToSelector:@selector(customTabView:toolTipForTabViewItem:)]){
        return([delegate customTabView:self toolTipForTabViewItem:[tabCell tabViewItem]]);
    }
    return @"";
}

//Clicking & Dragging --------------------------------------------------------------------------------------------------
#pragma mark Clicking & Dragging
//Mouse Down
- (void)mouseDown:(NSEvent *)theEvent
{
    AICustomTabCell	*tabCell;

    //Remember the clicked location so we can track any dragging
    lastClickLocation = [self convertPoint:[theEvent locationInWindow] fromView:nil];

	//Give the tab cell a chance to handle tracking
    if((tabCell = [self tabAtPoint:lastClickLocation])){
        if(![tabCell willTrackMouse:theEvent inRect:[tabCell frame] ofView:self]){
//			if(!( [[[NSApplication sharedApplication] currentEvent] modifierFlags] & NSCommandKeyMask )){ //Allow background dragging
                [tabView selectTabViewItem:[tabCell tabViewItem]];
//            }
        }
    }
}

//Mouse Dragged
- (void)mouseDragged:(NSEvent *)theEvent
{
    NSPoint             clickLocation = [self convertPoint:[theEvent locationInWindow] fromView:nil];

	//Once we've dragged beyond a certain threshold, initiate a tab drag
	if( (lastClickLocation.x - clickLocation.x) > TAB_DRAG_DISTANCE || (lastClickLocation.x - clickLocation.x) < -TAB_DRAG_DISTANCE ||
		(lastClickLocation.y - clickLocation.y) > TAB_DRAG_DISTANCE || (lastClickLocation.y - clickLocation.y) < -TAB_DRAG_DISTANCE ){

		//Perform a tab drag
		if(lastClickLocation.x != -1 && lastClickLocation.y != -1){ //See note below about lastClickLocation

			dragCell = [self tabAtPoint:lastClickLocation];
			if(dragCell){

				[self stopCursorTracking];
				[[AICustomTabDragging sharedInstance] dragTabCell:dragCell
											   fromCustomTabsView:self
														withEvent:theEvent
														selectTab:(!( [[[NSApplication sharedApplication] currentEvent] modifierFlags] & NSCommandKeyMask ))];

				 dragCell = nil;
				_self = nil;
			}
		}

		//Sneaky Bug Fix --
		//When dragging quickly, mouseDragged may be called multiple times.  We only want to drag once, no matter what.
		//This is achieved by only allowing a drag if lastClickLocation is valid.  lastClickLocation will only be valid
		//for the first mouseDragged event, allowing others to be easily ignored.
		lastClickLocation = NSMakePoint(-1,-1);
	}
}

//Return the drag types we accept
- (NSArray *)acceptableDragTypes
{
    NSArray *types = nil;

	//We always accept tab drags, but ask our delegate if it accepts any additional types
    if([delegate respondsToSelector:@selector(customTabViewAcceptableDragTypes:)]){
        types = [delegate customTabViewAcceptableDragTypes:self];
    }

    return(types ? [types arrayByAddingObject:TAB_CELL_IDENTIFIER] : @[TAB_CELL_IDENTIFIER]);
}

//Return YES to accept drags
- (BOOL)prepareForDragOperation:(id <NSDraggingInfo>)sender
{
    return(YES);
}

//Perform a drag operation (switching around the tabs)
- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender
{
    NSPoint			location = [self convertPoint:[sender draggingLocation] fromView:nil];
	NSPasteboard	*pboard = [sender draggingPasteboard];
    NSString        *type = [pboard availableTypeFromArray:@[TAB_CELL_IDENTIFIER]];
    BOOL            success = NO;
	NSInteger		dropIndex;
	AICustomTabCell	*tabCell;

	//Perform the drag
    if(type && [type isEqualToString:TAB_CELL_IDENTIFIER]){
		[self _dropPointForTabOfWidth:[[AICustomTabDragging sharedInstance] sizeOfDraggedCell].width
				 hoveredAtScreenPoint:location
							dropIndex:&dropIndex];
		[[AICustomTabDragging sharedInstance] acceptDragIntoTabView:self atIndex:dropIndex];
		[self setNeedsDisplay:YES];
		[self displayIfNeeded];

		success = YES;

    }else{
        if((tabCell = [self tabAtPoint:[sender draggingLocation]])){
            if([delegate respondsToSelector:@selector(customTabView:didAcceptDragPasteboard:onTabViewItem:)]){
                success = [delegate customTabView:self didAcceptDragPasteboard:pboard
									onTabViewItem:[tabCell tabViewItem]];
            }
        }
    }

    return(success);
}

//Called when a drag enters this toolbar
- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender
{
	NSString 		*type = [[sender draggingPasteboard] availableTypeFromArray:@[TAB_CELL_IDENTIFIER]];
	NSDragOperation	operation = NSDragOperationNone;

	[self stopCursorTracking];
	if(type && [type isEqualToString:TAB_CELL_IDENTIFIER]){
		operation = NSDragOperationPrivate;
		[[AICustomTabDragging sharedInstance] setDestinationTabView:self];
	}else{
		operation = NSDragOperationCopy;
	}

	//Pass the drag event along to our window
	if([[[self window] windowController] respondsToSelector:@selector(draggingEntered:)]){
		[[[self window] windowController] draggingEntered:sender];
	}

    return(operation);
}

//Called continuously as the drag is over our tab bar
- (NSDragOperation)draggingUpdated:(id <NSDraggingInfo>)sender
{
    NSPoint			location = [self convertPoint:[sender draggingLocation] fromView:nil];
    NSPasteboard 	*pboard = [sender draggingPasteboard];
    NSString 		*type = [pboard availableTypeFromArray:@[TAB_CELL_IDENTIFIER]];
    NSDragOperation	operation = NSDragOperationNone;

    if(type && [type isEqualToString:TAB_CELL_IDENTIFIER]){ //Dragging a tab
		int			draggedCellWidth = [[AICustomTabDragging sharedInstance] sizeOfDraggedCell].width;
		NSInteger	dropIndex;

		//Snap the hovered tab to it's drop location, and slide our tabs out of the way to make room
		[[AICustomTabDragging sharedInstance] setDestinationHoverPoint:[self _dropPointForTabOfWidth:draggedCellWidth
															   hoveredAtScreenPoint:location
																		  dropIndex:&dropIndex]];
		[self smoothlyArrangeTabsWithGapOfWidth:(draggedCellWidth + CUSTOM_TABS_GAP) atIndex:dropIndex];
		operation = NSDragOperationPrivate;
    }else{
		AICustomTabCell	*tabCell;

        if((tabCell = [self tabAtPoint:location])){
            //Select the tab being hovered
            if([tabView selectedTabViewItem] != [tabCell tabViewItem]){
                [tabView selectTabViewItem:[tabCell tabViewItem]];
            }
            operation = NSDragOperationCopy;
        }
    }

    return(operation);
}

//Called when the drag exits this tab bar
- (void)draggingExited:(id <NSDraggingInfo>)sender
{
	NSPasteboard 	*pboard = [sender draggingPasteboard];
	NSString 		*type = [pboard availableTypeFromArray:@[TAB_CELL_IDENTIFIER]];

	if(type && [type isEqualToString:TAB_CELL_IDENTIFIER]){ //Dragging a tab

		//Stop tracking the drag, and move our tabs back to where they belong
		[[AICustomTabDragging sharedInstance] setDestinationTabView:nil];
		[self smoothlyArrangeTabs];

		//Pass event along to the windowController
		if([[[self window] windowController] respondsToSelector:@selector(draggingExited:)]){
			[[[self window] windowController] draggingExited:sender];
		}
	}
}

//Determines the correct drop index for a hovered tab, and returns the desired screen location and index for it
//We ignore frame origins in here, since they are being slid all around and relying on them will cause jiggyness.
//Instead, we step through each cell and use only it's width.
- (NSPoint)_dropPointForTabOfWidth:(int)dragTabWidth hoveredAtScreenPoint:(NSPoint)inPoint dropIndex:(NSInteger *)outIndex
{
	if(allowsTabRearranging){
		NSEnumerator 	*enumerator;
		AICustomTabCell	*tabCell;
		CGFloat			lastLocation = CUSTOM_TABS_INDENT;
		NSUInteger 		hoverIndex = 0;

		//Figure out where the user is hovering the tabcell item
		enumerator = [tabCellArray objectEnumerator];
		while((tabCell = [enumerator nextObject])){
			if(tabCell != dragCell){
				if(inPoint.x < lastLocation + (([tabCell frame].size.width + dragTabWidth) / 2.0) ) break;
				lastLocation += [tabCell frame].size.width + CUSTOM_TABS_GAP;
			}
			hoverIndex++;
		}

		//Special case: Tab is to the right of all our tabs, the drop index is set to after our last tab
		if(hoverIndex >= [tabCellArray count]) hoverIndex = [tabCellArray count];

		if(outIndex) *outIndex = hoverIndex;

		return([[self window] cqm_convertPointToScreen:[self convertPoint:NSMakePoint(lastLocation,0) toView:nil]]);
	}else{
		NSTabViewItem		*tabViewItem = [[AICustomTabDragging sharedInstance] draggedTabViewItem];
		int					hover;

		//If dragging is disallowed, ask our delegate where this tab should go
		unsigned desiredIndex = [delegate customTabView:self indexForInsertingTabViewItem:tabViewItem];
		if(outIndex) *outIndex = desiredIndex;

		//Position the hover tab
		//Compensate for the hidden source drag tab if we are dragging to ourself
		if(dragCell && [tabCellArray indexOfObject:dragCell] < desiredIndex) desiredIndex--;
		if(desiredIndex == 0){
			hover = CUSTOM_TABS_INDENT;
		}else{
			hover = NSMaxX([tabCellArray[desiredIndex-1] frame]) + CUSTOM_TABS_GAP;
		}
		return([[self window] cqm_convertPointToScreen:[self convertPoint:NSMakePoint(hover,0) toView:nil]]);
	}
}


//Cursor tracking ------------------------------------------------------------------------------------------------------
#pragma mark Cursor Tracking
//Reset the cursor tracking (Call when tabs change shape or position, or to re-enable tracking after a stop)
- (void)resetCursorTracking
{
	[self stopCursorTracking];
	[self startCursorTracking];
}

//Install tracking rects for each tab
- (void)startCursorTracking
{
    //Track only if we're within a valid window
    if([self window] && !trackingCursor){
        NSPoint			localPoint;

        //Local mouse location
		localPoint = [[self window] cqm_convertPointToScreen:[NSEvent mouseLocation]];

        //Install tracking rects for each tab
        for (AICustomTabCell *tabCell in tabCellArray) {
            NSRect trackRect = [tabCell frame];
            [tabCell addTrackingRectsWithFrame:trackRect cursorLocation:localPoint];
        }

		trackingCursor = YES;
    }
}

//Remove the tracking rect for each open tab
- (void)stopCursorTracking
{
	if(trackingCursor){
		for (AICustomTabCell *tabCell in tabCellArray) {
			[tabCell removeTrackingRects];
		}

		trackingCursor = NO;
	}
}

@end

