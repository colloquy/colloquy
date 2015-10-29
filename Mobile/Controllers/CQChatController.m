#import "CQChatController.h"

#import "CQAlertView.h"
#import "CQChatCreationViewController.h"
#import "CQChatNavigationController.h"
#import "CQChatOrderingController.h"
#import "CQChatPresentationController.h"
#import "CQChatRoomController.h"
#import "CQColloquyApplication.h"
#import "CQConnectionsController.h"
#import "CQConsoleController.h"
#if ENABLE(FILE_TRANSFERS)
#import "CQFileTransferController.h"
#endif
#import "CQSoundController.h"

#import <ChatCore/MVChatUser.h>
#import <ChatCore/MVDirectChatConnection.h>
#if ENABLE(FILE_TRANSFERS)
#import <ChatCore/MVFileTransfer.h>
#endif

#import "NSNotificationAdditions.h"

NS_ASSUME_NONNULL_BEGIN

NSString *CQChatControllerAddedChatViewControllerNotification = @"CQChatControllerAddedChatViewControllerNotification";
NSString *CQChatControllerRemovedChatViewControllerNotification = @"CQChatControllerRemovedChatViewControllerNotification";
NSString *CQChatControllerChangedTotalImportantUnreadCountNotification = @"CQChatControllerChangedTotalImportantUnreadCountNotification";

#define ChatRoomInviteAlertTag 1
#if ENABLE(FILE_TRANSFERS)
#define FileDownloadAlertTag 2
#endif

#define NewChatActionSheetTag 0
#define NewConnectionActionSheetTag 1
#if ENABLE(FILE_TRANSFERS)
#define SendFileActionSheetTag 2
#define FileTypeActionSheetTag 3
#endif

static NSInteger alwaysShowNotices;
static NSString *chatRoomInviteAction;
static BOOL vibrateOnHighlight;
static CQSoundController *highlightSound;

#if ENABLE(FILE_TRANSFERS)
static BOOL vibrateOnFileTransfer;
static CQSoundController *fileTransferSound;
#endif

#pragma mark -

@interface CQChatController () <UIActionSheetDelegate, UIAlertViewDelegate, UIImagePickerControllerDelegate>
@end

@implementation CQChatController {
	CQChatNavigationController *_chatNavigationController;
	CQChatPresentationController *_chatPresentationController;
	id <CQChatViewController> _nextController;
	id <CQChatViewController> _visibleChatController;
	MVChatConnection *_nextRoomConnection;
	NSInteger _totalImportantUnreadCount;
	MVChatUser *_fileUser;
}

+ (void) userDefaultsChanged {
	if (![NSThread isMainThread])
		return;

	alwaysShowNotices = [[CQSettingsController settingsController] integerForKey:@"JVChatAlwaysShowNotices"];
	vibrateOnHighlight = [[CQSettingsController settingsController] boolForKey:@"CQVibrateOnHighlight"];

	chatRoomInviteAction = [[[CQSettingsController settingsController] stringForKey:@"CQChatRoomInviteAction"] copy];

	NSString *soundName = [[CQSettingsController settingsController] stringForKey:@"CQSoundOnHighlight"];

	highlightSound = ([soundName isEqualToString:@"None"] ? nil : [[CQSoundController alloc] initWithSoundNamed:soundName]);

#if ENABLE(FILE_TRANSFERS)
	vibrateOnFileTransfer = [[CQSettingsController settingsController] boolForKey:@"CQVibrateOnFileTransfer"];

	soundName = [[CQSettingsController settingsController] stringForKey:@"CQSoundOnFileTransfer"];

	old = fileTransferSound;
	fileTransferSound = ([soundName isEqualToString:@"None"] ? nil : [[CQSoundController alloc] initWithSoundNamed:soundName]);
	[old release];
#endif
}

+ (void) initialize {
	static BOOL userDefaultsInitialized;

	if (userDefaultsInitialized)
		return;

	userDefaultsInitialized = YES;

	[[NSNotificationCenter chatCenter] addObserver:self selector:@selector(userDefaultsChanged) name:CQSettingsDidChangeNotification object:nil];

	[self userDefaultsChanged];
}

