#import <Foundation/NSString.h>

NS_ASSUME_NONNULL_BEGIN

COLLOQUY_EXPORT BOOL isValidUTF8( const char *string, NSUInteger length );

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
+ (OSType) scriptTypedEncodingFromStringEncoding:(NSStringEncoding) encoding;
+ (NSStringEncoding) stringEncodingFromScriptTypedEncoding:(OSType) encoding;
#endif

#if __has_feature(objc_class_property)
@property (class, readonly, copy) NSArray <NSString *> *knownEmoticons;
@property (class, readonly, copy) NSSet <NSString *> *knownEmojiWithEmoticons;
#else
+ (NSArray <NSString *> *) knownEmoticons;
+ (NSSet <NSString *> *) knownEmojiWithEmoticons;
#endif

- (instancetype) initWithChatData:(NSData *) data encoding:(NSStringEncoding) encoding;

- (BOOL) isCaseInsensitiveEqualToString:(NSString *) string;
- (BOOL) hasCaseInsensitivePrefix:(NSString *) prefix;
- (BOOL) hasCaseInsensitiveSuffix:(NSString *) suffix;
- (BOOL) hasCaseInsensitiveSubstring:(NSString *) substring;

@property (readonly, copy) NSString *stringByEncodingXMLSpecialCharactersAsEntities;
@property (readonly, copy) NSString *stringByDecodingXMLSpecialCharacterEntities;

- (NSString *) stringByEscapingCharactersInSet:(NSCharacterSet *) set;
- (NSString *) stringByReplacingCharactersInSet:(NSCharacterSet *) set withString:(NSString *) string;

@property (readonly, copy, nullable) NSString *stringByEncodingIllegalURLCharacters;
@property (readonly, copy, nullable) NSString *stringByDecodingIllegalURLCharacters;

@property (readonly, copy) NSString *stringByStrippingIllegalXMLCharacters;
@property (readonly, copy) NSString *stringByStrippingXMLTags;

@property (readonly, copy) NSString *cq_sentenceCaseString;
+ (NSString *) cq_stringByReversingString:(NSString *) normalString;

@property (readonly, copy) NSString *stringWithDomainNameSegmentOfAddress;

@property (readonly, copy) NSString *fileName;

@property (getter=isValidIRCMask, readonly) BOOL validIRCMask;
@property (readonly, copy, nullable) NSString *IRCNickname;
@property (readonly, copy, nullable) NSString *IRCUsername;
@property (readonly, copy, nullable) NSString *IRCHostname;
@property (readonly, copy, nullable) NSString *IRCRealname;

@property (readonly) BOOL containsEmojiCharacters;
- (BOOL) containsEmojiCharactersInRange:(NSRange) range;
- (NSRange) rangeOfEmojiCharactersInRange:(NSRange) range;

@property (readonly) BOOL containsTypicalEmoticonCharacters;

@property (readonly, copy) NSString *stringBySubstitutingEmojiForEmoticons;
@property (readonly, copy) NSString *stringBySubstitutingEmoticonsForEmoji;

- (BOOL) isMatchedByRegex:(NSString *) regex NS_SWIFT_UNAVAILABLE("Use 'isMached(byRegex:options:in:) throws' instead");
- (BOOL) isMatchedByRegex:(NSString *) regex options:(NSRegularExpressionOptions) options inRange:(NSRange) range error:(NSError **) error;

- (NSRange) rangeOfRegex:(NSString *) regex inRange:(NSRange) range NS_SWIFT_UNAVAILABLE("Use 'range(ofRegex:options:in:capture:) throws' instead");
- (NSRange) rangeOfRegex:(NSString *) regex options:(NSRegularExpressionOptions) options inRange:(NSRange) range capture:(NSInteger) capture error:(NSError **) error;

- (NSString *__nullable) stringByMatching:(NSString *) regex capture:(NSInteger) capture NS_SWIFT_UNAVAILABLE("Use 'matching(_:options:in:capture:) throws' instead");
- (NSString *__nullable) stringByMatching:(NSString *) regex options:(NSRegularExpressionOptions) options inRange:(NSRange) range capture:(NSInteger) capture error:(NSError **) error;

- (nullable NSArray <NSString *> *) captureComponentsMatchedByRegex:(NSString *) regex options:(NSRegularExpressionOptions) options range:(NSRange) range error:(NSError **) error;

- (nullable NSString *) stringByReplacingOccurrencesOfRegex:(NSString *) regex withString:(NSString *) replacement NS_SWIFT_UNAVAILABLE("Use 'stringByReplacingOccurrences(ofRegex:with:options:range:) throws' instead");
- (nullable NSString *) stringByReplacingOccurrencesOfRegex:(NSString *) regex withString:(NSString *) replacement options:(NSRegularExpressionOptions) options range:(NSRange) searchRange error:(NSError **) error;

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

- (BOOL) replaceOccurrencesOfRegex:(NSString *) regex withString:(NSString *) replacement NS_SWIFT_UNAVAILABLE("Use 'replaceOccurrences(ofRegex:with:options:range:) throws' instead");
- (BOOL) replaceOccurrencesOfRegex:(NSString *) regex withString:(NSString *) replacement options:(NSRegularExpressionOptions) options range:(NSRange) searchRange error:(NSError **) error;
@end

NS_ASSUME_NONNULL_END
