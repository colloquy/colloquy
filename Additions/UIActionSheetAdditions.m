#import "UIActionSheetAdditions.h"

#import "CQColloquyApplication.h"
#import "CQChatOrderingController.h"
#import "CQConnectionsController.h"
#import "CQDirectChatController.h"
#import "CQIgnoreRulesController.h"
#import "CQUserInfoController.h"

#import "KAIgnoreRule.h"

#import <ChatCore/MVChatConnection.h>
#import <ChatCore/MVChatRoom.h>
#import <ChatCore/MVChatUser.h>

#define SendMessageButtonIndex 0

@interface UIActionSheet () <UIActionSheetDelegate>
@end

@implementation UIActionSheet (Additions)
+ (UIActionSheet *) userActionSheetForUser:(MVChatUser *) user inRoom:(MVChatRoom *) room showingUserInformation:(BOOL) showingUserInformation {
	UIActionSheet *sheet = [[UIActionSheet alloc] init];
	sheet.tag = UserActionSheetTag;
	sheet.delegate = sheet;

	[sheet addButtonWithTitle:NSLocalizedString(@"Send Message", @"Send Message button title")];
	[sheet associateObject:user forKey:@"user"];
	[sheet associateObject:room forKey:@"room"];

	if ([[UIDevice currentDevice] isPadModel] || showingUserInformation)
		[sheet addButtonWithTitle:NSLocalizedString(@"User Information", @"User Information button title")];

	if (showingUserInformation)
		[sheet associateObject:[NSNull null] forKey:@"showing-user-information"];

#if ENABLE(FILE_TRANSFERS)
	[sheet addButtonWithTitle:NSLocalizedString(@"Send File", @"Send File button title")];
#endif

	if ([room.connection.ignoreController hasIgnoreRuleForUser:user]) {
		[sheet associateObject:[NSNull null] forKey:@"has-ignore-rule"];
		[sheet addButtonWithTitle:NSLocalizedString(@"Unignore", @"Unignore")];
	} else [sheet addButtonWithTitle:NSLocalizedString(@"Ignore", @"Ignore")];

	NSUInteger localUserModes = (room.connection.localUser ? [room modesForMemberUser:room.connection.localUser] : 0);
	BOOL showOperatorActions = (localUserModes & (MVChatRoomMemberHalfOperatorMode | MVChatRoomMemberOperatorMode | MVChatRoomMemberAdministratorMode | MVChatRoomMemberFounderMode));
	if (showOperatorActions)
		[sheet addButtonWithTitle:NSLocalizedString(@"Operator Actions…", @"Operator Actions button title")];

	sheet.cancelButtonIndex = [sheet addButtonWithTitle:NSLocalizedString(@"Cancel", @"Cancel button title")];

	return sheet;
}