+ (CQChatController *) defaultController {
	static BOOL creatingSharedInstance = NO;
	static CQChatController *sharedInstance = nil;

	if (!sharedInstance && !creatingSharedInstance) {
		creatingSharedInstance = YES;
		sharedInstance = [[self alloc] init];
	}

	return sharedInstance;
}

#pragma mark -

- (instancetype) init {
	if (!(self = [super init]))
		return nil;

	_chatNavigationController = [[CQChatNavigationController alloc] init];
	_chatPresentationController = [[CQChatPresentationController alloc] init];

	[[NSNotificationCenter chatCenter] addObserver:self selector:@selector(_joinedRoom:) name:MVChatRoomJoinedNotification object:nil];
	[[NSNotificationCenter chatCenter] addObserver:self selector:@selector(_gotRoomMessage:) name:MVChatRoomGotMessageNotification object:nil];
	[[NSNotificationCenter chatCenter] addObserver:self selector:@selector(_gotPrivateMessage:) name:MVChatConnectionGotPrivateMessageNotification object:nil];
	[[NSNotificationCenter chatCenter] addObserver:self selector:@selector(_gotDirectChatMessage:) name:MVDirectChatConnectionGotMessageNotification object:nil];
	[[NSNotificationCenter chatCenter] addObserver:self selector:@selector(_invitedToRoom:) name:MVChatRoomInvitedNotification object:nil];
#if ENABLE(FILE_TRANSFERS)
	[[NSNotificationCenter chatCenter] addObserver:self selector:@selector(_gotFileDownloadOffer:) name:MVDownloadFileTransferOfferNotification object:nil];
#endif

	return self;
}

- (void) dealloc {
	[[NSNotificationCenter chatCenter] removeObserver:self];
	[[NSNotificationCenter chatCenter] removeObserver:_chatPresentationController];
}

#pragma mark -

- (void) _joinedRoom:(NSNotification *) notification {
	MVChatRoom *room = notification.object;
	CQChatRoomController *roomController = [[CQChatOrderingController defaultController] chatViewControllerForRoom:room ifExists:NO];
	[roomController didJoin];
}

- (void) _gotRoomMessage:(NSNotification *) notification {
	// We do this here to make sure we catch early messages right when we join (this includes dircproxy's dump).
	MVChatRoom *room = notification.object;

	CQChatRoomController *controller = [[CQChatOrderingController defaultController] chatViewControllerForRoom:room ifExists:NO];
	[controller addMessage:notification.userInfo];

	[[CQColloquyApplication sharedApplication] updateAppShortcuts];
}

- (void) _gotPrivateMessage:(NSNotification *) notification {
	MVChatUser *user = notification.object;

	if (user.localUser && notification.userInfo[@"target"])
		user = notification.userInfo[@"target"];

	BOOL hideFromUser = NO;
	if ([notification.userInfo[@"notice"] boolValue]) {
		if (![[CQChatOrderingController defaultController] chatViewControllerForUser:user ifExists:YES])
			hideFromUser = YES;

		if ( alwaysShowNotices == 1 || ( alwaysShowNotices == 0 && ![notification userInfo][@"handled"] ) )
			hideFromUser = NO;
	}

	if (!hideFromUser) {
		CQDirectChatController *controller = [[CQChatOrderingController defaultController] chatViewControllerForUser:user ifExists:NO userInitiated:NO];
		[controller addMessage:notification.userInfo];
		[[CQColloquyApplication sharedApplication] updateAppShortcuts];
	}
}

- (void) _gotDirectChatMessage:(NSNotification *) notification {
	MVDirectChatConnection *connection = notification.object;

	CQDirectChatController *controller = [[CQChatOrderingController defaultController] chatViewControllerForDirectChatConnection:connection ifExists:NO];
	[controller addMessage:notification.userInfo];
	[[CQColloquyApplication sharedApplication] updateAppShortcuts];
}

