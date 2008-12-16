@protocol CQChatTranscriptViewDelegate;

typedef enum {
	CQChatMessageNormalType,
	CQChatMessageNoticeType
} CQChatMessageType;

@interface CQChatTranscriptView : UIWebView <UIWebViewDelegate> {
	IBOutlet id <CQChatTranscriptViewDelegate> delegate;
	NSMutableArray *_pendingMessages;
	BOOL _stripMessageFormatting;
	BOOL _scrolling;
	BOOL _loading;
}
@property (nonatomic, assign) id <CQChatTranscriptViewDelegate> delegate;

@property (nonatomic) BOOL stripMessageFormatting;

- (void) addMessages:(NSArray *) messages;
- (void) addMessage:(NSDictionary *) info;

- (void) scrollToBottom;
- (void) flashScrollIndicators;
@end

@protocol CQChatTranscriptViewDelegate <NSObject>
@optional
- (BOOL) transcriptView:(CQChatTranscriptView *) transcriptView handleOpenURL:(NSURL *) url;
- (NSArray *) highlightWordsForTranscriptView:(CQChatTranscriptView *) transcriptView;
- (void) transcriptView:(CQChatTranscriptView *) transcriptView highlightedMessageWithWord:(NSString *) highlightWord;
- (NSStringEncoding) transcriptView:(CQChatTranscriptView *) transcriptView encodingForMessageData:(NSData *) message;
@end
