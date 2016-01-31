#import <Cocoa/Cocoa.h>

@interface JVDetailCell : NSImageCell
@property (copy) NSImage *statusImage;
@property NSUInteger statusNumber;
@property NSUInteger importantStatusNumber;

@property (copy) NSImage *highlightedImage;

@property (copy) NSString *mainText;
@property (copy) NSString *informationText;

@property BOOL boldAndWhiteOnHighlight;
@property CGFloat leftMargin;
@end
