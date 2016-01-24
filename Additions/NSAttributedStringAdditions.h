#import <Foundation/NSAttributedString.h>

NS_ASSUME_NONNULL_BEGIN

extern NSString *NSChatWindowsIRCFormatType;
extern NSString *NSChatCTCPTwoFormatType;

#define JVItalicObliquenessValue 0.16

@interface NSAttributedString (NSAttributedStringHTMLAdditions)
#if !defined(TARGET_OS_IPHONE) || !TARGET_OS_IPHONE
+ (instancetype) attributedStringWithHTMLFragment:(NSString *) fragment;

+ (instancetype) attributedStringWithChatFormat:(NSData *) data options:(NSDictionary *) options;
- (instancetype) initWithChatFormat:(NSData *) data options:(NSDictionary *) options;
#endif

- (NSString *) HTMLFormatWithOptions:(NSDictionary *) options;
- (NSData *) chatFormatWithOptions:(NSDictionary *) options;

- (NSAttributedString *) cq_stringByRemovingCharactersInSet:(NSCharacterSet *) set;

- (NSAttributedString *) attributedSubstringFromIndex:(NSUInteger) index;
- (NSArray <NSAttributedString *> *) cq_componentsSeparatedByCharactersInSet:(NSCharacterSet *) characterSet;
- (NSAttributedString *) cq_stringByTrimmingCharactersInSet:(NSCharacterSet *) characterSet;
@end

NS_ASSUME_NONNULL_END
