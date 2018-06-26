#import "JVChatTranscriptPanel.h"
#import "KAIgnoreRule.h"
#import "JVChatMessage.h"

#import <WebKit/WebKit.h>

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

COLLOQUY_EXPORT
@interface JVDirectChatPanel : JVChatTranscriptPanel <WebUIDelegate, WebPolicyDelegate> {
	@protected
	IBOutlet MVTextView *send;

	id _target;
	NSStringEncoding _encoding;
	NSMenu *_encodingMenu;
	NSMutableArray *_sendHistory;
	NSMutableArray<NSDictionary <NSString *, id>*> *_waitingAlerts;
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
	CGFloat _minimumSendHeight;
	BOOL _scrollerIsAtBottom;
	BOOL _forceSplitViewPosition;

	BOOL _loadingPersonImage;
	NSData *_personImageData;
}
- (id) initWithTarget:(id) target;
- (id) target;
- (MVChatUser *) user;
- (NSURL *) url;

- (void) showAlert:(NSAlert *) alert withCompletionHandler:(void (^)(NSModalResponse returnCode))handler;

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
- (IBAction) toggleNotifications:(id) sender;

- (NSUInteger) newMessagesWaiting;
- (NSUInteger) newHighlightMessagesWaiting;

- (IBAction) send:(id) sender;
- (void) sendMessage:(JVMutableChatMessage *) message;
- (BOOL) processUserCommand:(NSString *) command withArguments:(NSAttributedString *) arguments;

- (IBAction) clear:(id) sender;
- (IBAction) clearDisplay:(id) sender;
- (IBAction) markDisplay:(id) sender;

- (void) textDidChange:(NSNotification *) notification;
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
- (NSMutableAttributedString *) _convertRawMessage:(NSData *) message;
- (NSMutableAttributedString *) _convertRawMessage:(NSData *) message withBaseFont:(NSFont *) baseFont;
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
- (void) _setCurrentMessage:(JVMutableChatMessage *) message;
- (void) _userNicknameDidChange:(NSNotification *) notification;
- (void) _userStatusChanged:(NSNotification *) notification;
@end
