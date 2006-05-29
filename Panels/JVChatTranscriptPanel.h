#import "JVChatWindowController.h"

@class JVStyleView;
@class MVMenuButton;
@class JVStyle;
@class JVEmoticonSet;
@class JVChatMessage;
@class JVChatTranscript;
@class JVSQLChatTranscript;

extern NSString *JVToolbarChooseStyleItemIdentifier;
extern NSString *JVToolbarEmoticonsItemIdentifier;
extern NSString *JVToolbarFindItemIdentifier;
extern NSString *JVToolbarQuickSearchItemIdentifier;

@interface JVChatTranscriptPanel : NSObject <JVChatViewController, JVChatViewControllerScripting> {
	@protected
	IBOutlet NSView *contents;
	IBOutlet JVStyleView *display;
	BOOL _nibLoaded;
	BOOL _disposed;

	JVChatWindowController *_windowController;

	JVChatTranscript *_transcript;
	JVSQLChatTranscript *_sqlTestTranscript;

	NSMenu *_styleMenu;
	NSMenu *_emoticonMenu;

	NSString *_searchQuery;
	AGRegex *_searchQueryRegex;
}
- (id) initWithTranscript:(NSString *) filename;

- (IBAction) changeStyle:(id) sender;
- (void) setStyle:(JVStyle *) style withVariant:(NSString *) variant;
- (JVStyle *) style;

- (IBAction) changeStyleVariant:(id) sender;
- (void) setStyleVariant:(NSString *) variant;
- (NSString *) styleVariant;

- (IBAction) changeEmoticons:(id) sender;
- (void) setEmoticons:(JVEmoticonSet *) emoticons;
- (JVEmoticonSet *) emoticons;

- (JVChatTranscript *) transcript;
- (void) jumpToMessage:(JVChatMessage *) message;

- (IBAction) close:(id) sender;
- (IBAction) activate:(id) sender;

- (IBAction) performQuickSearch:(id) sender;
- (void) quickSearchMatchMessage:(JVChatMessage *) message;

- (void) setSearchQuery:(NSString *) query;
- (NSString *) searchQuery;

- (JVStyleView *) display;
@end

#pragma mark -

@interface NSObject (MVChatPluginLinkClickSupport)
- (BOOL) handleClickedLink:(NSURL *) url inView:(id <JVChatViewController>) view;
@end