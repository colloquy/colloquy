#import "JVChatTranscript.h"
#import <AppKit/NSNibDeclarations.h>

@class NSView;
@class MVTextView;
@class NSPopUpButton;
@class NSString;
@class NSPanel;
@class MVChatConnection;
@class NSDate;
@class NSMutableArray;
@class NSMutableDictionary;
@class NSMutableString;
@class NSBundle;
@class NSDictionary;
@class NSToolbar;
@class NSData;
@class NSAttributedString;
@class NSMutableAttributedString;

@interface JVDirectChat : JVChatTranscript {
	@protected
	IBOutlet MVTextView *send;
	IBOutlet NSPopUpButton *encodingView;
	NSString *_target;
	NSStringEncoding _encoding;
	MVChatConnection *_connection;
	NSMutableArray *_sendHistory;
	NSMutableArray *_waitingAlerts;
	NSMutableDictionary *_waitingAlertNames;
	NSMutableDictionary *_settings;
	NSMenu *_spillEncodingMenu;
	unsigned int _messageId;
	BOOL _firstMessage;
	BOOL _isActive;
	BOOL _newMessage;
	BOOL _newHighlightMessage;
	BOOL _cantSendMessages;
	int _historyIndex;
}
- (id) initWithTarget:(NSString *) target forConnection:(MVChatConnection *) connection;

- (void) setTarget:(NSString *) target;
- (NSString *) target;

- (void) showAlert:(NSPanel *) alert withName:(NSString *) name;

- (void) setPreference:(id) value forKey:(NSString *) key;
- (id) preferenceForKey:(NSString *) key;

- (NSStringEncoding) encoding;
- (IBAction) changeEncoding:(id) sender;	

- (void) addEventMessageToDisplay:(NSString *) message withName:(NSString *) name andAttributes:(NSDictionary *) attributes;
- (void) addMessageToDisplay:(NSData *) message fromUser:(NSString *) user asAction:(BOOL) action;
- (void) echoSentMessageToDisplay:(NSAttributedString *) message asAction:(BOOL) action;

- (IBAction) send:(id) sender;
- (BOOL) processUserCommand:(NSString *) command withArguments:(NSAttributedString *) arguments;
- (NSMutableAttributedString *) sendAttributedMessage:(NSMutableAttributedString *) message asAction:(BOOL) action;

- (IBAction) clear:(id) sender;
- (IBAction) clearDisplay:(id) sender;
@end
