#import <Foundation/NSString.h>

@interface NSString (NSStringAdditions)
+ (NSString *) mimeCharsetTagFromStringEncoding:(NSStringEncoding) encoding;
- (unsigned long) UTF8StringByteLength;
@end