#if ENABLE(FILE_TRANSFERS)
- (void) _gotFileDownloadOffer:(NSNotification *) notification {
	MVDownloadFileTransfer *transfer = notification.object;

	NSString *action = [[CQSettingsController settingsController] stringForKey:@"CQFileDownloadAction"];
	if ([action isEqualToString:@"Auto-Accept"]) {
		[self chatViewControllerForFileTransfer:transfer ifExists:NO];

		NSString *filePath = [NSTemporaryDirectory() stringByAppendingPathComponent:transfer.originalFileName];
		[transfer setDestination:filePath renameIfFileExists:YES];
		[transfer acceptByResumingIfPossible:YES];
		return;
	} else if ([action isEqualToString:@"Auto-Deny"]) {
		[transfer reject];
		return;
	}

	[self chatViewControllerForFileTransfer:transfer ifExists:NO];

	NSString *file = transfer.originalFileName;
	NSString *user = transfer.user.displayName;

	UIAlertView *alert = [[CQAlertView alloc] init];
	alert.tag = FileDownloadAlertTag;
	alert.delegate = self;
	alert.title = NSLocalizedString(@"File Download", "File Download alert title");
	alert.message = [NSString stringWithFormat:NSLocalizedString(@"%@ wants to send you \"%@\".", "File download alert message"), user, file];

	[alert associateObject:transfer forKey:@"transfer"];
	[alert addButtonWithTitle:NSLocalizedString(@"Accept", @"Accept alert button title")];

	alert.cancelButtonIndex = [alert addButtonWithTitle:NSLocalizedString(@"Deny", @"Deny alert button title")];

	if (vibrateOnFileTransfer)
		[CQSoundController vibrate];

	[fileTransferSound playSound];

	[alert show];

	[alert release];
}

- (void) _sendImage:(UIImage *) image asPNG:(BOOL) asPNG {
	NSData *data = nil;
	if (asPNG) data = UIImagePNGRepresentation(image);
	else data = UIImageJPEGRepresentation(image, 0.83333333f);

	NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
	[formatter setDateFormat:@"yyyy-MM-dd-A"];

	NSString *name = [[formatter stringFromDate:[NSDate date]] stringByAppendingString:@".png"];
	[formatter release];

	name = [name stringByReplacingOccurrencesOfString:@" " withString:@"_"];

	NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:name];
	[data writeToFile:path atomically:NO];

	MVUploadFileTransfer *transfer = [_fileUser sendFile:path passively:YES];
	[self chatViewControllerForFileTransfer:transfer ifExists:NO];
	[_fileUser release];
}
#endif

- (void) _invitedToRoom:(NSNotification *) notification {
	NSString *roomName = notification.userInfo[@"room"];
	MVChatConnection *connection = [notification object];
	MVChatUser *invitedUser = notification.userInfo[@"target"];
	MVChatUser *user = notification.userInfo[@"user"];
	MVChatRoom *room = [connection chatRoomWithName:roomName];

	if (invitedUser) {
		NSString *message = [NSString stringWithFormat:NSLocalizedString(@"%@ invited %@ to \"%@\" on \"%@\".", "User invited to join room alert message"), user.displayName, invitedUser.displayName, room.displayName, connection.displayName];
		CQDirectChatController *chatController = [[CQChatOrderingController defaultController] chatViewControllerForRoom:room ifExists:NO];
		[chatController addEventMessage:message withIdentifier:@""];
		return;
	}

	if ([chatRoomInviteAction isEqualToString:@"Auto-Join"]) {
		[connection joinChatRoomNamed:roomName];
		return;
	} else if ([chatRoomInviteAction isEqualToString:@"Auto-Deny"]) {
		return;
	}


	NSString *message = [NSString stringWithFormat:NSLocalizedString(@"You are invited to \"%@\" by \"%@\" on \"%@\".", "Invited to join room alert message"), room.displayName, user.displayName, connection.displayName];

	if ([UIApplication sharedApplication].applicationState == UIApplicationStateBackground) {
		UILocalNotification *localNotification = [[UILocalNotification alloc] init];

		localNotification.alertBody = message;
		localNotification.alertAction = NSLocalizedString(@"Join", "Join button title");
		localNotification.userInfo = @{@"c": connection.uniqueIdentifier, @"r": room.name, @"a": @"j"};
		localNotification.soundName = UILocalNotificationDefaultSoundName;

		[[UIApplication sharedApplication] presentLocalNotificationNow:localNotification];

		return;
	}

	CQAlertView *alert = [[CQAlertView alloc] init];
	alert.tag = ChatRoomInviteAlertTag;
	alert.delegate = self;
	alert.title = NSLocalizedString(@"Invited to Room", "Invited to room alert title");
	alert.message = message;

	alert.cancelButtonIndex = [alert addButtonWithTitle:NSLocalizedString(@"Dismiss", @"Dismiss alert button title")];

	[alert associateObject:room forKey:@"userInfo"];
	[alert addButtonWithTitle:NSLocalizedString(@"Join", @"Join button title")];

	if (vibrateOnHighlight)
		[CQSoundController vibrate];

	if (highlightSound)
		[highlightSound playSound];

	[alert show];
}

