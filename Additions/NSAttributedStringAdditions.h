extern NSString *NSChatWindowsIRCFormatType;
extern NSString *NSChatCTCPTwoFormatType;

#define JVItalicObliquenessValue 0.16

@interface NSAttributedString (NSAttributedStringHTMLAdditions)
#if SYSTEM(MAC)
+ (instancetype) attributedStringWithHTMLFragment:(NSString *) fragment baseURL:(NSURL *) url;

+ (instancetype) attributedStringWithChatFormat:(NSData *) data options:(NSDictionary *) options;
- (instancetype) initWithChatFormat:(NSData *) data options:(NSDictionary *) options;
#endif

- (NSString *) HTMLFormatWithOptions:(NSDictionary *) options;
- (NSData *) chatFormatWithOptions:(NSDictionary *) options;

- (NSAttributedString *) cq_stringByRemovingCharactersInSet:(NSCharacterSet *) set;

- (NSAttributedString *) attributedSubstringFromIndex:(NSUInteger) index;
- (NSArray *) cq_componentsSeparatedByCharactersInSet:(NSCharacterSet *) characterSet;
- (NSAttributedString *) cq_stringByTrimmingCharactersInSet:(NSCharacterSet *) characterSet;
@end
