#import <Foundation/NSString.h>

@interface NSMutableString (NSMutableStringReplaceAdditions)
- (void) replaceString:(NSString *) search withString:(NSString *) replace maxTimes:(unsigned) max;
@end

@interface NSString (NSStringHTMLAdditions)
+ (NSString *) stringWithHTMLStripedFromString:(NSString *) aString;
+ (NSString *) stringWithHTMLStripedFromString:(NSString *) aString encoding:(NSStringEncoding) encoding;
@end

@interface NSString (NSStringLengthAdditions)
- (unsigned long) UTF8StringByteLength;
@end