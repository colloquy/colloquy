@class MVChatUser;
@protocol CQChatTranscriptViewDelegate;

typedef enum {
	CQChatMessageNormalType,
	CQChatMessageNoticeType
} CQChatMessageType;

@interface CQChatTranscriptView : UIWebView <UIWebViewDelegate> {
	IBOutlet id <CQChatTranscriptViewDelegate> delegate;
	BOOL _scrolling;
}
@property (nonatomic, assign) id <CQChatTranscriptViewDelegate> delegate;

- (void) addMessageToDisplay:(NSData *) message fromUser:(MVChatUser *) user withAttributes:(NSDictionary *) msgAttributes withIdentifier:(NSString *) identifier andType:(CQChatMessageType) type;

- (void) scrollToBottom;
- (void) flashScrollIndicators;
@end

@protocol CQChatTranscriptViewDelegate
@optional
@end
