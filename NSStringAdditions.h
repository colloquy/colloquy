#import <Foundation/NSString.h>

@interface NSString (NSStringAdditions)
+ (NSString *) mimeCharsetTagFromStringEncoding:(NSStringEncoding) encoding;
- (unsigned long) UTF8StringByteLength;
- (NSString *) stringByEncodingXMLSpecialCharactersAsEntities;
- (NSString *) stringByDecodingXMLSpecialCharacterEntities;
- (NSString *) stringByEscapingCharactersInSet:(NSCharacterSet *) set;
@end

@interface NSMutableString (NSMutableStringAdditions)
- (void) encodeXMLSpecialCharactersAsEntities;
- (void) decodeXMLSpecialCharacterEntities;
- (void) escapeCharactersInSet:(NSCharacterSet *) set;
@end
