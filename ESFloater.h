//  Adium, ESFloater.h
//  Created by Evan Schoenberg on Wed Oct 08 2003.

#import <Foundation/NSObject.h>
#import <AppKit/NSNibDeclarations.h>

@class NSImageView;
@class NSPanel;
@class NSTimer;
@class NSImage;

@interface ESFloater : NSObject {
    NSImageView			*staticView;
    NSPanel				*panel;
    BOOL                windowIsVisible;
    NSTimer             *visibilityTimer;
    float               maxOpacity;
}

+ (id)floaterWithImage:(NSImage *)inImage styleMask:(unsigned int)styleMask title:(NSString *) title;
- (void)moveFloaterToPoint:(NSPoint)inPoint;
- (IBAction)close:(id)sender;
- (void)endFloater;
- (void)setImage:(NSImage *)inImage;
- (NSImage *)image;
- (void)setVisible:(BOOL)inVisible animate:(BOOL)animate;
- (void)setMaxOpacity:(float)inMaxOpacity;

@end
