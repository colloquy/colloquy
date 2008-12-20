@protocol CQChatTranscriptViewDelegate;

typedef enum {
	CQChatMessageNormalType,
	CQChatMessageNoticeType
} CQChatMessageType;

@interface CQChatTranscriptView : UIWebView <UIWebViewDelegate> {
	IBOutlet id <CQChatTranscriptViewDelegate> delegate;
	NSMutableArray *_pendingFormerMessages;
	NSMutableArray *_pendingMessages;
	BOOL _scrolling;
	BOOL _loading;
}
@property (nonatomic, assign) id <CQChatTranscriptViewDelegate> delegate;

- (void) addFormerMessages:(NSArray *) messages;
- (void) addMessages:(NSArray *) messages;
- (void) addMessage:(NSDictionary *) message;

- (void) scrollToBottomAnimated:(BOOL) animated;
- (void) flashScrollIndicators;
@end

@protocol CQChatTranscriptViewDelegate <NSObject>
@optional
- (BOOL) transcriptView:(CQChatTranscriptView *) transcriptView handleOpenURL:(NSURL *) url;
@end
