#import "KAIgnoreRule.h"

@class MVChatConnection;
@class MVChatRoom;
@class MVChatUser;
@class JVChatWindowController;
@class JVChatRoomPanel;
@class JVDirectChatPanel;
@class JVChatTranscriptPanel;
@class JVChatConsolePanel;
@class KAInternalIgnoreRule;

@protocol JVChatViewController;

@interface JVChatController : NSObject {
	@private
	NSMutableArray *_chatWindows;
	NSMutableArray *_chatControllers;
	NSMutableArray *_ignoreRules;
}
+ (JVChatController *) defaultManager;

- (NSSet *) allChatWindowControllers;
- (JVChatWindowController *) newChatWindowController;
- (void) disposeChatWindowController:(JVChatWindowController *) controller;

- (NSSet *) allChatViewControllers;
- (NSSet *) chatViewControllersWithConnection:(MVChatConnection *) connection;
- (NSSet *) chatViewControllersOfClass:(Class) class;
- (NSSet *) chatViewControllersKindOfClass:(Class) class;

- (JVChatRoomPanel *) chatViewControllerForRoom:(MVChatRoom *) room ifExists:(BOOL) exists;
- (JVDirectChatPanel *) chatViewControllerForUser:(MVChatUser *) user ifExists:(BOOL) exists;
- (JVDirectChatPanel *) chatViewControllerForUser:(MVChatUser *) user ifExists:(BOOL) exists userInitiated:(BOOL) requested;
- (JVChatTranscriptPanel *) chatViewControllerForTranscript:(NSString *) filename;
- (JVChatConsolePanel *) chatConsoleForConnection:(MVChatConnection *) connection ifExists:(BOOL) exists;

- (void) disposeViewController:(id <JVChatViewController>) controller;
- (void) detachViewController:(id <JVChatViewController>) controller;

- (IBAction) detachView:(id) sender;

- (JVIgnoreMatchResult) shouldIgnoreUser:(MVChatUser *) user withMessage:(NSAttributedString *) message inView:(id <JVChatViewController>) view;
@end

@interface NSObject (MVChatPluginCommandSupport)
- (BOOL) processUserCommand:(NSString *) command withArguments:(NSAttributedString *) arguments toConnection:(MVChatConnection *) connection inView:(id <JVChatViewController>) view;
@end