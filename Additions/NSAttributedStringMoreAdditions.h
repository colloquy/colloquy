#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSAttributedString (NSAttributedStringXMLAdditions)
+ (nullable instancetype) attributedStringWithXHTMLTree:(struct _xmlNode *) node baseURL:(nullable NSURL *) base defaultAttributes:(nullable NSDictionary *) attributes;
+ (nullable instancetype) attributedStringWithXHTMLFragment:(NSString *) fragment baseURL:(nullable NSURL *) base defaultAttributes:(nullable NSDictionary *) attributes;

- (nullable instancetype) initWithXHTMLTree:(struct _xmlNode *) node baseURL:(nullable NSURL *) base defaultAttributes:(nullable NSDictionary *) attributes;
- (nullable instancetype) initWithXHTMLFragment:(NSString *) fragment baseURL:(nullable NSURL *) base defaultAttributes:(nullable NSDictionary *) attributes;
@end

@interface NSMutableAttributedString (NSMutableAttributedStringHTMLAdditions)
- (void) makeLinkAttributesAutomatically;
@end

NS_ASSUME_NONNULL_END
