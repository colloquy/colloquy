#import <AppKit/NSImage.h>

@interface NSImage (NSImageAdditions)
+ (NSImage *) imageNamed:(NSString *) name forClass:(Class) class;
- (void) tileInRect:(NSRect) rect;
@end
