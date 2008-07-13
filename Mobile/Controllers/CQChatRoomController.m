#import "CQChatRoomController.h"

#import <ChatCore/MVChatRoom.h>
#import <ChatCore/MVChatUser.h>

@interface CQChatRoomController (CQChatRoomControllerPrivate)
- (void) _sortMembers;
@end

@implementation CQChatRoomController
- (id) initWithTarget:(id) target {
	if( ! ( self = [super initWithTarget:target] ) )
		return nil;

	_orderedMembers = [[NSMutableArray alloc] initWithCapacity:100];

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( _memberNicknameChanged: ) name:MVChatUserNicknameChangedNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( _memberModeChanged: ) name:MVChatRoomUserModeChangedNotification object:target];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( _membersSynced: ) name:MVChatRoomMemberUsersSyncedNotification object:target];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( _memberJoined: ) name:MVChatRoomUserJoinedNotification object:target];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( _memberParted: ) name:MVChatRoomUserPartedNotification object:target];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( _memberKicked: ) name:MVChatRoomUserKickedNotification object:target];

	return self;
}

- (void) dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];

	[_orderedMembers release];
	[_membersMainView release];
	[_membersNavigationBar release];
	[_membersTable release];
	[_memberInfoTable release];

	[super dealloc];
}

- (MVChatUser *) user {
	return nil;
}

- (MVChatRoom *) room {
	return (MVChatRoom *)_target;
}

- (UIImage *) icon {
	return [UIImage imageNamed:@"roomIcon.png"];
}

- (NSString *) title {
	return [[self room] displayName];
}

- (MVChatConnection *) connection {
	return [[self room] connection];
}

#pragma mark -

- (void) close {
	[[self room] part];
}

#pragma mark -

- (void) joined {
	[_orderedMembers removeAllObjects];
	[_orderedMembers addObjectsFromArray:[[_target memberUsers] allObjects]];

	[self _sortMembers];

	if( _showingMembers )
		[_membersTable reloadData];
}

#pragma mark -

- (void) showMembers {
	if( _showingMembers )
		return;

	if( ! _membersMainView ) {
		CGRect screenRect = [[UIScreen mainScreen] applicationFrame];
		CGRect contentRect = screenRect;

		contentRect.origin.y = 0.;

		_membersMainView = [[UIView alloc] initWithFrame:contentRect];

		_membersNavigationBar = [[UINavigationBar alloc] initWithFrame:CGRectMake(0., 0., screenRect.size.width, 45.)];
		[_membersNavigationBar setDelegate:self];
//		[_membersNavigationBar showLeftButton:nil withStyle:0 rightButton:@"Done" withStyle:3];

		UINavigationItem *item = [[UINavigationItem alloc] initWithTitle:[NSString stringWithFormat:@"%@ Members", self.title]];
		[_membersNavigationBar pushNavigationItem:item animated:YES];
		[item release];

		contentRect.size.height -= 45.;

/*
		_membersTable = [[UITableView alloc] initWithFrame:contentRect style:UITableViewStylePlain];
		[_membersTable setDataSource:self];
		[_membersTable setDelegate:self];
		[_membersTable setRowHeight:40.];
		[_membersTable setSeparatorStyle:1];

		_memberInfoTable = [[UITableView alloc] initWithFrame:contentRect style:UITableViewStyleGrouped];
		[_memberInfoTable setDataSource:self];
		[_memberInfoTable setDelegate:self];

		contentRect.origin.y = 45.;

		_membersTransitionView = [[UITransitionView alloc] initWithFrame:contentRect];
		[_membersTransitionView setDelegate:self];
		[_membersTransitionView addSubview:_membersTable];
		[_membersMainView addSubview:_membersNavigationBar];
		[_membersMainView addSubview:_membersTransitionView];
*/
	}

	_showingMembers = YES;

	if( _needsMembersSorted )
		[self _sortMembers];

	[_membersTable reloadData];

/*
	UIWindow *window = [[CQChatController defaultController] chatsWindow];

	CGRect startFrame = [_membersMainView frame];
	CGRect endFrame = startFrame;

	startFrame.origin.y = startFrame.size.height;
	endFrame.origin.y = 0.;

	UIFrameAnimation *animation = [[UIFrameAnimation alloc] initWithTarget:_membersMainView];
	[animation setStartFrame:startFrame];
	[animation setEndFrame:endFrame];
	[animation setSignificantRectFields:2]; // the y position of the rect
	[animation setAnimationCurve:1]; // ease in

	[_membersMainView setFrame:startFrame];
	[window addSubview:_membersMainView];
	[[UIAnimator sharedAnimator] addAnimation:animation withDuration:0.33 start:YES];

	[animation release];
*/
}