+ (UIActionSheet *) operatorActionSheetWithLocalUserModes:(NSUInteger) localUserModes targetingUserWithModes:(NSUInteger) selectedUserModes disciplineModes:(NSUInteger) disciplineModes onRoomWithFeatures:(NSSet *) features {
	NSMutableDictionary *context = [[NSMutableDictionary alloc] init];

	UIActionSheet *operatorSheet = [[UIActionSheet alloc] init];
	operatorSheet.delegate = operatorSheet;
	operatorSheet.tag = OperatorActionSheetTag;

	[operatorSheet associateObject:context forKey:@"userInfo"];

	BOOL localUserIsHalfOperator = (localUserModes & MVChatRoomMemberHalfOperatorMode);
	BOOL localUserIsOperator = (localUserModes & MVChatRoomMemberOperatorMode);
	BOOL localUserIsAdministrator = (localUserModes & MVChatRoomMemberAdministratorMode);
	BOOL localUserIsFounder = (localUserModes & MVChatRoomMemberFounderMode);

	BOOL selectedUserIsQuieted = (disciplineModes & MVChatRoomMemberDisciplineQuietedMode);
	BOOL selectedUserHasVoice = (selectedUserModes & MVChatRoomMemberVoicedMode);
	BOOL selectedUserIsHalfOperator = (selectedUserModes & MVChatRoomMemberHalfOperatorMode);
	BOOL selectedUserIsOperator = (selectedUserModes & MVChatRoomMemberOperatorMode);
	BOOL selectedUserIsAdministrator = (selectedUserModes & MVChatRoomMemberAdministratorMode);
	BOOL selectedUserIsFounder = (selectedUserModes & MVChatRoomMemberFounderMode);

	if (localUserIsHalfOperator || localUserIsOperator || localUserIsAdministrator || localUserIsFounder) {
		[operatorSheet addButtonWithTitle:NSLocalizedString(@"Kick from Room", @"Kick from Room button title")];
		[operatorSheet addButtonWithTitle:NSLocalizedString(@"Ban from Room", @"Ban From Room button title")];

		context[@(0U)] = @"kick";
		context[@(1U)] = @"ban";
	}

	if (localUserIsFounder && [features containsObject:MVChatRoomMemberFounderFeature]) {
		if (selectedUserIsFounder) [operatorSheet addButtonWithTitle:NSLocalizedString(@"Demote from Founder", @"Demote from Founder button title")];
		else [operatorSheet addButtonWithTitle:NSLocalizedString(@"Promote to Founder", @"Promote to Founder button title")];

		context[@(operatorSheet.numberOfButtons - 1)] = @(MVChatRoomMemberFounderMode | (selectedUserIsFounder ? (1 << 16) : 0));
	}

	if ((localUserIsAdministrator || localUserIsFounder) && ((localUserIsAdministrator && !selectedUserIsFounder) || localUserIsFounder) && [features containsObject:MVChatRoomMemberAdministratorFeature]) {
		if (selectedUserIsAdministrator) [operatorSheet addButtonWithTitle:NSLocalizedString(@"Demote from Admin", @"Demote from Admin button title")];
		else [operatorSheet addButtonWithTitle:NSLocalizedString(@"Promote to Admin", @"Promote to Admin button title")];

		context[@(operatorSheet.numberOfButtons - 1)] = @(MVChatRoomMemberAdministratorMode | (selectedUserIsAdministrator ? (1 << 16) : 0));
	}

	if ((localUserIsOperator || localUserIsAdministrator || localUserIsFounder) && ((localUserIsOperator && !(selectedUserIsAdministrator || selectedUserIsFounder)) || (localUserIsAdministrator && !selectedUserIsFounder) || localUserIsFounder)) {
		if ([features containsObject:MVChatRoomMemberOperatorFeature]) {
			if (selectedUserIsOperator) [operatorSheet addButtonWithTitle:NSLocalizedString(@"Demote from Operator", @"Demote from Operator button title")];
			else [operatorSheet addButtonWithTitle:NSLocalizedString(@"Promote to Operator", @"Promote to Operator button title")];

			context[@(operatorSheet.numberOfButtons - 1)] = @(MVChatRoomMemberOperatorMode | (selectedUserIsOperator ? (1 << 16) : 0));
		}

		if ([features containsObject:MVChatRoomMemberHalfOperatorFeature]) {
			if (selectedUserIsHalfOperator) [operatorSheet addButtonWithTitle:NSLocalizedString(@"Demote from Half-Operator", @"Demote From Half-Operator button title")];
			else [operatorSheet addButtonWithTitle:NSLocalizedString(@"Promote to Half-Operator", @"Promote to Half-Operator button title")];

			context[@(operatorSheet.numberOfButtons - 1)] = @(MVChatRoomMemberHalfOperatorMode | (selectedUserIsHalfOperator ? (1 << 16) : 0));
		}
	}

	if (localUserIsHalfOperator || localUserIsOperator || localUserIsAdministrator || localUserIsFounder) {
		if ([features containsObject:MVChatRoomMemberVoicedFeature] && ((localUserIsHalfOperator && !(selectedUserIsOperator || selectedUserIsAdministrator || selectedUserIsFounder)) || (localUserIsOperator && !(selectedUserIsAdministrator || selectedUserIsFounder)) || (localUserIsAdministrator && !selectedUserIsFounder) || localUserIsFounder)) {
			if (selectedUserHasVoice) [operatorSheet addButtonWithTitle:NSLocalizedString(@"Remove Voice", @"Remove Voice button title")];
			else [operatorSheet addButtonWithTitle:NSLocalizedString(@"Grant Voice", @"Grant Voice button title")];

			context[@(operatorSheet.numberOfButtons - 1)] = @(MVChatRoomMemberVoicedMode | (selectedUserHasVoice ? (1 << 16) : 0));
		}

		if ([features containsObject:MVChatRoomMemberQuietedFeature]) {
			if (selectedUserIsQuieted) [operatorSheet addButtonWithTitle:NSLocalizedString(@"Remove Force Quiet", @"Rmeove Force Quiet button title")];
			else [operatorSheet addButtonWithTitle:NSLocalizedString(@"Force Quiet", @"Force Quiet button title")];

			context[@(operatorSheet.numberOfButtons - 1)] = @(MVChatRoomMemberDisciplineQuietedMode | (selectedUserIsQuieted ? (1 << 16) : 0));
		}
	}

	operatorSheet.cancelButtonIndex = [operatorSheet addButtonWithTitle:NSLocalizedString(@"Cancel", @"Cancel button title")];

	return operatorSheet;
}

