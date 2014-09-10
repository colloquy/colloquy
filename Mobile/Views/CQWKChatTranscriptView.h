#import "CQChatTranscriptViewDelegate.h"

#import <WebKit/WebKit.h>

@interface CQWKChatTranscriptView : WKWebView <CQChatTranscriptView, UIGestureRecognizerDelegate, UIScrollViewDelegate, WKNavigationDelegate> {
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
@end
