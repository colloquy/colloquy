//
//  AICustomTabDragWindow.m
//  Adium
//
//  Created by Adam Iser on Sat Mar 06 2004.
//  Copyright (c) 2004 __MyCompanyName__. All rights reserved.
//

#import "AICustomTabDragWindow.h"
#import "AICustomTabsView.h"
#import "AICustomTabCell.h"
#import "ESFloater.h"
#import "NSImageAdditions.h"

#define CUSTOM_TABS_INDENT		3					//Indent on left and right of tabbar
#define CONTENT_OFFSET_X		1					//Offset of content view relative to tabs


@interface AICustomTabDragWindow (PRIVATE)
- (instancetype)initForCustomTabView:(AICustomTabsView *)inTabView cell:(AICustomTabCell *)inTabCell transparent:(BOOL)transparent;
@end

@implementation AICustomTabDragWindow
+ (AICustomTabDragWindow *)dragWindowForCustomTabView:(AICustomTabsView *)inTabView cell:(AICustomTabCell *)inTabCell transparent:(BOOL)transparent
{
	return([[self alloc] initForCustomTabView:inTabView cell:inTabCell transparent:transparent]);
}

//init
- (instancetype)initForCustomTabView:(AICustomTabsView *)inTabView cell:(AICustomTabCell *)inTabCell transparent:(BOOL)transparent

{
	if (!(self = [super init])) return nil;

	floaterTabImage = [self dragTabImageForTabCell:inTabCell inCustomTabsView:inTabView];
	floaterWindowImage = [self dragWindowImageForWindow:[inTabView window] customTabsView:inTabView tabCell:inTabCell];
	useFancyAnimations = ( floaterWindowImage ? YES : NO );

	if(useFancyAnimations){
		//Create a floating window for our tab
		dragTabFloater = [ESFloater floaterWithImage:floaterTabImage styleMask:NSBorderlessWindowMask title:nil];
		[dragTabFloater setMaxOpacity:1.0];

		//Create a floating window for the stand-alone window our tab would produce
		dragWindowFloater = [ESFloater floaterWithImage:floaterWindowImage styleMask:NSTitledWindowMask title:[[inTabView window] title]];
		[dragWindowFloater setMaxOpacity:(transparent ? 0.75 : 1.00)];
	}

	return(self);
}

- (void)closeWindow
{
    [dragTabFloater close:nil]; dragTabFloater = nil;
    [dragWindowFloater close:nil]; dragWindowFloater = nil;
}

//dealloc
- (void)dealloc
{
    [dragTabFloater close:nil];
    [dragWindowFloater close:nil];

}

//Toggle display of the full drag window
- (void)setDisplayingFullWindow:(BOOL)inFullWindow animate:(BOOL)animate
{
	if(useFancyAnimations){
		fullWindow = inFullWindow;
		[dragWindowFloater setVisible:fullWindow animate:animate];
		[dragTabFloater setVisible:!fullWindow animate:animate];
	}
}

//Move the drag floater to a screen point
//If the drag window is fading out, we don't move it.  Things look cleaner this way.
- (void)moveToPoint:(NSPoint)inPoint
{
	if(useFancyAnimations){
		[dragTabFloater moveFloaterToPoint:inPoint];
		if(fullWindow) [dragWindowFloater moveFloaterToPoint:NSMakePoint(inPoint.x - CUSTOM_TABS_INDENT, inPoint.y)];
	}
}


//Tab Imaging ----------------------------------------------------------------------------------------------------------
#pragma mark Drag Images
//Returns a drag image for the passed tab cell
- (NSImage *)dragTabImageForTabCell:(AICustomTabCell *)tabCell inCustomTabsView:(AICustomTabsView *)customTabsView
{
    NSImage     *dragTabImage = nil;

    if([customTabsView canDraw]){
        dragTabImage = [[NSImage alloc] init];
        [customTabsView lockFocus];
        [dragTabImage addRepresentation:[[NSBitmapImageRep alloc] initWithFocusedViewRect:[tabCell frame]]];
        [customTabsView unlockFocus];
    }

    return(dragTabImage);
}

//Returns a drag window image for the passed window/bar/cell
- (NSImage *)dragWindowImageForWindow:(NSWindow *)window customTabsView:(AICustomTabsView *)customTabsView tabCell:(AICustomTabCell *)tabCell
{
    NSView      *contentView = [[tabCell tabViewItem]  view];
    NSImage     *dragWindowImage = nil;
    NSImage     *contentImage, *tabImage;
    NSPoint     insertPoint;

    if([customTabsView canDraw] && [contentView canDraw]){
        //Get an image of the tab
        tabImage = [[NSImage alloc] init];
        [customTabsView lockFocus];
        [tabImage addRepresentation:[[NSBitmapImageRep alloc] initWithFocusedViewRect:[tabCell frame]]];
        [customTabsView unlockFocus];

        //Get an image of the tabView content view
        contentImage = [[NSImage alloc] init];
        [contentView lockFocus];
        [contentImage addRepresentation:[[NSBitmapImageRep alloc] initWithFocusedViewRect:[contentView frame]]];
        [contentView unlockFocus];

        //Create a drag image the size of the window
        dragWindowImage = [[NSImage alloc] initWithSize:[[window contentView] frame].size];
        [dragWindowImage setBackgroundColor:[NSColor clearColor]];
        [dragWindowImage lockFocus];

        //Draw the tabbar and tab
        [customTabsView drawBackgroundInRect:[customTabsView frame] withFrame:[customTabsView frame] selectedTabRect:NSMakeRect(0,0,0,0)];
        insertPoint = [customTabsView frame].origin;
        insertPoint.x += CUSTOM_TABS_INDENT; //Line the tab up a bit more realistically
		[tabImage drawAtPoint:insertPoint fromRect:NSZeroRect operation:NSCompositeCopy fraction:1.0];

        //Draw the content
		NSPoint	frameOrigin = [[[tabCell tabViewItem] tabView] frame].origin;
		[contentImage drawAtPoint:NSMakePoint(frameOrigin.x + CONTENT_OFFSET_X, frameOrigin.y) fromRect:NSZeroRect operation:NSCompositeCopy fraction:1.0];

        [dragWindowImage unlockFocus];
    }

    return(dragWindowImage);
}

//Returns the drag image for a drag system call.  In 10.3 we return a blank image to keep the system drag code happy
//Our custom drag image code (the floating windows) screws up drag tracking events in anything before panther (10.3)
//On earlier systems we fall back to using the stock dragging code
- (NSImage *)dragImage
{
	if(useFancyAnimations){
		return([[NSImage alloc] initWithSize:[floaterTabImage size]]);
	}else{
		return(floaterTabImage);
	}
}


@end
