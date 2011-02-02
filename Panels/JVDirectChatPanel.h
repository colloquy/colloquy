#import "JVChatTranscriptPanel.h"
#import "KAIgnoreRule.h"
#import "JVChatMessage.h"

@class MVTextView;
@class MVChatConnection;
@class MVChatUserWatchRule;
@class JVMutableChatMessage;
@class JVBuddy;

extern NSString *JVToolbarTextEncodingItemIdentifier;
extern NSString *JVToolbarClearScrollbackItemIdentifier;
extern NSString *JVToolbarSendFileItemIdentifier;
extern NSString *JVToolbarMarkItemIdentifier;

extern NSString *JVChatMessageWasProcessedNotification;
extern NSString *JVChatEventMessageWasProcessedNotification;

@interface JVDirectChatPanel : JVChatTranscriptPanel {
	@protected
	IBOutlet MVTextView *send;

	id _target;
	NSStringEncoding _encoding;
	NSMenu *_encodingMenu;
	NSMutableArray *_sendHistory;
	NSMutableArray *_waitingAlerts;
	NSMutableDictionary *_waitingAlertNames;
	NSMutableDictionary *_settings;
	NSMenu *_spillEncodingMenu;
	JVMutableChatMessage *_currentMessage;

	MVChatUserWatchRule *_watchRule;

	BOOL _firstMessage;
	BOOL _isActive;
	NSUInteger _newMessageCount;
	NSUInteger _newHighlightMessageCount;
	BOOL _cantSendMessages;

	NSInteger _historyIndex;
	CGFloat _sendHeight;
	BOOL _scrollerIsAtBottom;
	BOOL _forceSplitViewPosition;

	BOOL _loadingPersonImage;
	NSData *_personImageData;
}
- (id) initWithTarget:(id) target;
- (id) target;
- (MVChatUser *) user;
- (NSURL *) url;

- (void) showAlert:(NSPanel *) alert withName:(NSString *) name;

- (void) setPreference:(id) value forKey:(NSString *) key;
- (id) preferenceForKey:(NSString *) key;

- (NSStringEncoding) encoding;
- (IBAction) changeEncoding:(id) sender;

- (void) addEventMessageToDisplay:(NSString *) message withName:(NSString *) name andAttributes:(NSDictionary *) attributes;
- (void) addMessageToDisplay:(NSData *) message fromUser:(MVChatUser *) user asAction:(BOOL) action withIdentifier:(NSString *) identifier andType:(JVChatMessageType) type;
- (void) addMessageToDisplay:(NSData *) message fromUser:(MVChatUser *) user withAttributes:(NSDictionary *) msgAttributes withIdentifier:(NSString *) identifier andType:(JVChatMessageType) type;
- (void) processIncomingMessage:(JVMutableChatMessage *) message;
- (void) echoSentMessageToDisplay:(JVMutableChatMessage *) message;
- (JVMutableChatMessage *) currentMessage;

- (void) addMessageToHistory:(NSAttributedString *)message;

- (void) performNotification:(NSString *) identifier withContextInfo:(NSDictionary *) context;

- (NSUInteger) newMessagesWaiting;
- (NSUInteger) newHighlightMessagesWaiting;

- (IBAction) send:(id) sender;
- (void) sendMessage:(JVMutableChatMessage *) message;
- (BOOL) processUserCommand:(NSString *) command withArguments:(NSAttributedString *) arguments;

- (IBAction) clear:(id) sender;
- (IBAction) clearDisplay:(id) sender;
- (IBAction) markDisplay:(id) sender;
@end

@interface NSObject (MVChatPluginDirectChatSupport)
- (void) processIncomingMessage:(JVMutableChatMessage *) message inView:(id <JVChatViewController>) view;
- (void) processOutgoingMessage:(JVMutableChatMessage *) message inView:(id <JVChatViewController>) view;
@end
