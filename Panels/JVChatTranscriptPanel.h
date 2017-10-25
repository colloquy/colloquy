#import <Cocoa/Cocoa.h>
#import "JVChatWindowController.h"

#import <WebKit/WebKit.h>

@class JVStyleView;
@class MVMenuButton;
@class JVStyle;
@class JVEmoticonSet;
@class JVChatMessage;
@class JVChatTranscript;

NS_ASSUME_NONNULL_BEGIN

extern NSString *JVToolbarChooseStyleItemIdentifier;
extern NSString *JVToolbarEmoticonsItemIdentifier;
extern NSString *JVToolbarFindItemIdentifier;
extern NSString *JVToolbarQuickSearchItemIdentifier;

@interface JVChatTranscriptPanel : NSObject <JVChatViewController, JVChatViewControllerScripting, NSToolbarDelegate, WebUIDelegate> {
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
- (instancetype) init NS_DESIGNATED_INITIALIZER;
- (nullable instancetype) initWithTranscript:(NSString *) filename;

- (IBAction) changeStyle:(nullable id) sender;
- (void) setStyle:(JVStyle *) style withVariant:(NSString *) variant;
@property (readonly, strong) JVStyle *style;

- (IBAction) changeStyleVariant:(nullable id) sender;
@property (copy) NSString *styleVariant;

- (IBAction) changeEmoticons:(nullable id) sender;
@property (strong) JVEmoticonSet *emoticons;

@property (readonly, strong) JVChatTranscript *transcript;
- (void) jumpToMessage:(JVChatMessage *) message;

- (IBAction) close:(nullable id) sender;
- (IBAction) activate:(nullable id) sender;

- (IBAction) performQuickSearch:(nullable id) sender;
- (void) quickSearchMatchMessage:(nullable JVChatMessage *) message;

@property (copy, nullable) NSString *searchQuery;

@property (readonly, strong) JVStyleView *display;
@end

#pragma mark -

@protocol MVChatPluginLinkClickSupport <MVChatPlugin>
- (BOOL) handleClickedLink:(NSURL *) url inView:(id <JVChatViewController>) view;
@end

#pragma mark -

@interface JVChatTranscriptPanel (Private)
// Style Support.
- (void) _refreshWindowFileProxy;
- (void) _refreshSearch;
- (void) _didSwitchStyles:(NSNotification *) notification;

- (void) _reloadCurrentStyle:(nullable id) sender;
- (NSMenu *) _stylesMenu;
- (void) _changeStyleMenuSelection;
- (void) _updateStylesMenu;
- (BOOL) _usingSpecificStyle;

// Emoticons Support.
- (NSMenu *) _emoticonsMenu;
- (void) _changeEmoticonsMenuSelection;
- (void) _updateEmoticonsMenu;
- (BOOL) _usingSpecificEmoticons;

- (void) _openAppearancePreferences:(nullable id) sender;

@end

NS_ASSUME_NONNULL_END
