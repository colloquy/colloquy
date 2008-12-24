@protocol CQChatTranscriptViewDelegate;

@interface CQChatTranscriptView : UIWebView <UIWebViewDelegate> {
	IBOutlet id <CQChatTranscriptViewDelegate> delegate;
	NSMutableArray *_pendingPreviousSessionComponents;
	NSMutableArray *_pendingComponents;
	BOOL _scrolling;
	BOOL _loading;
}
@property (nonatomic, assign) id <CQChatTranscriptViewDelegate> delegate;

- (void) addPreviousSessionComponents:(NSArray *) components;
- (void) addComponents:(NSArray *) components animated:(BOOL) animated;
- (void) addComponent:(NSDictionary *) component animated:(BOOL) animated;

- (void) scrollToBottomAnimated:(BOOL) animated;
- (void) flashScrollIndicators;
@end

@protocol CQChatTranscriptViewDelegate <NSObject>
@optional
- (BOOL) transcriptView:(CQChatTranscriptView *) transcriptView handleOpenURL:(NSURL *) url;
@end
