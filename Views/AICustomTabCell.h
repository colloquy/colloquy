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

#import <AppKit/AppKit.h>

@protocol AICustomTabViewItem <NSObject>
@property (readonly, copy) NSString *label;
@property (readonly) NSImage *icon;
@property (readonly, getter=isEnabled) BOOL enabled;
@end

@class AICustomTabsView;

@interface AICustomTabCell : NSCell {
	BOOL								wasEnabled;
    BOOL								selected;
    BOOL								highlighted;
    BOOL								allowsInactiveTabClosing;

    BOOL								trackingClose;
    BOOL								hoveringClose;

    NSTrackingRectTag					trackingTag;
    NSTrackingRectTag					closeTrackingTag;
    NSTrackingRectTag					toolTipTag;

	NSAttributedString					*attributedLabel;
    NSTabViewItem<AICustomTabViewItem>	*tabViewItem;
    NSRect								frame;

	AICustomTabsView					*view;
}

+ (instancetype)customTabForTabViewItem:(NSTabViewItem<AICustomTabViewItem> *)inTabViewItem customTabsView:(AICustomTabsView *)inView;
@property BOOL allowsInactiveTabClosing;
@property (getter=isSelected) BOOL selected;
- (void)setHoveringClose:(BOOL)hovering;
@property (getter=isHighlighted) BOOL highlighted;
@property NSRect frame;
@property (readonly) NSSize size;
- (NSComparisonResult)compareWidth:(AICustomTabCell *)tab;
@property (readonly, strong) NSTabViewItem *tabViewItem;
- (void)drawWithFrame:(NSRect)rect inView:(NSView *)controlView;
- (void)drawWithFrame:(NSRect)rect inView:(NSView *)controlView ignoreSelection:(BOOL)ignoreSelection;
- (void)addTrackingRectsWithFrame:(NSRect)trackRect cursorLocation:(NSPoint)cursorLocation;
- (void)removeTrackingRects;
- (void)mouseEntered:(NSEvent *)theEvent;
- (void)mouseExited:(NSEvent *)theEvent;
- (BOOL)willTrackMouse:(NSEvent *)theEvent inRect:(NSRect)cellFrame ofView:(NSView *)controlView;
- (BOOL)startTrackingAt:(NSPoint)startPoint inView:(NSView *)controlView;
- (BOOL)continueTracking:(NSPoint)lastPoint at:(NSPoint)currentPoint inView:(NSView *)controlView;
- (void)stopTracking:(NSPoint)lastPoint at:(NSPoint)stopPoint inView:(NSView *)controlView mouseIsUp:(BOOL)flag;
@property (readonly, copy) NSAttributedString *attributedLabel;

@end
