#import <AppKit/NSAttributedString.h>

@class NSFont;
@class NSURL;

@interface NSAttributedString (NSAttributedStringXMLAdditions)
+ (id) attributedStringWithXHTMLTree:(void *) node baseURL:(NSURL *) base defaultFont:(NSFont *) font;
- (id) initWithXHTMLTree:(void *) node baseURL:(NSURL *) base defaultFont:(NSFont *) font;
@end
