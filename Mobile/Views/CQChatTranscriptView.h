@protocol CQChatTranscriptViewDelegate;

@interface CQChatTranscriptView : UIWebView <UIWebViewDelegate> {
	@protected
	IBOutlet id <CQChatTranscriptViewDelegate> transcriptDelegate;
	UIView *_blockerView;
	NSMutableArray *_pendingPreviousSessionComponents;
	NSMutableArray *_pendingComponents;
	NSString *_styleIdentifier;
	NSString *_fontFamily;
	NSUInteger _fontSize;
	BOOL _scrolling;
	BOOL _loading;
	BOOL _resetPending;
	CGPoint _lastTouchLocation;
	BOOL _allowsStyleChanges;
}
@property (nonatomic, assign) id <CQChatTranscriptViewDelegate> transcriptDelegate;

@property (nonatomic, assign) BOOL allowsStyleChanges;
@property (nonatomic, copy) NSString *styleIdentifier;
@property (nonatomic, copy) NSString *fontFamily;
@property (nonatomic, assign) NSUInteger fontSize;

- (void) addPreviousSessionComponents:(NSArray *) components;
- (void) addComponents:(NSArray *) components animated:(BOOL) animated;
- (void) addComponent:(NSDictionary *) component animated:(BOOL) animated;

- (void) noteNicknameChangedFrom:(NSString *) oldNickname to:(NSString *) newNickname;

- (void) scrollToBottomAnimated:(BOOL) animated;
- (void) flashScrollIndicators;

- (void) markScrollback;

- (void) reset;
- (void) resetSoon;
@end

@protocol CQChatTranscriptViewDelegate <NSObject>
@optional
- (void) transcriptView:(CQChatTranscriptView *) transcriptView receivedSwipeWithTouchCount:(NSUInteger) touchCount leftward:(BOOL) leftward;
- (BOOL) transcriptView:(CQChatTranscriptView *) transcriptView handleOpenURL:(NSURL *) url;
- (void) transcriptView:(CQChatTranscriptView *) transcriptView handleNicknameTap:(NSString *) nickname atLocation:(CGPoint) location;
- (void) transcriptViewWasReset:(CQChatTranscriptView *) transcriptView;
@end
