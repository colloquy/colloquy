#import "JVChatWindowController.h"

@class WebView;
@class MVMenuButton;
@class JVStyle;
@class JVChatMessage;

extern NSMutableSet *JVChatStyleBundles;
extern NSMutableSet *JVChatEmoticonBundles;

extern NSString *JVChatStylesScannedNotification;
extern NSString *JVChatEmoticonsScannedNotification;

@interface JVChatTranscript : NSObject <JVChatViewController> {
	@protected
	IBOutlet NSView *contents;
	IBOutlet WebView *display;
	BOOL _nibLoaded;

	JVChatWindowController *_windowController;

	NSString *_filePath;
	BOOL _isArchive;

	NSLock *_logLock;
	void *_xmlLog; /* xmlDocPtr */
	NSMutableArray *_messages;

	NSMenu *_styleMenu;
	JVStyle *_chatStyle;
	NSString *_chatStyleVariant;
	NSMutableDictionary *_styleParams;

	NSMenu *_emoticonMenu;
	NSBundle *_chatEmoticons;
	NSDictionary *_emoticonMappings;

	BOOL _previousStyleSwitch;

	// Select sheet NIB outlets, JVChatTranscript only.
	IBOutlet NSPanel *selectSheet;
	IBOutlet NSTextField *transcriptDescription;
	IBOutlet NSMatrix *selectOptions;
	IBOutlet NSPopUpButton *transcriptMembers;
	IBOutlet NSPopUpButton *transcriptSessions;
	IBOutlet NSTextField *transcriptFilter;
}
- (id) initWithTranscript:(NSString *) filename;

- (void) saveTranscriptTo:(NSString *) path;

- (IBAction) specifyTranscriptSectionSheet:(id) sender;
- (IBAction) cancelTranscriptSectionSheet:(id) sender;
- (IBAction) confirmTranscriptSectionSheet:(id) sender;

- (IBAction) changeChatStyle:(id) sender;
- (void) setChatStyle:(JVStyle *) style withVariant:(NSString *) variant;
- (JVStyle *) chatStyle;

- (IBAction) changeChatStyleVariant:(id) sender;
- (void) setChatStyleVariant:(NSString *) variant;
- (NSString *) chatStyleVariant;

- (IBAction) changeChatEmoticons:(id) sender;
- (void) setChatEmoticons:(NSBundle *) emoticons;
- (void) setChatEmoticons:(NSBundle *) emoticons performRefresh:(BOOL) refresh;
- (NSBundle *) chatEmoticons;

- (unsigned long) numberOfMessages;
- (JVChatMessage *) messageAtIndex:(unsigned long) index;
- (NSArray *) messagesInRange:(NSRange) range;

- (IBAction) close:(id) sender;
- (IBAction) activate:(id) sender;
@end

#pragma mark -

@interface JVChatTranscript (JVChatTranscriptScripting) <JVChatListItemScripting>
- (NSNumber *) uniqueIdentifier;
@end

#pragma mark -

@interface NSObject (MVChatPluginLinkClickSupport)
- (BOOL) handleClickedLink:(NSURL *) url inView:(id <JVChatViewController>) view;
@end