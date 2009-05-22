//
//  ESFloater.h
//  Adium
//
//  Created by Evan Schoenberg on Wed Oct 08 2003.
//

#import <Foundation/Foundation.h>

@interface ESFloater : NSObject {
    NSImageView			*staticView;
    NSPanel				*panel;
    BOOL                windowIsVisible;
    NSTimer             *visibilityTimer;
    CGFloat             maxOpacity;
}

+ (id)floaterWithImage:(NSImage *)inImage styleMask:(NSUInteger)styleMask title:(NSString *) title;
- (id)initWithImage:(NSImage *)inImage styleMask:(NSUInteger)styleMask title:(NSString *) title;
- (void)moveFloaterToPoint:(NSPoint)inPoint;
- (IBAction)close:(id)sender;
- (void)endFloater;
- (void)setImage:(NSImage *)inImage;
- (NSImage *)image;
- (void)setVisible:(BOOL)inVisible animate:(BOOL)animate;
- (void)setMaxOpacity:(CGFloat)inMaxOpacity;

@end
