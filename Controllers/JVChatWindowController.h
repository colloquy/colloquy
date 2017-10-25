#import <Cocoa/Cocoa.h>
#import "JVInspectorController.h"

@class MVMenuButton;
@class MVChatConnection;
@class JVChatWindowController;

@protocol JVChatViewController;
@protocol JVChatListItem;

NS_ASSUME_NONNULL_BEGIN

extern NSString *JVToolbarToggleChatDrawerItemIdentifier;
extern NSString *JVChatViewPboardType;

@interface JVChatWindowController : NSWindowController <JVInspectionDelegator, NSMenuDelegate, NSOutlineViewDataSource, NSOutlineViewDelegate, NSToolbarDelegate, NSWindowDelegate> {
	@protected
	IBOutlet NSDrawer *viewsDrawer;
	IBOutlet NSOutlineView *chatViewsOutlineView;
	IBOutlet NSPopUpButton *viewActionButton;
	IBOutlet NSPopUpButton *favoritesButton;
	NSString *_identifier;
	NSMutableDictionary *_settings;
	NSMutableArray/*<id <JVChatViewController>>*/ *_views;
	id <JVChatViewController> _activeViewController;
	BOOL _usesSmallIcons;
	BOOL _showDelayed;
	BOOL _reloadingData;
	BOOL _closing;
}
@property (copy) NSString *identifier;

@property (readonly, copy) NSString *userDefaultsPreferencesKey;
- (void) setPreference:(nullable id) value forKey:(NSString *) key;
- (nullable id) preferenceForKey:(NSString *) key;

- (void) showChatViewController:(id <JVChatViewController>) controller;

- (void) addChatViewController:(id <JVChatViewController>) controller;
- (void) insertChatViewController:(id <JVChatViewController>) controller atIndex:(NSUInteger) index;

- (void) removeChatViewController:(id <JVChatViewController>) controller;
- (void) removeChatViewControllerAtIndex:(NSUInteger) index;
- (void) removeAllChatViewControllers;

- (void) replaceChatViewController:(id <JVChatViewController>) controller withController:(id <JVChatViewController>) newController;
- (void) replaceChatViewControllerAtIndex:(NSUInteger) index withController:(id <JVChatViewController>) controller;

- (NSArray<id<JVChatViewController>> *) chatViewControllersForConnection:(MVChatConnection *) connection;
- (NSArray<id<JVChatViewController>> *) chatViewControllersWithControllerClass:(Class) class;
@property (readonly, copy) NSArray<id<JVChatViewController>> *allChatViewControllers;

@property (readonly, strong) id<JVChatViewController> activeChatViewController;
@property (readonly, strong, nullable) id<JVChatListItem> selectedListItem;

- (IBAction) getInfo:(nullable id) sender;

- (IBAction) joinRoom:(nullable id) sender;

- (IBAction) closeCurrentPanel:(nullable id) sender;
- (IBAction) detachCurrentPanel:(nullable id) sender;
- (IBAction) selectPreviousPanel:(nullable id) sender;
- (IBAction) selectPreviousActivePanel:(nullable id) sender;
- (IBAction) selectNextPanel:(nullable id) sender;
- (IBAction) selectNextActivePanel:(nullable id) sender;

- (NSToolbarItem *) toggleChatDrawerToolbarItem;
- (IBAction) toggleViewsDrawer:(nullable id) sender;
- (IBAction) openViewsDrawer:(nullable id) sender;
- (IBAction) closeViewsDrawer:(nullable id) sender;
- (IBAction) toggleSmallDrawerIcons:(nullable id) sender;

- (void) reloadListItem:(id <JVChatListItem>) controller andChildren:(BOOL) children;
- (BOOL) isListItemExpanded:(id <JVChatListItem>) item;
- (void) expandListItem:(id <JVChatListItem>) item;
- (void) collapseListItem:(id <JVChatListItem>) item;
@end

