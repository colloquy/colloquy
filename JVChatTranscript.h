#import <Foundation/NSString.h>
#import <Foundation/NSObject.h>
#import <AppKit/NSNibDeclarations.h>
#import "JVChatWindowController.h"

@class WebView;
@class MVMenuButton;
@class NSString;
@class NSBundle;
@class NSDictionary;

@interface JVChatTranscript : NSObject <JVChatViewController> {
	@protected
	IBOutlet NSView *contents;
	IBOutlet WebView *display;
	IBOutlet MVMenuButton *chooseStyle;
	/* xmlDocPtr */ void *_xmlLog;
	/* xsltStylesheetPtr */ void *_chatXSLStyle;
	JVChatWindowController *_windowController;
	NSString *_filePath;
	NSBundle *_chatStyle;
	NSString *_chatStyleVariant;
	NSBundle *_chatEmoticons;
	NSDictionary *_emoticonMappings;
	NSDictionary *_styleParams;
	const char **_params;
	BOOL _isArchive;
	BOOL _nibLoaded;
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
- (NSBundle *) chatEmoticons;

- (IBAction) leaveChat:(id) sender;
@end
