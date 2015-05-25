NS_ASSUME_NONNULL_BEGIN

BOOL isValidUTF8( const char *string, NSUInteger length );

#define is7Bit(ch) (((ch) & 0x80) == 0)
#define isUTF8Tupel(ch) (((ch) & 0xE0) == 0xC0)
#define isUTF8LongTupel(ch) (((ch) & 0xFE) == 0xC0)
#define isUTF8Triple(ch) (((ch) & 0xF0) == 0xE0)
#define isUTF8LongTriple(ch1,ch2) (((ch1) & 0xFF) == 0xE0 && ((ch2) & 0xE0) == 0x80)
#define isUTF8Quartet(ch) (((ch) & 0xF8) == 0xF0)
#define isUTF8LongQuartet(ch1,ch2) (((ch1) & 0xFF) == 0xF0 && ((ch2) & 0xF0) == 0x80)
#define isUTF8Quintet(ch) (((ch) & 0xFC) == 0xF8)
#define isUTF8LongQuintet(ch1,ch2) (((ch1) & 0xFF) == 0xF8 && ((ch2) & 0xF8) == 0x80)
#define isUTF8Sextet(ch) (((ch) & 0xFE) == 0xFC)
#define isUTF8LongSextet(ch1,ch2) (((ch1) & 0xFF) == 0xFC && ((ch2) & 0xFC) == 0x80)
#define isUTF8Cont(ch) (((ch) & 0xC0) == 0x80)

@interface NSString (NSStringAdditions)
+ (NSString *) locallyUniqueString;

#if ENABLE(SCRIPTING)
+ (unsigned long) scriptTypedEncodingFromStringEncoding:(NSStringEncoding) encoding;
+ (NSStringEncoding) stringEncodingFromScriptTypedEncoding:(unsigned long) encoding;
#endif

+ (NSArray *) knownEmoticons;
+ (NSSet *) knownEmojiWithEmoticons;

- (instancetype) initWithChatData:(NSData *) data encoding:(NSStringEncoding) encoding;

- (BOOL) isCaseInsensitiveEqualToString:(NSString *) string;
- (BOOL) hasCaseInsensitivePrefix:(NSString *) prefix;
- (BOOL) hasCaseInsensitiveSuffix:(NSString *) suffix;
- (BOOL) hasCaseInsensitiveSubstring:(NSString *) substring;

@property (readonly, copy) NSString *stringByEncodingXMLSpecialCharactersAsEntities;
@property (readonly, copy) NSString *stringByDecodingXMLSpecialCharacterEntities;

- (NSString *) stringByEscapingCharactersInSet:(NSCharacterSet *) set;
- (NSString *) stringByReplacingCharactersInSet:(NSCharacterSet *) set withString:(NSString *) string;

@property (readonly, copy) NSString *stringByEncodingIllegalURLCharacters;
@property (readonly, copy) NSString *stringByDecodingIllegalURLCharacters;

@property (readonly, copy) NSString *stringByStrippingIllegalXMLCharacters;
@property (readonly, copy) NSString *stringByStrippingXMLTags;

+ (NSString *) stringByReversingString:(NSString *) normalString;

@property (readonly, copy) NSString *stringWithDomainNameSegmentOfAddress;

@property (readonly, copy) NSString *fileName;

@property (getter=isValidIRCMask, readonly) BOOL validIRCMask;
@property (readonly, copy) NSString *IRCNickname;
@property (readonly, copy) NSString *IRCUsername;
@property (readonly, copy) NSString *IRCHostname;
@property (readonly, copy) NSString *IRCRealname;

@property (readonly) BOOL containsEmojiCharacters;
- (BOOL) containsEmojiCharactersInRange:(NSRange) range;
- (NSRange) rangeOfEmojiCharactersInRange:(NSRange) range;

@property (readonly) BOOL containsTypicalEmoticonCharacters;

@property (readonly, copy) NSString *stringBySubstitutingEmojiForEmoticons;
@property (readonly, copy) NSString *stringBySubstitutingEmoticonsForEmoji;

- (BOOL) isMatchedByRegex:(NSString *) regex;
- (BOOL) isMatchedByRegex:(NSString *) regex options:(NSRegularExpressionOptions) options inRange:(NSRange) range error:(NSError **) error;

- (NSRange) rangeOfRegex:(NSString *) regex inRange:(NSRange) range;
- (NSRange) rangeOfRegex:(NSString *) regex options:(NSRegularExpressionOptions) options inRange:(NSRange) range capture:(NSInteger) capture error:(NSError **) error;

- (NSString *) stringByMatching:(NSString *) regex capture:(NSInteger) capture;
- (NSString *) stringByMatching:(NSString *) regex options:(NSRegularExpressionOptions) options inRange:(NSRange) range capture:(NSInteger) capture error:(NSError **) error;

- (NSArray *) captureComponentsMatchedByRegex:(NSString *) regex options:(NSRegularExpressionOptions) options range:(NSRange) range error:(NSError **) error;

- (NSString *) stringByReplacingOccurrencesOfRegex:(NSString *) regex withString:(NSString *) replacement;
- (NSString *) stringByReplacingOccurrencesOfRegex:(NSString *) regex withString:(NSString *) replacement options:(NSRegularExpressionOptions) options range:(NSRange) searchRange error:(NSError **) error;

- (NSString *) cq_stringByRemovingCharactersInSet:(NSCharacterSet *) set;
@end

@interface NSMutableString (NSMutableStringAdditions)
- (void) encodeXMLSpecialCharactersAsEntities;
- (void) decodeXMLSpecialCharacterEntities;

- (void) escapeCharactersInSet:(NSCharacterSet *) set;
- (void) replaceCharactersInSet:(NSCharacterSet *) set withString:(NSString *) string;

- (void) encodeIllegalURLCharacters;
- (void) decodeIllegalURLCharacters;

- (void) stripIllegalXMLCharacters;
- (void) stripXMLTags;

- (void) substituteEmoticonsForEmoji;
- (void) substituteEmoticonsForEmojiInRange:(NSRangePointer) range;
- (void) substituteEmoticonsForEmojiInRange:(NSRangePointer) range withXMLSpecialCharactersEncodedAsEntities:(BOOL) encoded;

- (void) substituteEmojiForEmoticons;
- (void) substituteEmojiForEmoticonsInRange:(NSRangePointer) range;
- (void) substituteEmojiForEmoticonsInRange:(NSRangePointer) range encodeXMLSpecialCharactersAsEntities:(BOOL) encode;
@end

NS_ASSUME_NONNULL_END
