#import <Foundation/NSObject.h>
#import <AppKit/NSNibDeclarations.h>

extern NSString *MVPreferencesWindowNotification;

@class MVPreferencesIconView;
@class MVPreferencesGroupedIconView;
@class NSWindow;
@class NSView;
@class NSImageView;
@class NSTextField;
@class NSMutableArray;
@class NSMutableDictionary;
@class NSString;

@interface MVPreferencesController : NSObject {
	IBOutlet NSWindow *window;
	IBOutlet NSView *loadingView;
	IBOutlet MVPreferencesIconView *multiView;
	IBOutlet MVPreferencesGroupedIconView *groupView;
	IBOutlet NSImageView *loadingImageView;
	IBOutlet NSTextField *loadingTextFeld;
	NSView *mainView;
	NSMutableArray *panes;
	NSMutableDictionary *loadedPanes, *paneInfo;
	NSString *currentPaneIdentifier, *pendingPane;
	BOOL closeWhenDoneWithSheet, closeWhenPaneIsReady;
}
+ (MVPreferencesController *) sharedInstance;
- (NSWindow *) window;
- (void) showAll:(id) sender;
- (void) showPreferences:(id) sender;
- (void) selectPreferencePaneByIdentifier:(NSString *) identifier;
@end
