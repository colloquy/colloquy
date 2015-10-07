#import <Cocoa/Cocoa.h>

@interface JVDetailCell : NSImageCell

@property (strong) NSImage *statusImage;
@property (strong) NSImage *highlightedImage;
@property (copy) NSString *mainText;
@property (copy) NSString *informationText;
@property NSLineBreakMode lineBreakMode;
@property BOOL boldAndWhiteOnHighlight;
@property NSUInteger statusNumber;
@property NSUInteger importantStatusNumber;
@property CGFloat leftMargin;

@end
