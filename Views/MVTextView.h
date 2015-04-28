@protocol MVTextViewDelegate;

@interface MVTextView : NSTextView {
    NSDictionary *defaultTypingAttributes;
	NSSize lastPostedSize;
	NSSize _desiredSizeCached;
	BOOL _tabCompletting;
	BOOL _ignoreSelectionChanges;
	BOOL _complettingWithSuffix;
	NSString *_lastCompletionMatch;
	NSString *_lastCompletionPrefix;
}
- (BOOL) checkKeyEvent:(NSEvent *) event;

- (void) setBaseFont:(NSFont *) font;

- (IBAction) reset:(id) sender;

@property (readonly) NSSize minimumSizeForContent;

- (IBAction) bold:(id) sender;
- (IBAction) italic:(id) sender;

@property BOOL usesSystemCompleteOnTab;

- (BOOL) autocompleteWithSuffix:(BOOL) suffix;

- (id <MVTextViewDelegate>)delegate;
- (void)setDelegate:(id <MVTextViewDelegate>)anObject;
@end

@protocol MVTextViewDelegate <NSTextViewDelegate>
@optional
- (BOOL) textView:(NSTextView *) textView functionKeyPressed:(NSEvent *) event;
- (BOOL) textView:(NSTextView *) textView enterKeyPressed:(NSEvent *) event;
- (BOOL) textView:(NSTextView *) textView returnKeyPressed:(NSEvent *) event;
- (BOOL) textView:(NSTextView *) textView escapeKeyPressed:(NSEvent *) event;
- (NSArray *) textView:(NSTextView *) textView stringCompletionsForPrefix:(NSString *) prefix;
- (void) textView:(NSTextView *) textView selectedCompletion:(NSString *) completion fromPrefix:(NSString *) prefix;
@end
