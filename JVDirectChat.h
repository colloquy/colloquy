#import <Foundation/NSObject.h>
#import <AppKit/NSNibDeclarations.h>
#import "JVChatWindowController.h"
//#import <libxml/tree.h>
//#import <libxslt/xsltInternals.h>

@class NSView;
@class WebView;
@class MVTextView;
@class MVMenuButton;
@class NSString;
@class MVChatConnection;
@class NSDate;
@class NSMutableArray;
@class NSMutableString;
@class NSBundle;
@class NSDictionary;
@class NSToolbar;
@class NSData;
@class NSAttributedString;
@class NSMutableAttributedString;

@interface JVDirectChat : NSObject <JVChatViewController> {
	@protected
	IBOutlet NSView *contents;
	IBOutlet WebView *display;
	IBOutlet MVTextView *send;
	IBOutlet MVMenuButton *chooseStyle;
	/* xmlDocPtr */ void *_xmlLog;
	/* xsltStylesheetPtr */ void *_chatXSLStyle;
	JVChatWindowController *_windowController;
	NSString *_target;
	MVChatConnection *_connection;
	NSMutableArray *_sendHistory;
	NSBundle *_chatStyle;
	NSString *_chatStyleVariant;
	NSBundle *_chatEmoticons;
	NSDictionary *_emoticonMappings;
	NSStringEncoding _encoding;
	unsigned int _messageId;
	BOOL _firstMessage;
	BOOL _nibLoaded;
	BOOL _isLog;
	int _historyIndex;
}
- (void) setTarget:(NSString *) target;

- (IBAction) changeChatStyle:(id) sender;
- (void) setChatStyle:(NSBundle *) style withVariant:(NSString *) variant;
- (NSBundle *) chatStyle;

- (IBAction) changeChatStyleVariant:(id) sender;
- (void) setChatStyleVariant:(NSString *) variant;
- (NSString *) chatStyleVariant;

- (IBAction) changeChatEmoticons:(id) sender;
- (void) setChatEmoticons:(NSBundle *) emoticons;
- (NSBundle *) chatEmoticons;

- (IBAction) leaveChat:(id) sender;

- (void) addStatusMessageToDisplay:(NSString *) message;
- (void) addMessageToDisplay:(NSData *) message fromUser:(NSString *) user asAction:(BOOL) action;

- (IBAction) send:(id) sender;
- (BOOL) processUserCommand:(NSString *) command withArguments:(NSAttributedString *) arguments;
- (NSMutableAttributedString *) sendAttributedMessage:(NSMutableAttributedString *) message asAction:(BOOL) action;

- (IBAction) clear:(id) sender;
- (IBAction) clearDisplay:(id) sender;
@end
