#import <Foundation/NSString.h>
#import <Foundation/NSObject.h>
#import <AppKit/NSNibDeclarations.h>
#import "JVChatWindowController.h"

@class WebView;
@class MVMenuButton;
@class NSString;
@class NSBundle;
@class NSDictionary;
@class NSMutableDictionary;
@class NSConnection;
@class NSLock;

@interface JVChatTranscript : NSObject <JVChatViewController> {
	@protected
	IBOutlet NSView *contents;
	IBOutlet NSView *toolbarItems;
	IBOutlet WebView *display;
	IBOutlet MVMenuButton *chooseStyle;
	IBOutlet MVMenuButton *chooseEmoticon;
	/* xsltStylesheetPtr */ void *_chatXSLStyle;
	/* xmlDocPtr */ void *_xmlLog;
	/* xmlDocPtr */ void *_xmlQueue;
	NSLock *_logLock;
	JVChatWindowController *_windowController;
	NSString *_filePath;
	NSBundle *_chatStyle;
	NSString *_chatStyleVariant;
	NSBundle *_chatEmoticons;
	NSDictionary *_emoticonMappings;
	NSDictionary *_styleParams;
	NSMutableDictionary *_toolbarItems;
	const char **_params;
	BOOL _isArchive;
	BOOL _nibLoaded;
	BOOL _previousStyleSwitch;
}
- (id) initWithTranscript:(NSString *) filename;

- (IBAction) changeChatStyle:(id) sender;
- (void) setChatStyle:(NSBundle *) style withVariant:(NSString *) variant;
- (NSBundle *) chatStyle;

- (IBAction) changeChatStyleVariant:(id) sender;
- (void) setChatStyleVariant:(NSString *) variant;
- (NSString *) chatStyleVariant;

- (IBAction) changeChatEmoticons:(id) sender;
- (void) setChatEmoticons:(NSBundle *) emoticons;
- (void) setChatEmoticons:(NSBundle *) emoticons preformRefresh:(BOOL) refresh;
- (NSBundle *) chatEmoticons;

- (IBAction) leaveChat:(id) sender;
@end

@interface JVChatTranscript (JVChatTranscriptScripting) <JVChatListItemScripting>
- (NSNumber *) uniqueIdentifier;
@end