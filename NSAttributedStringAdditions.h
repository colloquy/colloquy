#import <AppKit/NSAttributedString.h>

@interface NSAttributedString (NSAttributedStringHTMLAdditions)
+ (id) attributedStringWithHTMLFragment:(NSString *) fragment baseURL:(NSURL *) url;

+ (id) attributedStringWithIRCFormat:(NSData *) data options:(NSDictionary *) options;
- (id) initWithIRCFormat:(NSData *) data options:(NSDictionary *) options;

- (NSString *) HTMLFormatWithOptions:(NSDictionary *) options;
- (NSData *) IRCFormatWithOptions:(NSDictionary *) options;
@end
