extern NSString *NSChatWindowsIRCFormatType;
extern NSString *NSChatCTCPTwoFormatType;

#define JVItalicObliquenessValue 0.16

@interface NSAttributedString (NSAttributedStringHTMLAdditions)
+ (id) attributedStringWithHTMLFragment:(NSString *) fragment baseURL:(NSURL *) url;

+ (id) attributedStringWithChatFormat:(NSData *) data options:(NSDictionary *) options;
- (id) initWithChatFormat:(NSData *) data options:(NSDictionary *) options;

- (NSString *) HTMLFormatWithOptions:(NSDictionary *) options;
- (NSData *) chatFormatWithOptions:(NSDictionary *) options;
@end
