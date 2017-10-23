#import <Foundation/NSAttributedString.h>

NS_ASSUME_NONNULL_BEGIN

COLLOQUY_EXPORT extern NSString *NSChatWindowsIRCFormatType;
COLLOQUY_EXPORT extern NSString *NSChatCTCPTwoFormatType;

#define JVItalicObliquenessValue 0.16

@interface NSAttributedString (NSAttributedStringHTMLAdditions)
#if !((defined(TARGET_OS_IPHONE) && TARGET_OS_IPHONE) || (defined(TARGET_OS_TV) && TARGET_OS_TV)) 
+ (instancetype) attributedStringWithHTMLFragment:(NSString *) fragment;

+ (instancetype) attributedStringWithChatFormat:(NSData *) data options:(NSDictionary *) options;
- (instancetype) initWithChatFormat:(NSData *) data options:(NSDictionary *) options;
- (NSString *) HTMLFormatWithOptions:(NSDictionary *) options;
#endif

- (NSData *) chatFormatWithOptions:(NSDictionary *) options;

- (NSAttributedString *) cq_stringByRemovingCharactersInSet:(NSCharacterSet *) set;

- (NSAttributedString *) attributedSubstringFromIndex:(NSUInteger) index;
- (NSArray <NSAttributedString *> *) cq_componentsSeparatedByCharactersInSet:(NSCharacterSet *) characterSet;
- (NSAttributedString *) cq_stringByTrimmingCharactersInSet:(NSCharacterSet *) characterSet;
@end

NS_ASSUME_NONNULL_END
