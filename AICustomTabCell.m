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

#import <Cocoa/Cocoa.h>
#import "AICustomTabCell.h"
#import "AICustomTabsView.h"

#define SHOW_CLOSE_BUTTON_FOR_SINGLE_TAB	YES		//Show close button when there is only one tab?

//Images (Shared between AICustomTabCell instances)
static NSImage		*tabFrontLeft = nil;
static NSImage		*tabFrontMiddle = nil;
static NSImage		*tabFrontRight = nil;
static NSImage		*tabCloseFront = nil;
static NSImage		*tabCloseBack = nil;
static NSImage		*tabCloseFrontPressed = nil;
static NSImage		*tabCloseFrontRollover = nil;

#define TAB_CLOSE_LEFTPAD		2		//Padding left of close button
#define TAB_CLOSE_RIGHTPAD		3		//Padding right of close button

#define TAB_CLOSE_Y_OFFSET		1       //Vertical offset of close button from center

#define TAB_RIGHT_PAD			5       //Tab right edge padding
#define TAB_LABEL_Y_OFFSET		1       //Vertical offset of label text from center

#define TAB_MIN_WIDTH			48      //(Could be used to) Enforce a mininum tab size safari style
#define TAB_SELECTED_HIGHER     NO     	//Draw the selected tab higher?

@interface AICustomTabCell (PRIVATE)
- (id)initForTabViewItem:(NSTabViewItem *)inTabViewItem;
- (NSRect)_closeButtonRect;
@end

@implementation AICustomTabCell

//Create a new custom tab
+ (id)customTabForTabViewItem:(NSTabViewItem *)inTabViewItem
{
    return([[[self alloc] initForTabViewItem:inTabViewItem] autorelease]);
}

//init
- (id)initForTabViewItem:(NSTabViewItem *)inTabViewItem
{
    static BOOL haveLoadedImages = NO;
    
    [super init];
	
    //Share these images between all AICustomTabCell instances
    if(!haveLoadedImages){
		tabFrontLeft = [[NSImage imageNamed:@"aquaTabLeft"] retain];
		tabFrontMiddle = [[NSImage imageNamed:@"aquaTabMiddle"] retain];
		tabFrontRight = [[NSImage imageNamed:@"aquaTabRight"] retain];

//		NSControlTint	tint = [NSColor currentControlTintSupportingJag];
		tabCloseFront = [[NSImage imageNamed:@"aquaTabClose"] retain];
		tabCloseBack = [[NSImage imageNamed:@"aquaTabCloseBack"] retain];
		tabCloseFrontPressed = [[NSImage imageNamed:@"aquaTabClosePressed"] retain];
		tabCloseFrontRollover = [[NSImage imageNamed:@"aquaTabCloseRollover"] retain];

        haveLoadedImages = YES;
    }
	
    tabViewItem = [inTabViewItem retain];
    allowsInactiveTabClosing = NO;
	wasEnabled = YES;
    trackingClose = NO;
    hoveringClose = NO;
    selected = NO;
    trackingTag = 0;
    closeTrackingTag = 0;
	toolTipTag = 0;
	
    return(self);
}

//dealloc
- (void)dealloc
{
	[attributedLabel release];
	[tabViewItem release];

    [super dealloc];
}

//Return the desired size of this tab
- (NSSize)size
{
	int width = [tabFrontLeft size].width + [[self attributedLabel] size].width + [tabFrontRight size].width +
	(TAB_CLOSE_LEFTPAD + [[tabViewItem icon] size].width + TAB_CLOSE_RIGHTPAD) + TAB_RIGHT_PAD;
	
    return( NSMakeSize((width > TAB_MIN_WIDTH ? width : TAB_MIN_WIDTH), [tabFrontLeft size].height) );
}

//Compare the width of this tab to another
- (NSComparisonResult)compareWidth:(AICustomTabCell *)tab
{
    int	tabWidth = [tab size].width;
    int	ourWidth = [self size].width;
	
    if(tabWidth > ourWidth){
        return(NSOrderedAscending);
        
    }else if(tabWidth < ourWidth){
        return(NSOrderedDescending);
        
    }else{
        return(NSOrderedSame);
        
    }
}

//Return the tab view item this tab is representing
- (NSTabViewItem *)tabViewItem
{
    return(tabViewItem);
}

