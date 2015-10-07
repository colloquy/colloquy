@protocol CQTextCompletionViewDelegate;

NS_ASSUME_NONNULL_BEGIN

@interface CQTextCompletionView : UIView
@property (nonatomic, copy) NSArray *completions;
@property (nonatomic) NSUInteger selectedCompletion;
@property (nonatomic, getter=isCloseSelected) BOOL closeSelected;

@property (nonatomic, nullable, weak) IBOutlet id <CQTextCompletionViewDelegate> delegate;
@end

@protocol CQTextCompletionViewDelegate <NSObject>
@optional
- (void) textCompletionView:(CQTextCompletionView *) textCompletionView didSelectCompletion:(NSString *) completion;
- (void) textCompletionViewDidClose:(CQTextCompletionView *) textCompletionView;
@end

NS_ASSUME_NONNULL_END