#pragma mark -

- (void) alertView:(UIAlertView *) alertView clickedButtonAtIndex:(NSInteger) buttonIndex {
	id userInfo = [alertView associatedObjectForKey:@"userInfo"];

	if (buttonIndex == alertView.cancelButtonIndex) {
#if ENABLE(FILE_TRANSFERS)
		if (alertView.tag == FileDownloadAlertTag)
			[(MVDownloadFileTransfer *)userInfo reject];
#endif
		return;
	}

	if (alertView.tag == ChatRoomInviteAlertTag) {
		MVChatRoom *room = userInfo;
		[[CQChatController defaultController] showChatControllerWhenAvailableForRoomNamed:room.name andConnection:room.connection];
		[room join];
#if ENABLE(FILE_TRANSFERS)
	} else if (alertView.tag == FileDownloadAlertTag) {
		MVDownloadFileTransfer *transfer = userInfo;
		NSString *filePath = [NSTemporaryDirectory() stringByAppendingPathComponent:transfer.originalFileName];
		[self chatViewControllerForFileTransfer:transfer ifExists:NO];
		[transfer setDestination:filePath renameIfFileExists:YES];
		[transfer acceptByResumingIfPossible:YES];
#endif
	}
}

#pragma mark -

- (void) actionSheet:(UIActionSheet *) actionSheet clickedButtonAtIndex:(NSInteger) buttonIndex {
	if (buttonIndex == actionSheet.cancelButtonIndex) {
		_fileUser = nil;
		return;
	}

	if (actionSheet.tag == NewChatActionSheetTag) {
		CQChatCreationViewController *creationViewController = [[CQChatCreationViewController alloc] init];
		creationViewController.selectedConnection = [actionSheet associatedObjectForKey:@"userInfo"];

		if (buttonIndex == 0)
			creationViewController.roomTarget = YES;

		[[CQColloquyApplication sharedApplication] presentModalViewController:creationViewController animated:YES];
	} else if (actionSheet.tag == NewConnectionActionSheetTag) {
		if (buttonIndex == 1) {
			[self joinSupportRoom];
		}
#if ENABLE(FILE_TRANSFERS)
	} else if (actionSheet.tag == SendFileActionSheetTag) {
		BOOL sendExistingPhoto = NO;
		BOOL takeNewPhoto = NO;
		BOOL sendContact = NO;

		if (buttonIndex == 0) {
			if ([UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera]) {
				takeNewPhoto = YES;
			} else if ([UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypePhotoLibrary]) {
				sendExistingPhoto = YES;
			} else {
				sendContact = YES;
			}
		} else if (buttonIndex == 1) {
			if ([UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypePhotoLibrary]) {
				sendExistingPhoto = YES;
			} else {
				sendContact = YES;
			}
		} else {
			sendContact = YES;
		}

		if (takeNewPhoto) {
			UIImagePickerController *picker = [[UIImagePickerController alloc] init];
			picker.delegate = self;
			picker.allowsEditing = YES;
			picker.sourceType = UIImagePickerControllerSourceTypeCamera;
			[[CQColloquyApplication sharedApplication] presentModalViewController:picker animated:YES];
			[picker release];
		} else if (sendExistingPhoto) {
			UIImagePickerController *picker = [[UIImagePickerController alloc] init];
			picker.delegate = self;
			picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
			[[CQColloquyApplication sharedApplication] presentModalViewController:picker animated:YES];
			[picker release];
		} else if (sendContact) {
			NSAssert(NO, @"Contact sending not implemented.");
		}
	} else if (actionSheet.tag == FileTypeActionSheetTag) {
		[self _sendImage:[actionSheet associatedObjectForKey:@"image"] asPNG:(buttonIndex == 0)];
#endif
	}
}

