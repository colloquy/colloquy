#import <AppKit/NSImageCell.h>

@interface JVDetailCell : NSImageCell {
	@private
	NSImage *_altImage;
	NSString *_mainText;
	NSString *_infoText;
}
- (void) setAlternateImage:(NSImage *) image;
- (NSImage *) alternateImage;

- (void) setMainText:(NSString *) text;
- (NSString *) mainText;

- (void) setInformationText:(NSString *) text;
- (NSString *) informationText;
@end
