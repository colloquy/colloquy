@interface NSAttributedString (NSAttributedStringXMLAdditions)
+ (id) attributedStringWithXHTMLTree:(void *) node baseURL:(NSURL *) base defaultFont:(NSFont *) font;
- (id) initWithXHTMLTree:(void *) node baseURL:(NSURL *) base defaultFont:(NSFont *) font;
@end

@interface NSMutableAttributedString (NSMutableAttributedStringHTMLAdditions)
- (void) makeLinkAttributesAutomatically;
@end