#pragma mark -

#if ENABLE(FILE_TRANSFERS)
- (void) imagePickerController:(UIImagePickerController *) picker didFinishPickingImage:(UIImage *) image editingInfo:(NSDictionary *) editingInfo {
	NSString *behavior = [[CQSettingsController settingsController] stringForKey:@"CQImageFileTransferBehavior"];
	if ([behavior isEqualToString:@"Ask"]) {
		UIActionSheet *sheet = [[UIActionSheet alloc] init];
		sheet.delegate = self;
		sheet.tag = FileTypeActionSheetTag;
		[sheet associateObject:image forKey:@"image"];
		[sheet addButtonWithTitle:NSLocalizedString(@"PNG", @"PNG button title")];
		[sheet addButtonWithTitle:NSLocalizedString(@"JPG", @"JPG button title")];
		[[CQColloquyApplication sharedApplication] showActionSheet:sheet];
		[sheet release];
	} else {
		[self _sendImage:image asPNG:[behavior isEqualToString:@"PNG"]];
	}

	[[CQColloquyApplication sharedApplication] dismissModalViewControllerAnimated:YES];
}

- (void) imagePickerControllerDidCancel:(UIImagePickerController *) picker {
	[[CQColloquyApplication sharedApplication] dismissModalViewControllerAnimated:YES];
	[_fileUser release];
}
#endif

#pragma mark -

- (void) setTotalImportantUnreadCount:(NSInteger) count {
	if (count < 0)
		count = 0;

	_totalImportantUnreadCount = count;

	if ([CQColloquyApplication sharedApplication].areNotificationBadgesAllowed)
		[UIApplication sharedApplication].applicationIconBadgeNumber = count;

	[[NSNotificationCenter chatCenter] postNotificationName:CQChatControllerChangedTotalImportantUnreadCountNotification object:self];
}

- (NSInteger) totalUnreadCount {
	NSInteger totalUnreadCount = 0;
	for (id <CQChatViewController> chatViewController in [CQChatOrderingController defaultController].chatViewControllers)
		if ([chatViewController respondsToSelector:@selector(unreadCount)])
			totalUnreadCount += chatViewController.unreadCount;
	return totalUnreadCount;
}

- (void) resetTotalUnreadCount {
	for (id <CQChatViewController> chatViewController in [CQChatOrderingController defaultController].chatViewControllers)
		if ([chatViewController respondsToSelector:@selector(markAsRead)])
			[chatViewController markAsRead];
}

#pragma mark -

- (NSDictionary *) persistentStateForConnection:(MVChatConnection *) connection {
	NSArray <id <CQChatViewController>> *controllers = [[CQChatOrderingController defaultController] chatViewControllersForConnection:connection];
	if (!controllers.count)
		return nil;

	NSMutableDictionary *state = [[NSMutableDictionary alloc] init];
	NSMutableArray <NSDictionary *> *controllerStates = [[NSMutableArray alloc] init];

	for (id <CQChatViewController> controller in controllers) {
		if (![controller respondsToSelector:@selector(persistentState)])
			continue;

		NSDictionary *controllerState = controller.persistentState;
		if (!controllerState.count || !controllerState[@"class"])
			continue;

		[controllerStates addObject:controllerState];
	}

	if (controllerStates.count)
		state[@"chatControllers"] = controllerStates;

	return state;
}

