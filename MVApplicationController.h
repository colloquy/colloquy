#import <Foundation/NSObject.h>
#import <AppKit/NSNibDeclarations.h>

@class MVPreferencesController;
//@class MVConnectionsController;
@class MVFileTransferController;
@class MVBuddyListController;

@interface MVApplicationController : NSObject {}
- (IBAction) checkForUpdate:(id) sender;
- (IBAction) connectToSupportRoom:(id) sender;
- (IBAction) emailDeveloper:(id) sender;
- (IBAction) productWebsite:(id) sender;

- (IBAction) showPreferences:(id) sender;
- (IBAction) showTransferManager:(id) sender;
- (IBAction) showConnectionManager:(id) sender;
- (IBAction) showBuddyList:(id) sender;
@end
