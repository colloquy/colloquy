#import "JVChatTranscript.h"
#import "KAIgnoreRule.h"

@class MVTextView;
@class MVChatConnection;
@class JVMutableChatMessage;
@class JVBuddy;

@interface JVDirectChat : JVChatTranscript {
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
	NSFileHandle *_logFile;
	NSMutableArray *_messageQueue;
	JVMutableChatMessage *_currentMessage;

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
- (id) initWithTarget:(id) target;
- (id) target;

- (IBAction) addToFavorites:(id) sender;

- (void) showAlert:(NSPanel *) alert withName:(NSString *) name;

- (void) setPreference:(id) value forKey:(NSString *) key;
- (id) preferenceForKey:(NSString *) key;

- (NSStringEncoding) encoding;
- (IBAction) changeEncoding:(id) sender;	

- (void) addEventMessageToDisplay:(NSString *) message withName:(NSString *) name andAttributes:(NSDictionary *) attributes;
- (void) addEventMessageToDisplay:(NSString *) message withName:(NSString *) name andAttributes:(NSDictionary *) attributes entityEncodeAttributes:(BOOL) encode;
- (void) addMessageToDisplay:(NSData *) message fromUser:(MVChatUser *) user asAction:(BOOL) action withIdentifier:(NSString *) identifier;
- (void) processIncomingMessage:(JVMutableChatMessage *) message;
- (void) echoSentMessageToDisplay:(JVMutableChatMessage *) message;
- (JVMutableChatMessage *) currentMessage;

- (unsigned int) newMessagesWaiting;
- (unsigned int) newHighlightMessagesWaiting;

- (IBAction) send:(id) sender;
- (void) sendMessage:(JVMutableChatMessage *) message;
- (BOOL) processUserCommand:(NSString *) command withArguments:(NSAttributedString *) arguments;

- (IBAction) clear:(id) sender;
- (IBAction) clearDisplay:(id) sender;
@end

@interface NSObject (MVChatPluginDirectChatSupport)
- (void) processIncomingMessage:(JVMutableChatMessage *) message;
- (void) processOutgoingMessage:(JVMutableChatMessage *) message;
@end