- (void) restorePersistentState:(NSDictionary *) state forConnection:(MVChatConnection *) connection {
	NSMutableArray <id <CQChatViewController>> *viewControllers = [NSMutableArray array];

	for (NSDictionary *controllerState in state[@"chatControllers"]) {
		NSString *className = controllerState[@"class"];
		Class class = NSClassFromString(className);
		if (!class)
			continue;

		id <CQChatViewController> controller = [[class alloc] initWithPersistentState:controllerState usingConnection:connection];
		if (!controller)
			continue;

		[viewControllers addObject:controller];

		if ([controllerState[@"active"] boolValue])
			_nextController = controller;
	}

	[[CQChatOrderingController defaultController] addViewControllers:viewControllers];
}

#pragma mark -

- (void) showNewChatActionSheetForConnection:(MVChatConnection *) connection fromPoint:(CGPoint) point {
	UIActionSheet *sheet = [[UIActionSheet alloc] init];
	sheet.delegate = self;

	[sheet associateObject:connection forKey:@"userInfo"];

	if ([CQConnectionsController defaultController].connections.count) {
		sheet.tag = NewChatActionSheetTag;

		[sheet addButtonWithTitle:NSLocalizedString(@"Join a Chat Room", @"Join a Chat Room button title")];
		[sheet addButtonWithTitle:NSLocalizedString(@"Message a User", @"Message a User button title")];
	} else {
		sheet.tag = NewConnectionActionSheetTag;

		[sheet addButtonWithTitle:NSLocalizedString(@"Join Support Room", @"Join Support Room button title")];
	}

	sheet.cancelButtonIndex = [sheet addButtonWithTitle:NSLocalizedString(@"Cancel", @"Cancel button title")];

	[[CQColloquyApplication sharedApplication] showActionSheet:sheet fromPoint:point];
}

#pragma mark -

- (void) showChatControllerWhenAvailableForRoomNamed:(NSString *) roomName andConnection:(MVChatConnection *) connection {
	NSParameterAssert(connection != nil);

	_nextRoomConnection = nil;

	MVChatRoom *room = (roomName.length ? [connection chatRoomWithName:roomName] : nil);
	if (room) {
		CQChatRoomController *controller = [[CQChatOrderingController defaultController] chatViewControllerForRoom:room ifExists:YES];
		if (controller) {
			[self showChatController:controller animated:[UIView areAnimationsEnabled]];
			return;
		}
	}

	_nextRoomConnection = connection;
}

- (void) showChatControllerForUserNicknamed:(NSString *) nickname andConnection:(MVChatConnection *) connection {
	_nextRoomConnection = nil;

	MVChatUser *user = (nickname.length ? [[connection chatUsersWithNickname:nickname] anyObject] : nil);
	if (!user)
		return;

	CQDirectChatController *controller = [[CQChatOrderingController defaultController] chatViewControllerForUser:user ifExists:NO];
	if (!controller)
		return;

	[self showChatController:controller animated:[UIView areAnimationsEnabled]];
}

- (void) showChatController:(id <CQChatViewController>) controller animated:(BOOL) animated {
	_nextRoomConnection = nil;

	[_chatNavigationController dismissViewControllerAnimated:animated completion:NULL];
	[_chatNavigationController selectChatViewController:controller animatedSelection:animated animatedScroll:animated];

	UINavigationController *navigationController = ((UIViewController *)_visibleChatController).navigationController;
	if (navigationController == nil) {
		navigationController = [[UINavigationController alloc] initWithRootViewController:(UIViewController *)controller];
		[_chatNavigationController.splitViewController showDetailViewController:navigationController sender:nil];
	} else if (controller) navigationController.viewControllers = @[ controller ];

	_visibleChatController = controller;
}

- (void) setFirstChatController {
	MVChatConnection *connection = [[CQChatOrderingController defaultController] connectionAtIndex:0];
	if (!connection)
		return;

	NSArray <id <CQChatViewController>> *chatViewControllersForConnection = [[CQChatOrderingController defaultController] chatViewControllersForConnection:connection];
	_nextController = chatViewControllersForConnection.firstObject;
}

- (void) showPendingChatControllerAnimated:(BOOL) animated {
	if (_nextController)
		[self showChatController:_nextController animated:animated];
	_nextController = nil;
}

