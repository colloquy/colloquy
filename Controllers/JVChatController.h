#import <Cocoa/Cocoa.h>
#import "KAIgnoreRule.h"

@class MVChatConnection;
@class MVChatRoom;
@class MVChatUser;
@class MVDirectChatConnection;
@class JVChatWindowController;
@class JVChatRoomPanel;
@class JVDirectChatPanel;
@class JVChatTranscriptPanel;
@class JVSmartTranscriptPanel;
@class JVChatConsolePanel;

@protocol JVChatViewController;

@interface JVChatController : NSObject {
	@private
	NSMutableSet *_chatWindows;
	NSMutableSet *_chatControllers;
	NSArray *_windowRuleSets;
}
+ (JVChatController *) defaultController;
+ (NSMenu *) smartTranscriptMenu;
+ (void) refreshSmartTranscriptMenu;

- (void) addViewControllerToPreferedWindowController:(id <JVChatViewController>) controller userInitiated:(BOOL) initiated;

@property (readonly, copy) NSSet<JVChatWindowController*> *allChatWindowControllers;
@property (readonly, strong) JVChatWindowController *createChatWindowController;
- (JVChatWindowController *) chatWindowControllerWithIdentifier:(NSString *) identifier;
- (void) disposeChatWindowController:(JVChatWindowController *) controller;

@property (readonly, copy) NSSet<id <JVChatViewController>> *allChatViewControllers;
- (NSSet<id <JVChatViewController>> *) chatViewControllersWithConnection:(MVChatConnection *) connection;
- (NSSet<id <JVChatViewController>> *) chatViewControllersOfClass:(Class) class;
- (NSSet<id <JVChatViewController>> *) chatViewControllersKindOfClass:(Class) class;

- (JVChatRoomPanel *) chatViewControllerForRoom:(MVChatRoom *) room ifExists:(BOOL) exists;
- (JVDirectChatPanel *) chatViewControllerForUser:(MVChatUser *) user ifExists:(BOOL) exists;
- (JVDirectChatPanel *) chatViewControllerForUser:(MVChatUser *) user ifExists:(BOOL) exists userInitiated:(BOOL) requested;
- (JVDirectChatPanel *) chatViewControllerForDirectChatConnection:(MVDirectChatConnection *) connection ifExists:(BOOL) exists;
- (JVDirectChatPanel *) chatViewControllerForDirectChatConnection:(MVDirectChatConnection *) connection ifExists:(BOOL) exists userInitiated:(BOOL) initiated;
- (JVChatTranscriptPanel *) chatViewControllerForTranscript:(NSString *) filename;
- (JVChatConsolePanel *) chatConsoleForConnection:(MVChatConnection *) connection ifExists:(BOOL) exists;

- (JVSmartTranscriptPanel *)createSmartTranscript NS_RETURNS_RETAINED;
@property (readonly, copy) NSSet<JVSmartTranscriptPanel*> *smartTranscripts;
- (void) saveSmartTranscripts;
- (void) disposeSmartTranscript:(JVSmartTranscriptPanel *) panel;

- (void) disposeViewController:(id <JVChatViewController>) controller;
- (void) detachViewController:(id <JVChatViewController>) controller;

- (IBAction) detachView:(id) sender;

- (JVIgnoreMatchResult) shouldIgnoreUser:(MVChatUser *) user withMessage:(NSAttributedString *) message inView:(id <JVChatViewController>) view;
@end

@interface NSObject (MVChatPluginCommandSupport)
- (BOOL) processUserCommand:(NSString *) command withArguments:(NSAttributedString *) arguments toConnection:(MVChatConnection *) connection inView:(id <JVChatViewController>) view;
@end
