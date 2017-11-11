//
//  AICustomTabDragWindow.h
//  Adium
//
//  Created by Adam Iser on Sat Mar 06 2004.
//  Copyright (c) 2004 __MyCompanyName__. All rights reserved.
//

@class ESFloater;
@class AICustomTabsView;
@class AICustomTabCell;

@interface AICustomTabDragWindow : NSObject {
	NSImage				*floaterTabImage;
	NSImage				*floaterWindowImage;
	ESFloater			*dragTabFloater;
	ESFloater			*dragWindowFloater;
	BOOL				fullWindow;

	BOOL				useFancyAnimations;
}

+ (AICustomTabDragWindow *)dragWindowForCustomTabView:(AICustomTabsView *)inTabView cell:(AICustomTabCell *)inTabCell transparent:(BOOL)transparent;
- (void)setDisplayingFullWindow:(BOOL)fullWindow animate:(BOOL)animate;
- (void)moveToPoint:(NSPoint)inPoint;
- (NSImage *)dragTabImageForTabCell:(AICustomTabCell *)tabCell inCustomTabsView:(AICustomTabsView *)customTabsView;
- (NSImage *)dragWindowImageForWindow:(NSWindow *)window customTabsView:(AICustomTabsView *)customTabsView tabCell:(AICustomTabCell *)tabCell;
- (NSImage *)dragImage;
- (void)closeWindow;

@end