//Frame of our close button
- (NSRect)_closeButtonRect
{
	NSSize	iconSize = [[tabViewItem icon] size];
	NSSize	closeSize = [tabCloseFront size];
    int 	centeredYPos = frame.origin.y + (frame.size.height - [tabCloseFront size].height) / 2.0;
    return(NSMakeRect(frame.origin.x + [tabFrontLeft size].width + TAB_CLOSE_LEFTPAD + ((iconSize.width - closeSize.width) / 2.0),
					  centeredYPos + TAB_CLOSE_Y_OFFSET + 1,
					  [tabCloseFront size].width,
					  [tabCloseFront size].height));
}


//Configure ------------------------------------------------------------------------------------------------------------
#pragma mark Configure
//Allow the user to close this tab even if it's not active
- (void)setAllowsInactiveTabClosing:(BOOL)inValue
{
    allowsInactiveTabClosing = inValue;
}
- (BOOL)allowsInactiveTabClosing{
	return(allowsInactiveTabClosing);
}

//The selected tab draws differently and has special close button behavior
- (void)setSelected:(BOOL)inSelected
{
    selected = inSelected;
}
- (BOOL)isSelected{
    return(selected);
}

//When a tab is hovered it should be highlighted.  Highlighted tabs draw differently.
- (void)setHighlighted:(BOOL)inHighlighted
{
    highlighted = inHighlighted;
}
- (BOOL)isHighlighted{
    return(highlighted);
}

//Frame determines where this tab cell will draw
- (void)setFrame:(NSRect)inFrame
{
    frame = inFrame;
}
- (NSRect)frame{
    return(frame);
}


//Drawing --------------------------------------------------------------------------------------------------------------
#pragma mark Drawing
//Normal draw routine
- (void)drawWithFrame:(NSRect)rect inView:(NSView *)controlView
{
	[self drawWithFrame:rect inView:controlView ignoreSelection:NO];
}

//Draw.  Pass ignore selection to ignore whether this tab is selected or not when drawing
- (void)drawWithFrame:(NSRect)rect inView:(NSView *)controlView ignoreSelection:(BOOL)ignoreSelection
{
    int		leftCapWidth, rightCapWidth, middleSourceWidth, middleRightEdge, middleLeftEdge;
    NSRect	sourceRect, destRect;
    NSSize	labelSize;
	NSPoint destPoint;
    
    //Pre-calc some dimensions
    labelSize = [tabViewItem sizeOfLabel:NO];
    leftCapWidth = [tabFrontLeft size].width;
    rightCapWidth = [tabFrontRight size].width;
    middleSourceWidth = [tabFrontMiddle size].width;
    middleRightEdge = (rect.origin.x + rect.size.width - rightCapWidth);
    middleLeftEdge = (rect.origin.x + leftCapWidth);
	
    //Background
    if(selected && !ignoreSelection){
        //Draw the left cap
        [tabFrontLeft compositeToPoint:NSMakePoint(rect.origin.x, rect.origin.y) operation:NSCompositeSourceOver];
		
        //Draw the middle
        sourceRect = NSMakeRect(0, 0, [tabFrontMiddle size].width, [tabFrontMiddle size].height);
        destRect = NSMakeRect(middleLeftEdge, rect.origin.y, sourceRect.size.width, sourceRect.size.height);
		
        while(destRect.origin.x < middleRightEdge){
            if((destRect.origin.x + destRect.size.width) > middleRightEdge){
                sourceRect.size.width -= (destRect.origin.x + destRect.size.width) - middleRightEdge;
            }
            [tabFrontMiddle compositeToPoint:destRect.origin fromRect:sourceRect operation:NSCompositeSourceOver];
            destRect.origin.x += destRect.size.width;
        }
		
        //Draw the right cap
        [tabFrontRight compositeToPoint:NSMakePoint(middleRightEdge, rect.origin.y) operation:NSCompositeSourceOver];
		
    }else if(highlighted){
        [[NSColor colorWithCalibratedWhite:0.0 alpha:0.1] set];
        [NSBezierPath fillRect:NSMakeRect(rect.origin.x, rect.origin.y, rect.size.width, rect.size.height)];
    }
	
    //Offset for icon
    rect.origin.x += leftCapWidth;
    rect.size.width -= leftCapWidth + rightCapWidth;
    
	//We'll display our close icon if the user is hovering.  Otherwise, we display the tab specified icon
	NSImage *leftIcon = [tabViewItem icon];
	if((hoveringClose && (selected || allowsInactiveTabClosing || ( [[[NSApplication sharedApplication] currentEvent] modifierFlags] & NSCommandKeyMask ))) || !leftIcon){		
		if(hoveringClose){
			leftIcon = (trackingClose ? tabCloseFrontPressed : tabCloseFrontRollover);
		}else{
			leftIcon = ((selected && !ignoreSelection) ? tabCloseFront : tabCloseBack);
		}
		destPoint = [self _closeButtonRect].origin;

	}else{
		destPoint = NSMakePoint(frame.origin.x + [tabFrontLeft size].width + TAB_CLOSE_LEFTPAD,
								((frame.size.height - [leftIcon size].height) / 2.0) + TAB_CLOSE_Y_OFFSET);
	}

	// Draw at whole pixel points only.
	destPoint.y = ceilf( destPoint.y );
	destPoint.x = ceilf( destPoint.x );

	[leftIcon compositeToPoint:destPoint operation:NSCompositeSourceOver fraction:( [tabViewItem isEnabled] ? 1. : 0.5 )];

	//Move over for label drawing.  We always move based on the tab icon and not on the close button.  This prevents
	//tab text from jumping when hovered if the tab icons are a different size from the close button
	NSSize leftIconSize = [[tabViewItem icon] size];
	rect.origin.x += TAB_CLOSE_LEFTPAD + leftIconSize.width + TAB_CLOSE_RIGHTPAD;
	rect.size.width -= TAB_CLOSE_LEFTPAD + leftIconSize.width + TAB_CLOSE_RIGHTPAD + TAB_RIGHT_PAD;

	
	//Draw our label
	destRect = NSMakeRect(rect.origin.x,
						  rect.origin.y + TAB_LABEL_Y_OFFSET,
						  rect.size.width,
						  rect.size.height - ((rect.size.height - labelSize.height) / 2.0));
    if(TAB_SELECTED_HIGHER && !ignoreSelection && selected) destRect.origin.y += 1.0;
	[[self attributedLabel] drawInRect:destRect];	
}

