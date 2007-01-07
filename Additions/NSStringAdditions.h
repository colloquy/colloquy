BOOL isValidUTF8( const char *s, unsigned len );

@interface NSString (NSStringAdditions)
+ (NSString *) locallyUniqueString;

+ (unsigned long) scriptTypedEncodingFromStringEncoding:(NSStringEncoding) encoding;
+ (NSStringEncoding) stringEncodingFromScriptTypedEncoding:(unsigned long) encoding;

- (BOOL) isCaseInsensitiveEqualToString:(NSString *) string;
- (BOOL) hasCaseInsensitivePrefix:(NSString *) prefix;
- (BOOL) hasCaseInsensitiveSuffix:(NSString *) suffix;
- (BOOL) hasCaseInsensitiveSubstring:(NSString *) substring;

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
