@protocol CQChatTranscriptViewDelegate;

typedef enum {
	CQShowRoomTopicNever,
	CQShowRoomTopicOnChange,
	CQShowRoomTopicAlways
} CQShowRoomTopic;

typedef enum {
	CQTimestampPositionLeft,
	CQTimestampPositionRight,
	CQTimestampPositionCenter
} CQTimestampPosition;

@interface CQChatTranscriptView : UIWebView <UIGestureRecognizerDelegate, UIWebViewDelegate> {
	@protected
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
	CQTimestampPosition _timestampPosition;
	BOOL _allowSingleSwipeGesture;
	NSMutableArray *_singleSwipeGestureRecognizers;
	CQShowRoomTopic _showRoomTopic;
	NSString *_roomTopic;
	NSString *_roomTopicSetter;
	BOOL _topicIsHidden;
}
@property (nonatomic, weak) IBOutlet id <CQChatTranscriptViewDelegate> transcriptDelegate;

@property (nonatomic, assign) BOOL allowsStyleChanges;
@property (nonatomic, copy) NSString *styleIdentifier;
@property (nonatomic, copy) NSString *fontFamily;
@property (nonatomic, assign) NSUInteger fontSize;
@property (nonatomic, assign) CQTimestampPosition timestampPosition;
@property (nonatomic, assign) BOOL allowSingleSwipeGesture;

- (void) addPreviousSessionComponents:(NSArray *) components;
- (void) addComponents:(NSArray *) components animated:(BOOL) animated;
- (void) addComponent:(NSDictionary *) component animated:(BOOL) animated;

- (void) noteNicknameChangedFrom:(NSString *) oldNickname to:(NSString *) newNickname;
- (void) noteTopicChangeTo:(NSString *) newTopic by:(NSString *) username;

// image must be either a URL, or, a base64-encoded image
- (void) insertImage:(NSString *) image forElementWithIdentifier:(NSString *) elementIdentifier;

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
- (void) transcriptView:(CQChatTranscriptView *) transcriptView handleLongPressURL:(NSURL *) url atLocation:(CGPoint) location;
- (BOOL) transcriptViewShouldBecomeFirstResponder:(CQChatTranscriptView *) transcriptView;
- (void) transcriptViewWasReset:(CQChatTranscriptView *) transcriptView;
@end
