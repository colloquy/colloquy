@interface NSTextStorage (NSTextStorageAdditions)
- (NSColor *) backgroundColor;
- (void) setBackgroundColor:(NSColor *) color;

- (NSString *) hyperlink;
- (void) setHyperlink:(NSString *) link;

- (BOOL) boldState;
- (void) setBoldState:(BOOL) bold;

- (BOOL) italicState;
- (void) setItalicState:(BOOL) italic;

- (BOOL) underlineState;
- (void) setUnderlineState:(BOOL) underline;

- (NSArray *) styleClasses;
- (void) setStyleClasses:(NSArray *) classes;

- (NSString *) XHTMLStart;
- (void) setXHTMLStart:(NSString *) html;

- (NSString *) XHTMLEnd;
- (void) setXHTMLEnd:(NSString *) html;
@end
