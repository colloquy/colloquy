#import <AppKit/NSWindowController.h>
#import <AppKit/NSNibDeclarations.h>
#import "JVInspectorController.h"

@class NSDrawer;
@class NSOutlineView;
@class MVMenuButton;
@class NSMutableArray;
@class MVChatConnection;
@class NSArray;
@class NSToolbarItem;
@class NSString;
@class NSView;
@class JVChatWindowController;
@class NSToolbar;
@class NSImage;
@class NSMenu;

@protocol JVChatViewController;
@protocol JVChatListItem;

extern NSString *JVToolbarToggleChatDrawerItemIdentifier;
extern NSString *JVChatViewPboardType;

@interface JVChatWindowController : NSWindowController <JVInspectionDelegator> {
	@private
	IBOutlet NSDrawer *viewsDrawer;
	IBOutlet NSOutlineView *chatViewsOutlineView;
	IBOutlet MVMenuButton *viewActionButton;
	NSView *_placeHolder;
	NSMutableArray *_views;
	id <JVChatViewController> _activeViewController;
	BOOL _usesSmallIcons;
}
- (void) showChatViewController:(id <JVChatViewController>) controller;

- (void) addChatViewController:(id <JVChatViewController>) controller;
- (void) insertChatViewController:(id <JVChatViewController>) controller atIndex:(unsigned int) index;

- (void) removeChatViewController:(id <JVChatViewController>) controller;
- (void) removeChatViewControllerAtIndex:(unsigned int) index;
- (void) removeAllChatViewControllers;

- (void) replaceChatViewController:(id <JVChatViewController>) controller withController:(id <JVChatViewController>) newController;
- (void) replaceChatViewControllerAtIndex:(unsigned int) index withController:(id <JVChatViewController>) controller;

- (NSArray *) chatViewControllersForConnection:(MVChatConnection *) connection;
- (NSArray *) chatViewControllersWithControllerClass:(Class) class;
- (NSArray *) allChatViewControllers;

- (NSToolbarItem *) toggleChatDrawerToolbarItem;
- (IBAction) toggleViewsDrawer:(id) sender;

- (void) reloadChatView:(id <JVChatViewController>) controller;
@end

@protocol JVChatViewController <NSObject, JVChatListItem>
- (MVChatConnection *) connection;

- (JVChatWindowController *) windowController;
- (void) setWindowController:(JVChatWindowController *) controller;

- (NSView *) view;
- (NSToolbar *) toolbar;
- (NSString *) windowTitle;
- (NSString *) identifier;
@end

@interface NSObject (JVChatViewControllerOptional)
- (void) willSelect;
- (void) didSelect;

- (void) willUnselect;
- (void) didUnselect;
@end

@protocol JVChatListItem <NSObject>
- (id <JVChatListItem>) parent;

- (NSImage *) icon;
- (NSMenu *) menu;
- (NSString *) title;
- (NSString *) information;
- (NSImage *) statusImage;

- (int) numberOfChildren;
- (id) childAtIndex:(int) index;
@end
