@interface NSString (NSStringAdditions)
+ (NSString *) locallyUniqueString;

+ (NSString *) mimeCharsetTagFromStringEncoding:(NSStringEncoding) encoding;

- (unsigned long) UTF8StringByteLength;

- (id) initWithBytes:(const void *) bytes encoding:(NSStringEncoding) encoding;
+ (id) stringWithBytes:(const void *) bytes encoding:(NSStringEncoding) encoding;

- (const char *) bytesUsingEncoding:(NSStringEncoding) encoding allowLossyConversion:(BOOL) lossy;
- (const char *) bytesUsingEncoding:(NSStringEncoding) encoding;

- (NSString *) stringByEncodingXMLSpecialCharactersAsEntities;
- (NSString *) stringByDecodingXMLSpecialCharacterEntities;

- (NSString *) stringByEscapingCharactersInSet:(NSCharacterSet *) set;

- (NSString *) stringByEncodingIllegalURLCharacters;
- (NSString *) stringByDecodingIllegalURLCharacters;

- (NSString *) stringByStrippingIllegalXMLCharacters;
@end

@interface NSMutableString (NSMutableStringAdditions)
- (void) encodeXMLSpecialCharactersAsEntities;
- (void) decodeXMLSpecialCharacterEntities;

- (void) escapeCharactersInSet:(NSCharacterSet *) set;

- (void) encodeIllegalURLCharacters;
- (void) decodeIllegalURLCharacters;

- (void) stripIllegalXMLCharacters;
@end
