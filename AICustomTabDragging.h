//
//  AICustomTabDragging.h
//  Adium
//
//  Created by Adam Iser on Sat Mar 06 2004.
//  Copyright (c) 2004 __MyCompanyName__. All rights reserved.
//

#define TAB_CELL_IDENTIFIER                     @"Tab Cell Identifier"

#import <Foundation/NSObject.h>
#import <Foundation/NSGeometry.h>

@class AICustomTabDragWindow;
@class AICustomTabCell;
@class AICustomTabsView;
@class NSEvent;

@interface AICustomTabDragging : NSObject {
	AICustomTabCell         *dragTabCell;			//Custom tab cell being dragged
	NSSize                  dragOffset;				//Offset of cursor on dragged image
	BOOL					selectTabAfterDrag;		//Drag is occuring in the background, do not select after dropping
	AICustomTabsView        *sourceTabBar;			//source tabBar of the drag
	AICustomTabsView        *destTabBar;			//tabBar currently being hovered by the drag
	AICustomTabsView 		*_destinationOfLastDrag;//last tabbar to be dragged into (used to fix a cursor tracking issue)
	AICustomTabDragWindow	*tabDragWindow;			//drag window used for custom drag animations
}

+ (AICustomTabDragging *)sharedInstance;
- (void)dragTabCell:(AICustomTabCell *)inTabCell fromCustomTabsView:(AICustomTabsView *)sourceView withEvent:(NSEvent *)inEvent selectTab:(BOOL)shouldSelect;
- (void)setDestinationTabView:(AICustomTabsView *)inDest;
- (AICustomTabsView *)destinationTabView;
- (void)setDestinationHoverPoint:(NSPoint)inPoint;
- (NSSize)sizeOfDraggedCell;
- (void)acceptDragIntoTabView:(AICustomTabsView *)destTabView atIndex:(int)destIndex;

@end