- (void) hideMembers {
	if( ! _showingMembers )
		return;
/*
	CGRect endFrame = [_membersMainView frame];
	endFrame.origin.y = endFrame.size.height;

	UIFrameAnimation *animation = [[UIFrameAnimation alloc] initWithTarget:_membersMainView];
	[animation setStartFrame:[_membersMainView frame]];
	[animation setEndFrame:endFrame];
	[animation setSignificantRectFields:2]; // the y position of the rect
	[animation setAnimationCurve:2]; // ease out
	[animation setDelegate:self];

	[[UIAnimator sharedAnimator] addAnimation:animation withDuration:0.33 start:YES];

	[animation release];
*/
}

#pragma mark -

static int sortMembersByStatus(id user1, id user2, void *context) {
	CQChatRoomController *room = (CQChatRoomController *)context;

	unsigned long user1Status = 0;
	unsigned long user2Status = 0;

	unsigned long modes = [[room target] modesForMemberUser:user1];

	if( [user1 isServerOperator] ) user1Status = 6;
	else if( modes & MVChatRoomMemberFounderMode ) user1Status = 5;
	else if( modes & MVChatRoomMemberAdministratorMode ) user1Status = 4;
	else if( modes & MVChatRoomMemberOperatorMode ) user1Status = 3;
	else if( modes & MVChatRoomMemberHalfOperatorMode ) user1Status = 2;
	else if( modes & MVChatRoomMemberVoicedMode ) user1Status = 1;

	modes = [[room target] modesForMemberUser:user2];

	if( [user2 isServerOperator] ) user2Status = 6;
	else if( modes & MVChatRoomMemberFounderMode ) user2Status = 5;
	else if( modes & MVChatRoomMemberAdministratorMode ) user2Status = 4;
	else if( modes & MVChatRoomMemberOperatorMode ) user2Status = 3;
	else if( modes & MVChatRoomMemberHalfOperatorMode ) user2Status = 2;
	else if( modes & MVChatRoomMemberVoicedMode ) user2Status = 1;

	if( user1Status > user2Status )
		return NSOrderedAscending;
	if( user2Status > user1Status )
		return NSOrderedDescending;

	return [[user1 displayName] caseInsensitiveCompare:[user2 displayName]];
}

static int sortMembersByNickname(id user1, id user2, void *context) {
	return [[user1 displayName] caseInsensitiveCompare:[user2 displayName]];
}

- (void) _sortMembers {
	if( ! _showingMembers ) {
		_needsMembersSorted = YES;
		return;
	}

	_needsMembersSorted = NO;

	if( [[NSUserDefaults standardUserDefaults] boolForKey:@"CQSortRoomMembersByStatus"] )
		[_orderedMembers sortUsingFunction:sortMembersByStatus context:self];
	else [_orderedMembers sortUsingFunction:sortMembersByNickname context:self];
}

- (void) _memberNicknameChanged:(NSNotification *) notification {
	MVChatUser *user = [notification object];
	if( ! [_target hasUser:user] ) return;

	int originalIndex = [_orderedMembers indexOfObjectIdenticalTo:user];
	if( originalIndex == NSNotFound ) return;

	[self _sortMembers];

	if( _showingMembers ) {
		/* int index = [_orderedMembers indexOfObjectIdenticalTo:user];
		if( index != NSNotFound && index == originalIndex )
			[_membersTable reloadCellAtRow:index column:0 animated:YES];
		else */ [_membersTable reloadData];
	}
}

- (void) _memberModeChanged:(NSNotification *) notification {
	MVChatUser *user = [[notification userInfo] objectForKey:@"who"];
	if( ! user ) return;

	int originalIndex = [_orderedMembers indexOfObjectIdenticalTo:user];
	if( originalIndex == NSNotFound ) return;

	[self _sortMembers];

	if( _showingMembers ) {
		/* int index = [_orderedMembers indexOfObjectIdenticalTo:user];
		if( index != NSNotFound && index == originalIndex )
			[_membersTable reloadCellAtRow:index column:0 animated:YES];
		else */[_membersTable reloadData];
	}
}	

