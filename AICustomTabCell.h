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

@interface NSObject (AICustomTabViewItem)
- (NSString *)label;
- (NSImage *)icon;
@end

@interface AICustomTabCell : NSCell {
    BOOL				selected;
    BOOL				highlighted;
    BOOL				allowsInactiveTabClosing;
    
    BOOL				trackingClose;
    BOOL				hoveringClose;
    
    NSTrackingRectTag	trackingTag;
    NSDictionary        *userData;
    NSTrackingRectTag   closeTrackingTag;
    NSDictionary        *closeUserData;
	NSToolTipTag		toolTipTag;
    
	NSAttributedString	*attributedLabel;
    NSTabViewItem		*tabViewItem;
    NSRect				frame;
}

+ (id)customTabForTabViewItem:(NSTabViewItem *)inTabViewItem;
- (void)setAllowsInactiveTabClosing:(BOOL)inValue;
- (BOOL)allowsInactiveTabClosing;
- (void)setSelected:(BOOL)inSelected;
- (BOOL)isSelected;
- (void)setHighlighted:(BOOL)inHighlighted;
- (BOOL)isHighlighted;
- (void)setFrame:(NSRect)inFrame;
- (NSRect)frame;
- (NSSize)size;
- (NSComparisonResult)compareWidth:(AICustomTabCell *)tab;
- (NSTabViewItem *)tabViewItem;
- (void)drawWithFrame:(NSRect)rect inView:(NSView *)controlView;
- (void)drawWithFrame:(NSRect)rect inView:(NSView *)controlView ignoreSelection:(BOOL)ignoreSelection;
- (void)addTrackingRectsInView:(NSView *)view withFrame:(NSRect)trackRect cursorLocation:(NSPoint)cursorLocation;
- (void)removeTrackingRectsFromView:(NSView *)view;
- (void)mouseEntered:(NSEvent *)theEvent;
- (void)mouseExited:(NSEvent *)theEvent;
- (BOOL)willTrackMouse:(NSEvent *)theEvent inRect:(NSRect)cellFrame ofView:(NSView *)controlView;
- (BOOL)startTrackingAt:(NSPoint)startPoint inView:(NSView *)controlView;
- (BOOL)continueTracking:(NSPoint)lastPoint at:(NSPoint)currentPoint inView:(NSView *)controlView;
- (void)stopTracking:(NSPoint)lastPoint at:(NSPoint)stopPoint inView:(NSView *)controlView mouseIsUp:(BOOL)flag;
- (NSAttributedString *)attributedLabel;

@end
