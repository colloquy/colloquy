@protocol CQTextCompletionViewDelegate;

@interface CQTextCompletionView : UIView {
	IBOutlet id <CQTextCompletionViewDelegate> delegate;
	CGSize _completionTextSizes[5];
	NSUInteger _selectedCompletion;
	NSArray *_completions;
}
@property (nonatomic, copy) NSArray *completions;
@property (nonatomic) NSUInteger selectedCompletion;

@property (nonatomic,assign) id <CQTextCompletionViewDelegate> delegate;
@end

@protocol CQTextCompletionViewDelegate <NSObject>
@optional
- (void) textCompletionView:(CQTextCompletionView *) textCompletionView didSelectCompletion:(NSString *) completion;
- (void) textCompletionViewDidClose:(CQTextCompletionView *) textCompletionView;
@end