#pragma mark -

- (void) actionSheet:(UIActionSheet *) actionSheet clickedButtonAtIndex:(NSInteger) buttonIndex {
	if (buttonIndex == actionSheet.cancelButtonIndex)
		return;

	dispatch_async(dispatch_get_main_queue(), ^{
		MVChatUser *user = [actionSheet associatedObjectForKey:@"user"];
		MVChatRoom *room = [actionSheet associatedObjectForKey:@"room"];

		if (actionSheet.tag == UserActionSheetTag) {
			if (buttonIndex == SendMessageButtonIndex) {
				CQDirectChatController *chatController = [[CQChatOrderingController defaultController] chatViewControllerForUser:user ifExists:NO];
				[[CQChatController defaultController] showChatController:chatController animated:YES];
			} else if (buttonIndex == [self userInfoButtonIndex]) {
				CQUserInfoController *userInfoController = [[CQUserInfoController alloc] init];
				userInfoController.user = user;

				[[CQColloquyApplication sharedApplication] dismissPopoversAnimated:YES];
				[[CQColloquyApplication sharedApplication] presentModalViewController:userInfoController animated:YES];

	#if ENABLE(FILE_TRANSFERS)
			} else if (buttonIndex == [self sendFileButtonIndex]) {
				[[CQChatController defaultController] showFilePickerWithUser:user];
	#endif
			} else if (buttonIndex == [self operatorActionsButtonIndex]) {
				NSUInteger localUserModes = (room.connection.localUser ? [room modesForMemberUser:room.connection.localUser] : 0);
				NSUInteger selectedUserModes = (user ? [room modesForMemberUser:user] : 0);

				UIActionSheet *operatorSheet = [UIActionSheet operatorActionSheetWithLocalUserModes:localUserModes targetingUserWithModes:selectedUserModes disciplineModes:[room disciplineModesForMemberUser:user] onRoomWithFeatures:room.connection.supportedFeatures];
				operatorSheet.delegate = operatorSheet;
				operatorSheet.title = actionSheet.title;

				[operatorSheet associateObject:user forKey:@"user"];
				[operatorSheet associateObject:room forKey:@"room"];

				[[CQColloquyApplication sharedApplication] showActionSheet:operatorSheet forSender:[actionSheet associatedObjectForKey:@"userInfo"] animated:YES];
			} else if (buttonIndex == [self ignoreButtonIndex]) {
				if ([self associatedObjectForKey:@"has-ignore-rule"])
					[room.connection.ignoreController removeIgnoreRuleFromString:user.nickname];
				else [room.connection.ignoreController addIgnoreRule:[KAIgnoreRule ruleForUser:user.nickname mask:nil message:nil inRooms:nil isPermanent:YES friendlyName:nil]];
			}
		} else if (actionSheet.tag == OperatorActionSheetTag) {
			id action = [actionSheet associatedObjectForKey:@"userInfo"][@(buttonIndex)];

			if ([action isKindOfClass:[NSNumber class]]) {
				MVChatRoomMemberMode mode = ([action unsignedIntegerValue] & 0x7FFF);
				BOOL removeMode = (([action unsignedIntegerValue] & (1 << 16)) == (1 << 16));

				if (removeMode) [room removeMode:mode forMemberUser:user];
				else [room setMode:mode forMemberUser:user];
			} else if ([action isEqual:@"ban"]) {
				MVChatUser *wildcardUser = [MVChatUser wildcardUserWithNicknameMask:nil andHostMask:[NSString stringWithFormat:@"*@%@", user.address]];
				[room addBanForUser:wildcardUser];
			} else if ([action isEqual:@"kick"]) {
				[room kickOutMemberUser:user forReason:nil];
			}
		}
	});
}

#pragma mark -

- (NSInteger) userInfoButtonIndex {
	if ([self associatedObjectForKey:@"showing-user-information"] || [[UIDevice currentDevice] isPadModel])
		return 1;
	return NSNotFound;
}

#if ENABLE(FILE_TRANSFERS)
- (NSInteger) sendFileButtonIndex {
	if ([self associatedObjectForKey:@"showing-user-information"] || [[UIDevice currentDevice] isPadModel])
		return 2;
	return 1;
}
#endif

- (NSInteger) ignoreButtonIndex {
	if ([self associatedObjectForKey:@"showing-user-information"] || [[UIDevice currentDevice] isPadModel])
		return 2;
	return 1;
}

- (NSInteger) operatorActionsButtonIndex {
	return [self ignoreButtonIndex] + 1;
}
@end
