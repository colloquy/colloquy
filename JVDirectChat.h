#import "JVChatTranscript.h"
#import <AddressBook/ABImageLoading.h>
#import "KAIgnoreRule.h"

@class MVTextView;
@class MVChatConnection;
@class JVMutableChatMessage;
@class JVBuddy;

@interface JVDirectChat : JVChatTranscript {
	@protected
	IBOutlet MVTextView *send;

	NSString *_target;
	NSStringEncoding _encoding;
	NSMenu *_encodingMenu;
	MVChatConnection *_connection;
	NSMutableArray *_sendHistory;
	NSMutableArray *_waitingAlerts;
	NSMutableDictionary *_waitingAlertNames;
	NSMutableDictionary *_settings;
	NSMenu *_spillEncodingMenu;
	JVBuddy *_buddy;
	NSFileHandle *_logFile;
	NSMutableArray *_messageQueue;
	JVMutableChatMessage *_currentMessage;

	unsigned int _messageId;
	BOOL _firstMessage;
	BOOL _requiresFullMessage;
	BOOL _isActive;
	unsigned int _newMessageCount;
	unsigned int _newHighlightMessageCount;
	BOOL _cantSendMessages;

	int _historyIndex;	
	float _sendHeight;
	BOOL _scrollerIsAtBottom;
	long _previousLogOffset;
	BOOL _forceSplitViewPosition;

	BOOL _loadingPersonImage;
	NSData *_personImageData;
}
- (id) initWithTarget:(NSString *) target forConnection:(MVChatConnection *) connection;

- (void) setTarget:(NSString *) target;
- (NSString *) target;
- (NSURL *) url;
- (JVBuddy *) buddy;

- (void) unavailable;

- (IBAction) addToFavorites:(id) sender;

- (void) showAlert:(NSPanel *) alert withName:(NSString *) name;

- (void) setPreference:(id) value forKey:(NSString *) key;
- (id) preferenceForKey:(NSString *) key;

- (NSStringEncoding) encoding;
- (IBAction) changeEncoding:(id) sender;	

- (void) addEventMessageToDisplay:(NSString *) message withName:(NSString *) name andAttributes:(NSDictionary *) attributes;
- (void) addEventMessageToDisplay:(NSString *) message withName:(NSString *) name andAttributes:(NSDictionary *) attributes entityEncodeAttributes:(BOOL) encode;
- (void) addMessageToDisplay:(NSData *) message fromUser:(NSString *) user asAction:(BOOL) action;
- (void) processIncomingMessage:(JVMutableChatMessage *) message;
- (void) echoSentMessageToDisplay:(NSAttributedString *) message asAction:(BOOL) action;
- (JVMutableChatMessage *) currentMessage;

- (unsigned int) newMessagesWaiting;
- (unsigned int) newHighlightMessagesWaiting;

- (IBAction) send:(id) sender;
- (void) sendMessage:(JVMutableChatMessage *) message;
- (NSAttributedString *) sendActionMessage:(NSAttributedString *) message;
- (BOOL) processUserCommand:(NSString *) command withArguments:(NSAttributedString *) arguments;

- (IBAction) clear:(id) sender;
- (IBAction) clearDisplay:(id) sender;
@end

@interface NSObject (MVChatPluginDirectChatSupport)
- (void) processIncomingMessage:(JVMutableChatMessage *) message;
- (void) processOutgoingMessage:(JVMutableChatMessage *) message;

- (void) userNamed:(NSString *) nickname isNowKnownAs:(NSString *) newNickname inView:(id <JVChatViewController>) view;
@end