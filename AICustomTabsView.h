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

#import "ESFloater.h"
#define TAB_CELL_IDENTIFIER     @"Tab Cell Identifier"

@class AICustomTabCell;
@class AICustomTabsView;

@interface NSObject (AICustomTabsViewDelegate)
- (void)customTabView:(AICustomTabsView *)tabView didSelectTabViewItem:(NSTabViewItem *)tabViewItem;
- (void)customTabView:(AICustomTabsView *)tabView closeTabViewItem:(NSTabViewItem *)tabViewItem;
- (void)customTabViewDidChangeNumberOfTabViewItems:(AICustomTabsView *)tabView;
- (void)customTabViewDidChangeOrderOfTabViewItems:(AICustomTabsView *)tabView;
- (void)customTabView:(AICustomTabsView *)tabView didMoveTabViewItem:(NSTabViewItem *)tabViewItem toCustomTabView:(AICustomTabsView *)destTabView index:(int)index screenPoint:(NSPoint)point;
- (NSMenu *)customTabView:(AICustomTabsView *)tabView menuForTabViewItem:(NSTabViewItem *)tabViewItem;
- (NSString *)customTabView:(AICustomTabsView *)tabView toolTipForTabViewItem:(NSTabViewItem *)tabViewItem;
- (BOOL)customTabView:(AICustomTabsView *)tabView didAcceptDragPasteboard:(NSPasteboard *)pasteboard onTabViewItem:(NSTabViewItem *)tabViewItem;
- (NSArray *)customTabViewAcceptableDragTypes:(AICustomTabsView *)tabView;
- (int)customTabView:(AICustomTabsView *)tabView indexForInsertingTabViewItem:(NSTabViewItem *)tabViewItem;
@end

@interface AICustomTabsView : NSView {
    IBOutlet	NSTabView			*tabView;

    id					delegate;
    BOOL				allowsInactiveTabClosing;	//Allow closing of inactive tabs
	BOOL				allowsTabRearranging;		//Allow tabs to be rearranged in the window
	BOOL				trackingCursor;				//Tracking rects are installed
	BOOL				ignoreTabNumberChange;		//Ignore tab count changes, used for re-arranging
	
	//Tab Dragging
    BOOL                removingLastTabHidesWindow;	//Removing the last tab hides our window
	int 				tabGapWidth;				//Gap in our tabs
	int 				tabGapIndex;				//Location of the gap
    NSPoint				lastClickLocation;			//Last click location			
    NSTimer             *arrangeCellTimer;			//Timer for tab animations
	
	//Guarded.  Access these using the internal accessors
    NSMutableArray		*tabCellArray;
    AICustomTabCell		*selectedCustomTabCell;
	
	//
	AICustomTabCell     *dragCell;
}

//Delegate
- (void)setDelegate:(id)inDelegate;
- (id)delegate;

//Toggle closing of this window when the last tab is removed
- (void)setRemovingLastTabHidesWindow:(BOOL)inValue;
- (BOOL)removingLastTabHidesWindow;

//Allow closing of inactive tabs
- (void)setAllowsInactiveTabClosing:(BOOL)inValue;
- (BOOL)allowsInactiveTabClosing;

//Permit rearranging within the window
- (void)setAllowsTabRearranging:(BOOL)inValue;
- (BOOL)allowsTabRearranging;

//Misc
- (void)redisplayTabForTabViewItem:(NSTabViewItem *)inTabViewItem;
- (void)resizeTabForTabViewItem:(NSTabViewItem *)inTabViewItem;
- (void)moveTab:(NSTabViewItem *)tabViewItem toIndex:(int)index;
- (int)numberOfTabViewItems;

//Private
- (void)rebuildTabCells;
- (AICustomTabCell *)tabAtPoint:(NSPoint)clickLocation;
- (int)totalWidthOfTabs;
- (void)moveTab:(NSTabViewItem *)tabViewItem toIndex:(int)index selectTab:(BOOL)shouldSelect animate:(BOOL)animate;
- (int)numberOfTabViewItems;
- (void)closeTab:(AICustomTabCell *)tabCell;
- (void)closeAllTabsExceptFor:(AICustomTabCell *)targetCell;
- (void)drawBackgroundInRect:(NSRect)rect withFrame:(NSRect)viewFrame selectedTabRect:(NSRect)tabFrame;
- (void)resetCursorTracking;
- (AICustomTabCell *)tabCellForTabViewItem:(NSTabViewItem *)tabViewItem;

@end

