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

@protocol CQChatTranscriptViewDelegate <NSObject>
@optional
- (void) transcriptView:(id) transcriptView receivedSwipeWithTouchCount:(NSUInteger) touchCount leftward:(BOOL) leftward;
- (BOOL) transcriptView:(id) transcriptView handleOpenURL:(NSURL *) url;
- (void) transcriptView:(id) transcriptView handleNicknameTap:(NSString *) nickname atLocation:(CGPoint) location;
- (void) transcriptView:(id) transcriptView handleLongPressURL:(NSURL *) url atLocation:(CGPoint) location;
- (BOOL) transcriptViewShouldBecomeFirstResponder:(id) transcriptView;
- (void) transcriptViewWasReset:(id) transcriptView;
@end

@protocol CQChatTranscriptView <NSObject>
@property (nonatomic, weak) IBOutlet id <CQChatTranscriptViewDelegate> transcriptDelegate;

@property (nonatomic, assign) BOOL allowsStyleChanges;
@property (nonatomic, copy) NSString *styleIdentifier;
@property (nonatomic, copy) NSString *fontFamily;
@property (nonatomic, assign) NSUInteger fontSize;
@property (nonatomic, assign) CQTimestampPosition timestampPosition;
@property (nonatomic, assign) BOOL allowSingleSwipeGesture;

@property (nonatomic, readonly) UIScrollView *scrollView;

- (void) stringByEvaluatingJavaScriptFromString:(NSString *) script completionHandler:(void (^)(NSString *))completionHandler;

- (void) addPreviousSessionComponents:(NSArray *) components;
- (void) addComponents:(NSArray *) components animated:(BOOL) animated;
- (void) addComponent:(NSDictionary *) component animated:(BOOL) animated;

- (void) noteNicknameChangedFrom:(NSString *) oldNickname to:(NSString *) newNickname;
- (void) noteTopicChangeTo:(NSString *) newTopic by:(NSString *) username;

// image must be either a URL or a base64-encoded image
- (void) insertImage:(NSString *) image forElementWithIdentifier:(NSString *) elementIdentifier;

- (void) scrollToBottomAnimated:(BOOL) animated;
- (void) flashScrollIndicators;

- (void) markScrollback;

- (void) reset;
- (void) resetSoon;
@end
