extern NSString *NSChatWindowsIRCFormatType;
extern NSString *NSChatCTCPTwoFormatType;

#define JVItalicObliquenessValue 0.16

@interface NSAttributedString (NSAttributedStringHTMLAdditions)
#if SYSTEM(MAC)
+ (id) attributedStringWithHTMLFragment:(NSString *) fragment baseURL:(NSURL *) url;

+ (id) attributedStringWithChatFormat:(NSData *) data options:(NSDictionary *) options;
- (id) initWithChatFormat:(NSData *) data options:(NSDictionary *) options;
#endif

- (NSString *) HTMLFormatWithOptions:(NSDictionary *) options;
- (NSData *) chatFormatWithOptions:(NSDictionary *) options;

#if SYSTEM(MAC)
- (NSAttributedString *) cq_stringByRemovingCharactersInSet:(NSCharacterSet *) set;
#endif

- (NSString *) cq_stringByRemovingCharactersInSet:(NSCharacterSet *) set;

- (NSAttributedString *) attributedSubstringFromIndex:(NSUInteger) index;
- (NSArray *) cq_componentsSeparatedByCharactersInSet:(NSCharacterSet *) characterSet;
- (NSAttributedString *) cq_stringByTrimmingCharactersInSet:(NSCharacterSet *) characterSet;
@end
