#import <Foundation/NSString.h>
#import <Foundation/NSObject.h>
#import <AppKit/NSNibDeclarations.h>
#import "JVChatWindowController.h"

@class WebView;
@class MVMenuButton;
@class NSMutableSet;
@class NSString;
@class NSBundle;
@class NSDictionary;
@class NSMutableDictionary;
@class JVChatMessage;
@class NSLock;

extern NSMutableSet *JVChatStyleBundles;
extern NSMutableSet *JVChatEmoticonBundles;

extern NSString *JVChatStylesScannedNotification;
extern NSString *JVChatEmoticonsScannedNotification;

extern NSString *JVNewStyleVariantAddedNotification;

@interface JVChatTranscript : NSObject <JVChatViewController> {
	@protected
	IBOutlet NSView *contents;
	IBOutlet WebView *display;

	void *_chatXSLStyle; /* xsltStylesheetPtr */
	void *_xmlLog; /* xmlDocPtr */

	NSLock *_logLock;
	JVChatWindowController *_windowController;
	NSString *_filePath;
	NSMenu *_styleMenu;
	NSBundle *_chatStyle;
	NSString *_chatStyleVariant;
	NSMenu *_emoticonMenu;
	NSBundle *_chatEmoticons;
	NSDictionary *_emoticonMappings;
	NSMutableDictionary *_styleParams;
	NSMutableArray *_messages;

	const char **_params;
	BOOL _isArchive;
	BOOL _nibLoaded;
	BOOL _previousStyleSwitch;
}
- (id) initWithTranscript:(NSString *) filename;

- (void) saveTranscriptTo:(NSString *) path;

- (IBAction) changeChatStyle:(id) sender;
- (void) setChatStyle:(NSBundle *) style withVariant:(NSString *) variant;
- (NSBundle *) chatStyle;

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

- (IBAction) leaveChat:(id) sender;
@end

#pragma mark -

@interface JVChatTranscript (JVChatTranscriptScripting) <JVChatListItemScripting>
- (NSNumber *) uniqueIdentifier;
@end

#pragma mark -

@interface NSObject (MVChatPluginLinkClickSupport)
- (BOOL) handleClickedLink:(NSURL *) url inView:(id <JVChatViewController>) view;
@end