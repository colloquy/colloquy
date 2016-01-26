#import "JVChatTranscriptPanel.h"
#import "KAIgnoreRule.h"
#import "JVChatMessage.h"

#import <WebKit/WebKit.h>

@class MVTextView;
@class MVChatConnection;
@class MVChatUserWatchRule;
@class JVMutableChatMessage;
@class JVBuddy;

NS_ASSUME_NONNULL_BEGIN

extern NSString *JVToolbarTextEncodingItemIdentifier;
extern NSString *JVToolbarClearScrollbackItemIdentifier;
extern NSString *JVToolbarSendFileItemIdentifier;
extern NSString *JVToolbarMarkItemIdentifier;

extern NSString *JVChatMessageWasProcessedNotification;
extern NSString *JVChatEventMessageWasProcessedNotification;

@interface JVDirectChatPanel : JVChatTranscriptPanel <WebUIDelegate, WebPolicyDelegate> {
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
- (instancetype) init NS_DESIGNATED_INITIALIZER;
- (instancetype) initWithTarget:(id) target;
@property (readonly, assign, nullable) id target;
@property (readonly, strong, nullable) MVChatUser *user;
@property (readonly, copy) NSURL *url;

- (void) showAlert:(NSPanel *) alert withName:(nullable NSString *) name;

- (void) setPreference:(nullable id) value forKey:(NSString *) key;
- (nullable id) preferenceForKey:(NSString *) key;

@property (readonly) NSStringEncoding encoding;
- (IBAction) changeEncoding:(nullable id) sender;

- (void) addEventMessageToDisplay:(NSString *) message withName:(NSString *) name andAttributes:(nullable NSDictionary *) attributes;
- (void) addMessageToDisplay:(NSData *) message fromUser:(MVChatUser *) user asAction:(BOOL) action withIdentifier:(NSString *) identifier andType:(JVChatMessageType) type;
- (void) addMessageToDisplay:(NSData *) message fromUser:(MVChatUser *) user withAttributes:(NSDictionary *) msgAttributes withIdentifier:(NSString *) identifier andType:(JVChatMessageType) type;
- (void) processIncomingMessage:(JVMutableChatMessage *) message;
- (void) echoSentMessageToDisplay:(JVMutableChatMessage *) message;
@property (readonly, strong) JVMutableChatMessage *currentMessage;

- (void) addMessageToHistory:(NSAttributedString *)message;

- (void) performNotification:(NSString *) identifier withContextInfo:(NSDictionary *) context;
- (IBAction) toggleNotifications:(nullable id) sender;

@property (readonly) NSUInteger newMessagesWaiting;
@property (readonly) NSUInteger newHighlightMessagesWaiting;

- (IBAction) send:(nullable id) sender;
- (void) sendMessage:(JVMutableChatMessage *) message;
- (BOOL) processUserCommand:(NSString *) command withArguments:(NSAttributedString *) arguments;

- (IBAction) clear:(nullable id) sender;
- (IBAction) clearDisplay:(nullable id) sender;
- (IBAction) markDisplay:(nullable id) sender;

- (void) textDidChange:(nullable NSNotification *) notification;
@end

@interface NSObject (MVChatPluginDirectChatSupport)
- (void) processIncomingMessage:(JVMutableChatMessage *) message inView:(id <JVChatViewController>) view;
- (void) processOutgoingMessage:(JVMutableChatMessage *) message inView:(id <JVChatViewController>) view;
@end

@interface JVDirectChatPanel (Private)
- (NSString *) _selfCompositeName;
- (NSString *) _selfStoredNickname;
- (NSMenu *) _encodingMenu;
- (void) _hyperlinkRoomNames:(NSMutableAttributedString *) message;
- (nullable NSMutableAttributedString *) _convertRawMessage:(NSData *) message;
- (nullable NSMutableAttributedString *) _convertRawMessage:(NSData *) message withBaseFont:(nullable NSFont *) baseFont;
- (void) _alertSheetDidEnd:(NSWindow *) sheet returnCode:(int) returnCode contextInfo:(void *) contextInfo;
- (void) _didConnect:(NSNotification *) notification;
- (void) _didDisconnect:(NSNotification *) notification;
- (void) _errorOccurred:(NSNotification *) notification;
- (void) _awayStatusChanged:(NSNotification *) notification;
// TODO: This method is overwriting a method of superclass category JVChatTranscriptPanel+Private, undefined behavior.
- (void) _updateEmoticonsMenu; // overwrite
- (void) _insertEmoticon:(id) sender;
// TODO: This method is overwriting a method of superclass category JVChatTranscriptPanel+Private, undefined behavior.
- (BOOL) _usingSpecificStyle; // overwrite
// TODO: This method is overwriting a method of superclass category JVChatTranscriptPanel+Private, undefined behavior.
- (BOOL) _usingSpecificEmoticons; // overwrite
// TODO: This method is overwriting a method of superclass category JVChatTranscriptPanel+Private, undefined behavior.
- (void) _didSwitchStyles:(NSNotification *) notification; // overwrite
- (void) _saveSelfIcon;
- (void) _saveBuddyIcon:(JVBuddy *) buddy;
- (void) _refreshIcon:(NSNotification *) notification;
- (void) _setCurrentMessage:(nullable JVMutableChatMessage *) message;
- (void) _userNicknameDidChange:(NSNotification *) notification;
- (void) _userStatusChanged:(NSNotification *) notification;
@end

NS_ASSUME_NONNULL_END
