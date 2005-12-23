@interface MVTextView : NSTextView {
    NSDictionary *defaultTypingAttributes;
	NSSize lastPostedSize;
	NSSize _desiredSizeCached;
	BOOL _usesSystemCompleteOnTab;
	BOOL _tabCompletting;
	BOOL _ignoreSelectionChanges;
	BOOL _complettingWithSuffix;
	NSString *_lastCompletionMatch;
	NSString *_lastCompletionPrefix;
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
- (NSArray *) textView:(NSTextView *) textView stringCompletionsForPrefix:(NSString *) prefix;
- (void) textView:(NSTextView *) textView selectedCompletion:(NSString *) completion fromPrefix:(NSString *) prefix;
@end
