@interface MVTextView : NSTextView {
    NSDictionary *defaultTypingAttributes;
	NSSize lastPostedSize;
	NSSize _desiredSizeCached;
	BOOL _usesSystemCompleteOnTab;
	BOOL _tabCompletting;
	BOOL _complettingWithSuffix;
	BOOL _firstTabComplettingBeep;
}
- (BOOL) checkKeyEvent:(NSEvent *) event;

- (void) setBaseFont:(NSFont *) font;

- (void) reset:(id) sender;

- (NSSize) minimumSizeForContent;

- (void) bold:(id) sender;
- (void) italic:(id) sender;

- (void) setUsesSystemCompleteOnTab:(BOOL) use;
- (BOOL) usesSystemCompleteOnTab;

- (BOOL) autocompleteWithSuffix:(BOOL) suffix;
@end

@interface NSObject (MVTextViewDelegate)
- (BOOL) textView:(NSTextView *) textView functionKeyPressed:(NSEvent *) event;
- (BOOL) textView:(NSTextView *) textView enterKeyPressed:(NSEvent *) event;
- (BOOL) textView:(NSTextView *) textView returnKeyPressed:(NSEvent *) event;
- (BOOL) textView:(NSTextView *) textView escapeKeyPressed:(NSEvent *) event;
- (NSArray *) completionsFor:(NSString *) inFragment;
@end
