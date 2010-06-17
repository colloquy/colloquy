@protocol CQChatTranscriptViewDelegate;

@interface CQChatTranscriptView : UIWebView <UIWebViewDelegate> {
	@protected
	IBOutlet id <CQChatTranscriptViewDelegate> transcriptDelegate;
	UIView *_blockerView;
	NSMutableArray *_pendingPreviousSessionComponents;
	NSMutableArray *_pendingComponents;
	NSString *_styleIdentifier;
	BOOL _scrolling;
	BOOL _loading;
}
@property (nonatomic, assign) id <CQChatTranscriptViewDelegate> transcriptDelegate;

@property (nonatomic, copy) NSString *styleIdentifier;

- (void) addPreviousSessionComponents:(NSArray *) components;
- (void) addComponents:(NSArray *) components animated:(BOOL) animated;
- (void) addComponent:(NSDictionary *) component animated:(BOOL) animated;

- (void) scrollToBottomAnimated:(BOOL) animated;
- (void) flashScrollIndicators;
- (void) reset;
@end

@protocol CQChatTranscriptViewDelegate <NSObject>
@optional
- (BOOL) transcriptView:(CQChatTranscriptView *) transcriptView handleOpenURL:(NSURL *) url;
@end
