#import "MVChatPluginManagerAdditions.h"
#import "MVConnectionsController.h"
#import "MVFileTransferController.h"
#import "MVBuddyListController.h"
#import "JVChatController.h"
#import "JVPreferencesController.h"

@implementation MVChatPluginManager (MVChatPluginManagerAdditions)
- (MVConnectionsController *) connectionsController {
	return [MVConnectionsController defaultManager];
}

- (JVChatController *) chatController {
	return [JVChatController defaultManager];
}

- (MVFileTransferController *) fileTransferController {
	return [MVFileTransferController defaultManager];	
}

- (MVBuddyListController *) buddyListController {
	return [MVBuddyListController sharedBuddyList];
}

- (JVPreferencesController *) preferencesController {
	return [JVPreferencesController sharedPreferences];
}
@end
