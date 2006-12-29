@interface NSString (NSStringAdditions)
+ (NSString *) locallyUniqueString;

+ (NSString *) mimeCharsetTagFromStringEncoding:(NSStringEncoding) encoding;
+ (unsigned long) scriptTypedEncodingFromStringEncoding:(NSStringEncoding) encoding;
+ (NSStringEncoding) stringEncodingFromScriptTypedEncoding:(unsigned long) encoding;

- (id) initWithBytes:(const void *) bytes encoding:(NSStringEncoding) encoding;
- (id) initWithBytesNoCopy:(void *) bytes encoding:(NSStringEncoding) encoding freeWhenDone:(BOOL) free;
+ (id) stringWithBytes:(const void *) bytes encoding:(NSStringEncoding) encoding;
+ (id) stringWithBytesNoCopy:(void *) bytes encoding:(NSStringEncoding) encoding freeWhenDone:(BOOL) free;

- (const char *) bytesUsingEncoding:(NSStringEncoding) encoding allowLossyConversion:(BOOL) lossy;
- (const char *) bytesUsingEncoding:(NSStringEncoding) encoding;

- (NSString *) stringByEncodingXMLSpecialCharactersAsEntities;
- (NSString *) stringByDecodingXMLSpecialCharacterEntities;

- (NSString *) stringByEscapingCharactersInSet:(NSCharacterSet *) set;

- (NSString *) stringByEncodingIllegalURLCharacters;
- (NSString *) stringByDecodingIllegalURLCharacters;

- (NSString *) stringByStrippingIllegalXMLCharacters;

- (NSString *) stringWithDomainNameSegmentOfAddress;
@end

@interface NSMutableString (NSMutableStringAdditions)
- (void) encodeXMLSpecialCharactersAsEntities;
- (void) decodeXMLSpecialCharacterEntities;

- (void) escapeCharactersInSet:(NSCharacterSet *) set;

- (void) encodeIllegalURLCharacters;
- (void) decodeIllegalURLCharacters;

- (void) stripIllegalXMLCharacters;
@end