//Returns the attributed form of our label for drawing (cached)
- (NSAttributedString *)attributedLabel
{
	NSString	*label = [tabViewItem label];
	
	if(![label isEqualToString:[attributedLabel string]] || wasEnabled != [tabViewItem isEnabled] ){
		wasEnabled = [tabViewItem isEnabled];
		//Paragraph Style (Turn off clipping by word)
		NSMutableParagraphStyle *paragraphStyle = [[[NSParagraphStyle defaultParagraphStyle] mutableCopy] autorelease];
		[paragraphStyle setAlignment:NSCenterTextAlignment];
		[paragraphStyle setLineBreakMode:NSLineBreakByTruncatingTail];

		//Update the attributed string
		[attributedLabel release];
		attributedLabel = [[NSAttributedString alloc] initWithString:label attributes:
			[NSDictionary dictionaryWithObjectsAndKeys:
				( wasEnabled ? [NSColor controlTextColor] : [[NSColor controlTextColor] colorWithAlphaComponent:0.5] ), NSForegroundColorAttributeName,
				[NSFont systemFontOfSize:11], NSFontAttributeName,
				paragraphStyle, NSParagraphStyleAttributeName,
				nil]];
	}
	
	return(attributedLabel);
}


//Cursor tracking ------------------------------------------------------------------------------------------------------
#pragma mark Cursor tracking
//Install tracking rects for our tab and its close button
- (void)addTrackingRectsInView:(NSView *)view withFrame:(NSRect)trackRect cursorLocation:(NSPoint)cursorLocation
{
    userData = [[NSDictionary dictionaryWithObjectsAndKeys:view, @"view", nil] retain]; //We have to retain and release the userData ourself
    trackingTag = [view addTrackingRect:trackRect
                                  owner:self
                               userData:userData
                           assumeInside:NSPointInRect(cursorLocation, trackRect)];
    highlighted = NSPointInRect(cursorLocation, trackRect);
	
    closeUserData = [[NSDictionary dictionaryWithObjectsAndKeys:view, @"view", [NSNumber numberWithBool:YES], @"close", nil] retain]; //We have to retain and release the userData ourself
    closeTrackingTag = [view addTrackingRect:[self _closeButtonRect]
                                       owner:self
                                    userData:closeUserData
                                assumeInside:NSPointInRect(cursorLocation, [self _closeButtonRect])];
    hoveringClose = NSPointInRect(cursorLocation, [self _closeButtonRect]);
	
	toolTipTag = [view addToolTipRect:trackRect owner:view userData:NULL];
}

