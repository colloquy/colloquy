//
//  AICustomTabDragging.m
//  Adium
//
//  Created by Adam Iser on Sat Mar 06 2004.
//  Copyright (c) 2004 __MyCompanyName__. All rights reserved.
//

#import "AICustomTabDragging.h"
#import "AICustomTabDragWindow.h"
#import "AICustomTabsView.h"
#import "AICustomTabCell.h"

#define CUSTOM_TABS_INDENT		3					//Indent on left and right of tabbar

@interface AICustomTabDragging (PRIVATE)
+ (NSImage *)dragTabImageForTabCell:(AICustomTabCell *)tabCell inCustomTabsView:(AICustomTabsView *)customTabsView;
+ (NSImage *)dragWindowImageForWindow:(NSWindow *)window customTabsView:(AICustomTabsView *)customTabsView tabCell:(AICustomTabCell *)tabCell;
- (void)cleanupDrag;
@end

@implementation AICustomTabDragging

static AICustomTabDragging *sharedTabDragInstance = nil;
+ (AICustomTabDragging *)sharedInstance
{
	if(!sharedTabDragInstance) sharedTabDragInstance = [[self alloc] init];
	return(sharedTabDragInstance);
}

//Init
- (id)init
{
	[super init];
	_destinationOfLastDrag = nil;
	dragTabCell = nil;
	sourceTabBar = nil;
	destTabBar = nil;
	tabDragWindow = nil;

	return(self);
}

//Set the currently hovered destination tab view
- (void)setDestinationTabView:(AICustomTabsView *)inDest
{
	if(inDest != destTabBar){
		[destTabBar release];
		destTabBar = [inDest retain];
	}
	[tabDragWindow setDisplayingFullWindow:(!destTabBar) animate:YES];
}

//Set the currently hovered destination tab view
- (AICustomTabsView *)destinationTabView
{
	return(destTabBar);
}

//Set the currently active source tab view
- (AICustomTabsView *)sourceTabView
{
	return(sourceTabBar);
}

//Set the currently hovered screen point
- (void)setDestinationHoverPoint:(NSPoint)inPoint
{
	[tabDragWindow moveToPoint:inPoint];
}

//Size of the cell being dragged
- (NSSize)sizeOfDraggedCell
{
	return([dragTabCell frame].size);
}


//Drag Start/Stop --------------------------------------------------------------------------------------------------------
#pragma mark Drag Start/Stop
//Initiate a drag
- (void)dragTabCell:(AICustomTabCell *)inTabCell fromCustomTabsView:(AICustomTabsView *)sourceView withEvent:(NSEvent *)inEvent selectTab:(BOOL)shouldSelect
{
    NSPasteboard 	*pboard;
    NSPoint			clickLocation = [inEvent locationInWindow];
    NSPoint			startPoint;
    BOOL			sourceWindowWillHide;

	//Post the dragging will begin notification
	[[NSNotificationCenter defaultCenter] postNotificationName:AICustomTabDragWillBegin object:self];

	//Setup
	[destTabBar release]; destTabBar = nil;
	sourceTabBar = [sourceView retain];
	dragTabCell = [inTabCell retain];
	selectTabAfterDrag = shouldSelect;

	//Determine if the source window will hide as a result of this drag
	sourceWindowWillHide = ([sourceTabBar removingLastTabHidesWindow] && [sourceTabBar numberOfTabViewItems] == 1);
	if(!sourceWindowWillHide){
		destTabBar = [sourceView retain];
	}

	//Adjust the drag offset so the cursor is atleast always touching the tab drag image
	int width = [inTabCell frame].size.width;
	int height = [inTabCell frame].size.height;

	dragOffset = NSMakeSize([inTabCell frame].origin.x - clickLocation.x, [inTabCell frame].origin.y - clickLocation.y);
	if(dragOffset.width > width) dragOffset.width = width;
	if(dragOffset.width < -width) dragOffset.width = -width;
	if(dragOffset.height > height) dragOffset.height = height;
	if(dragOffset.height < -height) dragOffset.height = -height;

	//Create the drag window for our custom drag tracking
	tabDragWindow = [AICustomTabDragWindow dragWindowForCustomTabView:sourceView
																 cell:inTabCell
														  transparent:!([sourceTabBar removingLastTabHidesWindow])];
	[tabDragWindow setDisplayingFullWindow:sourceWindowWillHide animate:NO];

	//Position the drag window
	startPoint = [[inEvent window] convertBaseToScreen:[inEvent locationInWindow]];
	startPoint = NSMakePoint(startPoint.x + dragOffset.width, startPoint.y + dragOffset.height);
	[tabDragWindow moveToPoint:startPoint];

	//Hide the source window
	if(sourceWindowWillHide){
		[[sourceTabBar window] setAlphaValue:0.0];
	}

	//Perform the drag
	pboard = [NSPasteboard pasteboardWithName:NSDragPboard];
	[pboard declareTypes:[NSArray arrayWithObjects:TAB_CELL_IDENTIFIER, nil] owner:self];
	[pboard setString:TAB_CELL_IDENTIFIER forType:TAB_CELL_IDENTIFIER];
	[[inEvent window] dragImage:[tabDragWindow dragImage]
							 at:NSMakePoint(clickLocation.x + dragOffset.width, clickLocation.y + dragOffset.height)
						 offset:NSMakeSize(0,0)
						  event:inEvent
					 pasteboard:pboard
						 source:self
					  slideBack:NO];

	//Sneaky Bug Fix ---
	//After dropping a tab into a tab bar, the tabbar's cursor tracking is rebuilt.  Unfortunately, since the floating
	//window (With an image of the tab) used for dragging is still over the tab bar, any cursor rects we attempt to
	//install below it will not work.  A sneaky solution to this is to remember the destination tab bar of the drag,
	//and reset it's cursor tracking again, after the drag window has closed.
	[tabDragWindow closeWindow];
	if(_destinationOfLastDrag){
		[_destinationOfLastDrag resetCursorTracking];
		[_destinationOfLastDrag release]; _destinationOfLastDrag= nil;
	}

}

