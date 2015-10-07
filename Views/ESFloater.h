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

+ (instancetype)floaterWithImage:(NSImage *)inImage styleMask:(NSUInteger)styleMask title:(NSString *) title;
- (instancetype)initWithImage:(NSImage *)inImage styleMask:(NSUInteger)styleMask title:(NSString *) title NS_DESIGNATED_INITIALIZER;
- (void)moveFloaterToPoint:(NSPoint)inPoint;
- (IBAction)close:(id)sender;
- (void)endFloater;
@property (strong) NSImage *image;
- (void)setVisible:(BOOL)inVisible animate:(BOOL)animate;
- (void)setMaxOpacity:(CGFloat)inMaxOpacity;

@end