//Remove our tracking rects
- (void)removeTrackingRectsFromView:(NSView *)view
{
    [view removeTrackingRect:trackingTag]; trackingTag = 0;
    [userData autorelease]; userData = nil;

    [view removeTrackingRect:closeTrackingTag]; closeTrackingTag = 0;
    [closeUserData autorelease]; closeUserData = nil;
	
	[view removeToolTip:toolTipTag]; toolTipTag = 0;
}

//Mouse entered our tabs (or close button)
- (void)mouseEntered:(NSEvent *)theEvent
{
    NSDictionary    *eventData = [theEvent userData];
    NSView          *view = [eventData objectForKey:@"view"];

	//Scrubs the tab if control is down.
//	if(([theEvent modifierFlags] & NSAlternateKeyMask) && !selected){
//		[[tabViewItem tabView] selectTabViewItem:tabViewItem];
//	}
	
    //Set ourself (or our close button) has hovered
    if((allowsInactiveTabClosing || selected || ( [[[NSApplication sharedApplication] currentEvent] modifierFlags] & NSCommandKeyMask ) ) && [[eventData objectForKey:@"close"] boolValue]){
        hoveringClose = YES;
        [view setNeedsDisplayInRect:[self frame]];
    }else{
        highlighted = YES;
        [view setNeedsDisplayInRect:[self frame]];
    }
}

//Mouse left one of our tabs
- (void)mouseExited:(NSEvent *)theEvent
{
    NSDictionary    *eventData = [theEvent userData];
    NSView          *view = [eventData objectForKey:@"view"];
	
    //Set ourself (or our close button) has not hovered
    if([[eventData objectForKey:@"close"] boolValue]){
        hoveringClose = NO;
        [view setNeedsDisplayInRect:[self frame]];
    }else{
        highlighted = NO;
        [view setNeedsDisplayInRect:[self frame]];
    }
}


//Clicking & Click tracking --------------------------------------------------------------------------------------------
#pragma mark Clicking & Click tracking
//Track click and hold on the close button
- (BOOL)willTrackMouse:(NSEvent *)theEvent inRect:(NSRect)cellFrame ofView:(NSView *)controlView
{
    if((allowsInactiveTabClosing || selected || ( [[[NSApplication sharedApplication] currentEvent] modifierFlags] & NSCommandKeyMask ) ) &&
	   (SHOW_CLOSE_BUTTON_FOR_SINGLE_TAB || [[tabViewItem tabView] numberOfTabViewItems] != 1) &&
	   NSPointInRect([controlView convertPoint:[theEvent locationInWindow] fromView:nil], [self _closeButtonRect])){
		
        [self trackMouse:theEvent inRect:[self _closeButtonRect] ofView:controlView untilMouseUp:YES];
        return(YES);
		
    }else{
        return(NO);
		
    }
}

//Start Tracking.  Redisplay the close button as pressed
- (BOOL)startTrackingAt:(NSPoint)startPoint inView:(NSView *)controlView
{
    trackingClose = YES;
    hoveringClose = YES;
    [controlView setNeedsDisplayInRect:[self _closeButtonRect]];
	
    return(YES);
}

//
- (BOOL)continueTracking:(NSPoint)lastPoint at:(NSPoint)currentPoint inView:(NSView *)controlView
{
    BOOL	hovering = NSPointInRect(currentPoint, [self _closeButtonRect]);
	
    if(hoveringClose != hovering){
        hoveringClose = hovering;
        [controlView setNeedsDisplayInRect:[self _closeButtonRect]];
    }
    
    return(YES);
}

//
- (void)stopTracking:(NSPoint)lastPoint at:(NSPoint)stopPoint inView:(NSView *)controlView mouseIsUp:(BOOL)flag
{
    BOOL	hovering = NSPointInRect(stopPoint, [self _closeButtonRect]);
	
	//Closes all the other tabs in the current window if option is held down (And we have more than one tab)
	if(hovering && ([[[controlView window] currentEvent] modifierFlags] & NSAlternateKeyMask) && [[tabViewItem tabView] numberOfTabViewItems] > 1){
		[(AICustomTabsView *)controlView closeAllTabsExceptFor:self];
	}else if(hovering){ //If the mouse was released over the close button, close our tab
        [(AICustomTabsView *)controlView closeTab:self];
    }
	
    hoveringClose = NO;
    trackingClose = NO;
    [controlView setNeedsDisplayInRect:[self _closeButtonRect]];
}

@end
