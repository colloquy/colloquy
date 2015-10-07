@interface NSAttributedString (NSAttributedStringXMLAdditions)
+ (instancetype) attributedStringWithXHTMLTree:(void *) node baseURL:(NSURL *) base defaultAttributes:(NSDictionary *) attributes;
+ (instancetype) attributedStringWithXHTMLFragment:(NSString *) fragment baseURL:(NSURL *) base defaultAttributes:(NSDictionary *) attributes;

- (instancetype) initWithXHTMLTree:(void *) node baseURL:(NSURL *) base defaultAttributes:(NSDictionary *) attributes;
- (instancetype) initWithXHTMLFragment:(NSString *) fragment baseURL:(NSURL *) base defaultAttributes:(NSDictionary *) attributes;
@end

@interface NSMutableAttributedString (NSMutableAttributedStringHTMLAdditions)
- (void) makeLinkAttributesAutomatically;
@end
