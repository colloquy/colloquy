#import <Foundation/NSObject.h>
#import <AppKit/NSNibDeclarations.h>

@class NSMutableSet;
@class MVChatConnection;
@class NSSet;
@class JVChatWindowController;
@class NSString;

@protocol JVChatViewController;

@interface JVChatController : NSObject {
	@private
	NSMutableSet *_chatWindows;
	NSMutableSet *_chatControllers;
}
+ (JVChatController *) defaultManager;

- (NSSet *) allChatWindowControllers;
- (JVChatWindowController *) newChatWindowController;
- (void) disposeChatWindowController:(JVChatWindowController *) controller;

- (NSSet *) allChatViewControllers;
- (NSSet *) chatViewControllersWithConnection:(MVChatConnection *) connection;
- (NSSet *) chatViewControllersOfClass:(Class) class;
- (id <JVChatViewController>) chatViewControllerForRoom:(NSString *) room withConnection:(MVChatConnection *) connection ifExists:(BOOL) exists;
- (id <JVChatViewController>) chatViewControllerForUser:(NSString *) user withConnection:(MVChatConnection *) connection ifExists:(BOOL) exists;
- (id <JVChatViewController>) chatViewControllerForTranscript:(NSString *) filename;
- (id <JVChatViewController>) chatConsoleForConnection:(MVChatConnection *) connection ifExists:(BOOL) exists;
- (void) disposeViewController:(id <JVChatViewController>) controller;
@end