- (void) _membersSynced:(NSNotification *) notification {
	NSDictionary *userInfo = [notification userInfo];
	if( userInfo ) {
		NSArray *added = [userInfo objectForKey:@"added"];
		if( added ) {
			for( MVChatUser *user in added ) {
				if( [_orderedMembers indexOfObjectIdenticalTo:user] == NSNotFound )
					[_orderedMembers addObject:user];
			}
		}

		NSArray *removed = [userInfo objectForKey:@"removed"];
		if( removed ) {
			for( MVChatUser *user in removed ) {
				int index = [_orderedMembers indexOfObjectIdenticalTo:user];
				if( index != NSNotFound )
					[_orderedMembers removeObjectAtIndex:index];
			}
		}
	}

	[self _sortMembers];

	if( _showingMembers )
		[_membersTable reloadData];
}

- (void) _memberJoined:(NSNotification *) notification {
	MVChatUser *user = [[notification userInfo] objectForKey:@"user"];

	if( [_orderedMembers indexOfObjectIdenticalTo:user] == NSNotFound ) {
		[_orderedMembers addObject:user];

		[self _sortMembers];

		if( _showingMembers ) {
			int index = [_orderedMembers indexOfObjectIdenticalTo:user];
			if( index != NSNotFound )
				[_membersTable insertRowsAtIndexPaths:[NSArray arrayWithObject:[NSIndexPath indexPathWithIndex:index]] withRowAnimation:UITableViewRowAnimationFade];
			else [_membersTable reloadData];
		}
	}
}

- (void) _memberParted:(NSNotification *) notification {
	MVChatUser *user = [[notification userInfo] objectForKey:@"user"];

	int index = [_orderedMembers indexOfObjectIdenticalTo:user];
	if( index == NSNotFound ) return;

	[_orderedMembers removeObjectAtIndex:index];

	if( _showingMembers )
		[_membersTable deleteRowsAtIndexPaths:[NSArray arrayWithObject:[NSIndexPath indexPathWithIndex:index]] withRowAnimation:UITableViewRowAnimationFade];
}

- (void) _memberKicked:(NSNotification *) notification {
	MVChatUser *user = [[notification userInfo] objectForKey:@"user"];

	int index = [_orderedMembers indexOfObjectIdenticalTo:user];
	if( index == NSNotFound ) return;

	[_orderedMembers removeObjectAtIndex:index];

	if( _showingMembers )
		[_membersTable deleteRowsAtIndexPaths:[NSArray arrayWithObject:[NSIndexPath indexPathWithIndex:index]] withRowAnimation:UITableViewRowAnimationFade];
}

#pragma mark -

/*
- (void) animator:(UIAnimator *) animator stopAnimation:(UIAnimation *) animation {
	[_membersMainView removeFromSuperview];
	_showingMembers = NO;
}
*/

#pragma mark -

/*
- (void) navigationBar:(UINavigationBar *) bar buttonClicked:(int) button {
	if( bar == [[CQChatController defaultController] navigationBar] ) {
		if( button == 0 )
			[self showMembers];
	} else if( bar == _membersNavigationBar ) {
		if( button == 0 )
			[self hideMembers];
	}
}
*/

#pragma mark -

- (int) numberOfRowsInTable:(UITableView *) table {
	return [_orderedMembers count];
}

- (UITableViewCell *) table:(UITableView *) table cellForRow:(int) row column:(int) col {
	MVChatUser *user = [_orderedMembers objectAtIndex:row];

	UITableViewCell *cell = [[UITableViewCell alloc] init];
	[cell setText:[user displayName]];

	unsigned long modes = [_target modesForMemberUser:user];

	if( [user isServerOperator] )
		[cell setImage:[UIImage imageNamed:@"user-super-op.png"]];
	else if( modes & MVChatRoomMemberFounderMode )
		[cell setImage:[UIImage imageNamed:@"user-founder.png"]];
	else if( modes & MVChatRoomMemberAdministratorMode )
		[cell setImage:[UIImage imageNamed:@"user-admin.png"]];
	else if( modes & MVChatRoomMemberOperatorMode )
		[cell setImage:[UIImage imageNamed:@"user-op.png"]];
	else if( modes & MVChatRoomMemberHalfOperatorMode )
		[cell setImage:[UIImage imageNamed:@"user-half-op.png"]];
	else if( modes & MVChatRoomMemberVoicedMode )
		[cell setImage:[UIImage imageNamed:@"user-voice.png"]];
	else [cell setImage:[UIImage imageNamed:@"user-normal.png"]];

	return [cell autorelease];
}

- (BOOL) table:(UITableView *) table canSelectRow:(int) row {
	return NO;
}
@end