- (BOOL) hasPendingChatController {
	return !!_nextController;
}

#pragma mark -

#if ENABLE(FILE_TRANSFERS)
- (void) showFilePickerWithUser:(MVChatUser *) user {
	UIActionSheet *sheet = [[UIActionSheet alloc] init];
	sheet.delegate = self;
	sheet.tag = SendFileActionSheetTag;

	if ([UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera])
		[sheet addButtonWithTitle:NSLocalizedString(@"Take Photo", @"Take Photo button title")];
	if ([UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypePhotoLibrary])
		[sheet addButtonWithTitle:NSLocalizedString(@"Choose Existing Photo", @"Choose Existing Photo button title")];
//	[sheet addButtonWithTitle:NSLocalizedString(@"Choose Contact", @"Choose Contact button title")];

	sheet.cancelButtonIndex = [sheet addButtonWithTitle:NSLocalizedString(@"Cancel", @"Cancel button title")];

	_fileUser = [user retain];

	[[CQColloquyApplication sharedApplication] showActionSheet:sheet];

	[sheet release];
}
#endif

#pragma mark -

- (void) joinSupportRoom {
	MVChatConnection *connection = [[CQConnectionsController defaultController] connectionForServerAddress:@"freenode.net"];
	if (!connection) connection = [[CQConnectionsController defaultController] connectionForServerAddress:@"freenode.com"];

	if (!connection) {
		connection = [[MVChatConnection alloc] initWithType:MVChatConnectionIRCType];
		connection.displayName = @"Freenode";
		connection.server = @"irc.freenode.net";
		connection.preferredNickname = [MVChatConnection defaultNickname];
		connection.realName = [MVChatConnection defaultRealName];
		connection.username = [connection.preferredNickname lowercaseString];
		connection.encoding = [MVChatConnection defaultEncoding];
		connection.automaticallyConnect = NO;
		connection.multitaskingSupported = YES;
		connection.secure = YES;
		connection.serverPort = 6697;

		[[CQConnectionsController defaultController] addConnection:connection];
	}

	[connection connectAppropriately];

	[self showChatControllerWhenAvailableForRoomNamed:@"#colloquy-mobile" andConnection:connection];

	[connection joinChatRoomNamed:@"#colloquy-mobile"];
}

#pragma mark -

- (void) showConsoleForConnection:(MVChatConnection *) connection {
	CQConsoleController *consoleController = [[CQChatOrderingController defaultController] chatViewControllerForConnection:connection ifExists:NO userInitiated:NO];

	[self showChatController:consoleController animated:YES];
}

#pragma mark -

- (void) _showChatControllerUnanimated:(id) controller {
	[self showChatController:controller animated:NO];
}

- (void) visibleChatControllerWasHidden {
	_visibleChatController = nil;
}

- (void) closeViewController:(id) controller {
	if ([controller respondsToSelector:@selector(close)])
		[controller close];

	NSUInteger controllerIndex = [[CQChatOrderingController defaultController] indexOfViewController:controller];

	[[CQChatOrderingController defaultController] removeViewController:controller];

	NSDictionary *notificationInfo = @{@"controller": controller};
	[[NSNotificationCenter chatCenter] postNotificationName:CQChatControllerRemovedChatViewControllerNotification object:self userInfo:notificationInfo];

	if (_visibleChatController == controller) {
		if ([CQChatOrderingController defaultController].chatViewControllers.count) {
			if (!controllerIndex)
				controllerIndex = 1;
			[self _showChatControllerUnanimated:[CQChatOrderingController defaultController].chatViewControllers[(controllerIndex - 1)]];
		}
	}
}
@end

NS_ASSUME_NONNULL_END

#pragma mark -

NS_ASSUME_NONNULL_BEGIN

@implementation MVIRCChatRoom (CQChatControllerAdditions)
- (NSString *) displayName {
	if (![[CQSettingsController settingsController] boolForKey:@"JVShowFullRoomNames"])
		return [self.connection displayNameForChatRoomNamed:self.name];
	return self.name;
}
@end

NS_ASSUME_NONNULL_END