//End a drag
- (void)acceptDragIntoTabView:(AICustomTabsView *)destTabView atIndex:(int)destIndex
{
	if(destTabView == sourceTabBar){
		//Tab re-arranging we handle internally
		[sourceTabBar moveTab:[dragTabCell tabViewItem] toIndex:destIndex selectTab:selectTabAfterDrag animate:NO];

	}else{
		//Moving tabs between bars is handled by the tab view delegate
		if([[sourceTabBar delegate] respondsToSelector:@selector(customTabView:didMoveTabViewItem:toCustomTabView:index:screenPoint:)]){
			[[sourceTabBar delegate] customTabView:sourceTabBar
								didMoveTabViewItem:[dragTabCell tabViewItem]
								   toCustomTabView:destTabView
											 index:destIndex
									   screenPoint:NSMakePoint(-1,-1)];
		}
	}

	//Remember the dest tab bar so we can reset cursor tracking (see dragTabCell:fromCustomTabsView:withEvent:)
	_destinationOfLastDrag = [destTabBar retain];
	[self cleanupDrag];

	//Post the dragging did finish notification
	[[NSNotificationCenter defaultCenter] postNotificationName:AICustomTabDragDidComplete object:self];
}


//Drag Tracking --------------------------------------------------------------------------------------------------------
#pragma mark Drag Tracking (Source)
//Invoked in the dragging source as the drag begins
- (void)draggedImage:(NSImage *)image beganAt:(NSPoint)screenPoint
{
    [self draggedImage:image movedTo:screenPoint];
}

//Invoked in the dragging source as the drag moves
- (void)draggedImage:(NSImage *)image movedTo:(NSPoint)screenPoint
{
	[tabDragWindow setDisplayingFullWindow:(!destTabBar) animate:YES];

    if(!destTabBar){
        [tabDragWindow moveToPoint:screenPoint];
    }
}

//Invoked in the dragging source as the drag ends
- (void)draggedImage:(NSImage *)image endedAt:(NSPoint)screenPoint operation:(NSDragOperation)operation
{
	if(operation == NSDragOperationNone){ //when dropped on the screen
		//Sneaky Bug Fix ---
		//If a drag is done very quickly, the system will fail to send our tab bar a draggingExited event, even though
		//the drag DID exit.  If this hapens, destTabBar will not be nil when we reach this method.  If the drag
		//opearation is 0, we know the tab was dropped somewhere on the screen.  So, if there is a value in destTabBar
		//we can assume it's a tab bar the system failed to send a draggingExited event, and send it ourself.
		if(destTabBar) [destTabBar draggingExited:nil];

		screenPoint.x -= CUSTOM_TABS_INDENT;
        if([[sourceTabBar delegate] respondsToSelector:@selector(customTabView:didMoveTabViewItem:toCustomTabView:index:screenPoint:)]){
            [[sourceTabBar delegate] customTabView:sourceTabBar didMoveTabViewItem:[dragTabCell tabViewItem] toCustomTabView:nil index:-1 screenPoint:screenPoint];
        }
    }

    //Cleanup drag
	[self cleanupDrag];
}

//Prevent dragging of tabs to another application
- (unsigned int)draggingSourceOperationMaskForLocal:(BOOL)isLocal
{
    return(isLocal ? NSDragOperationEvery : NSDragOperationNone);
}

//Clean up drag variables
- (void)cleanupDrag
{
	[dragTabCell release]; dragTabCell = nil;
	[destTabBar release]; destTabBar = nil;
	[sourceTabBar release]; sourceTabBar = nil;
}

- (NSTabViewItem *)draggedTabViewItem
{
	return([dragTabCell tabViewItem]);
}

@end
