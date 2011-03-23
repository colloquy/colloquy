#import "JVInspectorController.h"

@class MVMenuButton;
@class MVChatConnection;
@class JVChatWindowController;

@protocol JVChatViewController;
@protocol JVChatListItem;

extern NSString *JVToolbarToggleChatDrawerItemIdentifier;
extern NSString *JVChatViewPboardType;

@interface JVChatWindowController : NSWindowController <JVInspectionDelegator> {
	@protected
	IBOutlet NSDrawer *viewsDrawer;
	IBOutlet NSOutlineView *chatViewsOutlineView;
	IBOutlet MVMenuButton *viewActionButton;
	IBOutlet MVMenuButton *favoritesButton;
	NSString *_identifier;
	NSMutableDictionary *_settings;
	NSMutableArray *_views;
	id <JVChatViewController> _activeViewController;
	BOOL _usesSmallIcons;
	BOOL _showDelayed;
	BOOL _reloadingData;
	BOOL _closing;
}
- (NSString *) identifier;
- (void) setIdentifier:(NSString *) identifier;

- (NSString *) userDefaultsPreferencesKey;
- (void) setPreference:(id) value forKey:(NSString *) key;
- (id) preferenceForKey:(NSString *) key;

- (void) showChatViewController:(id <JVChatViewController>) controller;

- (void) addChatViewController:(id <JVChatViewController>) controller;
- (void) insertChatViewController:(id <JVChatViewController>) controller atIndex:(NSUInteger) index;

- (void) removeChatViewController:(id <JVChatViewController>) controller;
- (void) removeChatViewControllerAtIndex:(NSUInteger) index;
- (void) removeAllChatViewControllers;

- (void) replaceChatViewController:(id <JVChatViewController>) controller withController:(id <JVChatViewController>) newController;
- (void) replaceChatViewControllerAtIndex:(NSUInteger) index withController:(id <JVChatViewController>) controller;

- (NSArray *) chatViewControllersForConnection:(MVChatConnection *) connection;
- (NSArray *) chatViewControllersWithControllerClass:(Class) class;
- (NSArray *) allChatViewControllers;

- (id <JVChatViewController>) activeChatViewController;
- (id <JVChatListItem>) selectedListItem;

- (IBAction) getInfo:(id) sender;

- (IBAction) joinRoom:(id) sender;

- (IBAction) closeCurrentPanel:(id) sender;
- (IBAction) detachCurrentPanel:(id) sender;
- (IBAction) selectPreviousPanel:(id) sender;
- (IBAction) selectPreviousActivePanel:(id) sender;
- (IBAction) selectNextPanel:(id) sender;
- (IBAction) selectNextActivePanel:(id) sender;

- (NSToolbarItem *) toggleChatDrawerToolbarItem;
- (IBAction) toggleViewsDrawer:(id) sender;
- (IBAction) openViewsDrawer:(id) sender;
- (IBAction) closeViewsDrawer:(id) sender;

- (void) reloadListItem:(id <JVChatListItem>) controller andChildren:(BOOL) children;
- (BOOL) isListItemExpanded:(id <JVChatListItem>) item;
- (void) expandListItem:(id <JVChatListItem>) item;
- (void) collapseListItem:(id <JVChatListItem>) item;
@end

@interface JVChatWindowController (JVChatWindowControllerScripting)
- (NSNumber *) uniqueIdentifier;
@end

@protocol JVChatViewController <JVChatListItem>
- (MVChatConnection *) connection;

- (JVChatWindowController *) windowController;
- (void) setWindowController:(JVChatWindowController *) controller;

- (NSView *) view;
- (NSResponder *) firstResponder;
- (NSString *) toolbarIdentifier;
- (NSString *) windowTitle;
- (NSString *) identifier;
@end

@interface NSObject (JVChatViewControllerOptional)
- (void) willSelect;
- (void) didSelect;

- (void) willUnselect;
- (void) didUnselect;

- (void) willDispose;
@end

@protocol JVChatListItemScripting
- (NSNumber *) uniqueIdentifier;
- (NSArray *) children;
- (NSString *) information;
- (NSString *) toolTip;
- (BOOL) isEnabled;
@end

@protocol JVChatViewControllerScripting <JVChatListItemScripting>
- (NSWindow *) window;
- (IBAction) close:(id) sender;
@end

@protocol JVChatListItem <NSObject>
- (id <JVChatListItem>) parent;
- (NSImage *) icon;
- (NSString *) title;
@end

@interface NSObject (JVChatListItemOptional)
- (BOOL) acceptsDraggedFileOfType:(NSString *) type;
- (void) handleDraggedFile:(NSString *) path;
- (IBAction) doubleClicked:(id) sender;
- (BOOL) isEnabled;

- (NSMenu *) menu;
- (NSString *) information;
- (NSString *) toolTip;
- (NSImage *) statusImage;

- (NSUInteger) numberOfChildren;
- (id) childAtIndex:(NSUInteger) index;
@end

@interface NSObject (MVChatPluginToolbarSupport)
- (NSArray *) toolbarItemIdentifiersForView:(id <JVChatViewController>) view;
- (NSToolbarItem *) toolbarItemForIdentifier:(NSString *) identifier inView:(id <JVChatViewController>) view willBeInsertedIntoToolbar:(BOOL) willBeInserted;
@end
