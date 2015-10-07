#import "JVChatWindowController.h"

@class JVStyleView;
@class MVMenuButton;
@class JVStyle;
@class JVEmoticonSet;
@class JVChatMessage;
@class JVChatTranscript;

extern NSString *JVToolbarChooseStyleItemIdentifier;
extern NSString *JVToolbarEmoticonsItemIdentifier;
extern NSString *JVToolbarFindItemIdentifier;
extern NSString *JVToolbarQuickSearchItemIdentifier;

@interface JVChatTranscriptPanel : NSObject <JVChatViewController, JVChatViewControllerScripting, NSToolbarDelegate> {
	@protected
	IBOutlet NSView *contents;
	IBOutlet JVStyleView *display;
	BOOL _nibLoaded;
	BOOL _disposed;

	JVChatWindowController *_windowController;

	JVChatTranscript *_transcript;

	NSMenu *_styleMenu;
	NSMenu *_emoticonMenu;

	NSString *_searchQuery;
	NSRegularExpression *_searchQueryRegex;
}
- (instancetype) initWithTranscript:(NSString *) filename;

- (IBAction) changeStyle:(id) sender;
- (void) setStyle:(JVStyle *) style withVariant:(NSString *) variant;
@property (readonly, strong) JVStyle *style;

- (IBAction) changeStyleVariant:(id) sender;
@property (copy) NSString *styleVariant;

- (IBAction) changeEmoticons:(id) sender;
@property (strong) JVEmoticonSet *emoticons;

@property (readonly, strong) JVChatTranscript *transcript;
- (void) jumpToMessage:(JVChatMessage *) message;

- (IBAction) close:(id) sender;
- (IBAction) activate:(id) sender;

- (IBAction) performQuickSearch:(id) sender;
- (void) quickSearchMatchMessage:(JVChatMessage *) message;

@property (copy) NSString *searchQuery;

@property (readonly, strong) JVStyleView *display;
@end

#pragma mark -

@interface NSObject (MVChatPluginLinkClickSupport)
- (BOOL) handleClickedLink:(NSURL *) url inView:(id <JVChatViewController>) view;
@end