@interface JVChatWindowController (Private)
- (void) _claimMenuCommands;
- (void) _resignMenuCommands;
- (void) _doubleClickedListItem:(id) sender;
- (void) _deferRefreshSelectionMenu;
- (void) _refreshSelectionMenu;
- (void) _refreshMenuWithItem:(id) item;
- (void) _refreshWindow;
- (void) _refreshToolbar;
- (void) _refreshWindowTitle;
- (void) _refreshList;
- (void) _refreshPreferences;
- (void) _saveWindowFrame;
- (void) _switchViews:(id) sender;
- (void) _favoritesListDidUpdate:(NSNotification *) notification;
@end

@interface JVChatWindowController (JVChatWindowControllerScripting)
@property (readonly, copy) NSNumber *uniqueIdentifier;
@end

@protocol JVChatViewController <JVChatListItem>
@optional
- (id <JVChatViewController>) activeChatViewController;

@required
- (nullable MVChatConnection *) connection;
@property (readonly, strong, nullable) MVChatConnection *connection;

- (nullable JVChatWindowController *) windowController;
- (void) setWindowController:(nullable JVChatWindowController *) controller;
@property (nonatomic, readwrite, retain, nullable) JVChatWindowController *windowController;

- (NSView *) view;
- (nullable NSResponder *) firstResponder;
- (NSString *) toolbarIdentifier;
@property (readonly, copy) NSString *toolbarIdentifier;
- (NSString *) windowTitle;
@property (readonly, copy) NSString *windowTitle;
- (NSString *)identifier;
@property (readonly, copy) NSString *identifier;

@optional
- (void) willSelect;
- (void) didSelect;

- (void) willUnselect;
- (void) didUnselect;

- (void) willDispose;
@end

@protocol JVChatListItemScripting <NSObject>
- (NSNumber *) uniqueIdentifier;
@property (readonly, copy) NSNumber *uniqueIdentifier;
- (nullable NSArray *) children;
- (nullable NSString *) information;
@property (readonly, copy, nullable) NSString *information;
- (NSString *) toolTip;
@property (readonly, copy) NSString *toolTip;
- (BOOL) isEnabled;
@property (readonly, getter=isEnabled) BOOL enabled;
@end

@protocol JVChatViewControllerScripting <JVChatListItemScripting>
- (NSWindow *) window;
- (IBAction) close:(nullable id) sender;
@end

@protocol JVChatListItem <NSObject>
- (nullable id <JVChatListItem>) parent;
@property (readonly, nullable, weak) id<JVChatListItem> parent;
- (NSImage *) icon;
@property (readonly, retain) NSImage *icon;
- (NSString *) title;
@property (readonly, copy) NSString *title;

@optional
- (BOOL) acceptsDraggedFileOfType:(NSString *) type;
- (void) handleDraggedFile:(NSString *) path;
- (IBAction) doubleClicked:(nullable id) sender;
- (BOOL) isEnabled;
@property (readonly, getter=isEnabled) BOOL enabled;

- (NSMenu *) menu;
- (nullable NSString *) information;
@property (readonly, copy, nullable) NSString *information;
- (NSString *) toolTip;
@property (readonly, copy) NSString *toolTip;
- (nullable NSImage *) statusImage;
@property (readonly, retain, nullable) NSImage *statusImage;

- (NSUInteger) numberOfChildren;
@property (readonly) NSUInteger numberOfChildren;
- (id<JVChatListItem>) childAtIndex:(NSUInteger) index;
@end

@protocol MVChatPluginToolbarSupport <MVChatPlugin>
- (nullable NSArray<NSString*> *) toolbarItemIdentifiersForView:(id <JVChatViewController>) view;
- (nullable NSToolbarItem *) toolbarItemForIdentifier:(NSString *) identifier inView:(id <JVChatViewController>) view willBeInsertedIntoToolbar:(BOOL) willBeInserted;
@end

NS_ASSUME_NONNULL_END
