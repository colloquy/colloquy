#import <AppKit/NSTextStorage.h>

@class NSColor;

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
@end
