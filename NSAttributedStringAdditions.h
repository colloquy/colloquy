#import <AppKit/NSAttributedString.h>

@interface NSAttributedString (NSAttributedStringHTMLAdditions)
- (NSData *) HTMLWithOptions:(NSDictionary *) options usingEncoding:(NSStringEncoding) encoding allowLossyConversion:(BOOL) loss;
@end
