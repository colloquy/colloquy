//
//  CQWhoisViewController.m
//  Mobile Colloquy
//
//  Created by August Joki on 1/3/09.
//  Copyright 2009 Concinnous Software. All rights reserved.
//



#import "CQWhoisViewController.h"
#import "CQPreferencesTextCell.h"
#import "CQWhoisChannelsViewController.h"

#import <ChatCore/MVChatUser.h>
#import <ChatCore/MVChatConnection.h>


@implementation CQWhoisViewController

@synthesize user = _user;

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView;
{
	return 4;
}


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section;
{
	NSInteger rows = 0;
	switch (section) {
		case 0:
			rows = 2;
			break;
		case 1:
			rows = 4;
			break;
		case 2:
			rows = 2;
			break;
		case 3:
			rows = 2;
			break;
		default:
			break;
	}
	return rows;
}


- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)indexPath;
{
	CQPreferencesTextCell *cell = [CQPreferencesTextCell reusableTableViewCellInTableView:tableView];
	cell.textField.enabled = NO;
	
	NSInteger section = indexPath.section;
	NSInteger row = indexPath.row;
	NSString *na = NSLocalizedString( @"n/a", "not applicable or not available");
	if (section == 0) {
		if (row == 0) { // Class
			cell.label = NSLocalizedString(@"Class", "Class whois label");
			NSString *value;
			if( [_user isIdentified] ) {
				value = NSLocalizedString( @"Registered user", "registered user class");
			} else if( [_user isServerOperator] ) {
				value = NSLocalizedString( @"Server operator", "server operator class");
			} else {
				value = NSLocalizedString( @"Normal user", "normal user class");
			}
			cell.text = value;
		}
		else if (row == 1) { // Away Info
			cell.label = NSLocalizedString(@"Away Info", "Away Info whois label");
			NSString *value = [[NSString alloc] initWithData:_user.awayStatusMessage encoding:_user.connection.encoding];
			cell.text = (value) ? value : na;
		}
	}
	else if (section == 1) {
		if (row == 0) { // IP Address
			cell.label = NSLocalizedString(@"IP Address", "IP Address whois label");
			cell.text = (address) ? address : na;
		}
		else if (row == 1) { // Hostname
			cell.label = NSLocalizedString(@"Hostname", "Hostname whois label");
			cell.text = (_user.address) ? _user.address : na;
		}
		else if (row == 2) { // Username
			cell.label = NSLocalizedString(@"Username", "Username whois label");
			cell.text = (_user.username) ? _user.username : na;
		}
		else if (row == 3) { // Real Name
			cell.label = NSLocalizedString(@"Real Name", "Real Name whois label");
			cell.text = (_user.realName) ? _user.realName : na;
		}
	}
	else if (section == 2) {
		if (row == 0) { // Server
			cell.label = NSLocalizedString(@"Server", "Server whois label");
			cell.text = (_user.serverAddress) ? _user.serverAddress : na;
		}
		else if (row == 1) { // Channels
			cell.label = NSLocalizedString(@"Rooms", "Rooms whois label");
			NSString *chans = [[_user attributeForKey:MVChatUserKnownRoomsAttribute] componentsJoinedByString:NSLocalizedString( @", ", "channel list separator")];
			cell.text = (chans) ? chans : na;
			cell.accessoryType = UITableViewCellAccessoryDetailDisclosureButton;
			cell.accessoryAction = @selector(channels);
			cell.target = self;
		}
	}
	else if (section == 3) {
		if (row == 0) {// Connected
			cell.label = NSLocalizedString(@"Connected", "Connected whois label");
			
			NSTimeInterval interval = [_user.dateConnected timeIntervalSinceNow];
			unsigned absoluteInterval = ABS(interval);
			unsigned seconds = (absoluteInterval % 60);
			unsigned minutes = ((absoluteInterval / 60) % 60);
			unsigned hours = (absoluteInterval / 3600);
			
			NSString *newTime;
			if (hours) {
				newTime = [[NSString alloc] initWithFormat:@"%s%d:%02d:%02d", (interval >= 1. ? "-" : ""), hours, minutes, seconds];
			}
			else {
				newTime = [[NSString alloc] initWithFormat:@"%s%d:%02d", (interval >= 1. ? "-" : ""), minutes, seconds];
			}
			
			cell.text = ([_user status] != MVChatUserOfflineStatus) ? newTime : NSLocalizedString( @"offline", "offline, not connected");
		}
		else if (row == 1) { // Idle Time
			cell.label = NSLocalizedString(@"Idle Time", "Idle Time whois label");
			
			NSTimeInterval interval = _user.idleTime;
			unsigned absoluteInterval = ABS(interval);
			unsigned seconds = (absoluteInterval % 60);
			unsigned minutes = ((absoluteInterval / 60) % 60);
			unsigned hours = (absoluteInterval / 3600);
			
			NSString *newTime;
			if (hours) {
				newTime = [[NSString alloc] initWithFormat:@"%d:%02d:%02d", hours, minutes, seconds];
			}
			else {
				newTime = [[NSString alloc] initWithFormat:@"%d:%02d", minutes, seconds];
			}
			
			cell.text = (_user.status != MVChatUserOfflineStatus) ? newTime : NSLocalizedString(@"offline", "offline, not connected");
		}
	}
	return cell;
}


- (void)channels;
{
	CQWhoisChannelsViewController *channelsController = [[CQWhoisChannelsViewController alloc] initWithNibName:@"WhoisChannelsView" bundle:nil];
	channelsController.channels = [_user attributeForKey:MVChatUserKnownRoomsAttribute];
	channelsController.connection = _user.connection;
	channelsController.navigationItem.title = self.navigationItem.title;
	[self.navigationController pushViewController:channelsController animated:YES];
	[channelsController release];
}


- (void) gotAddress:(NSString *) ip;
{
	address = ip ? ip : NSLocalizedString( @"n/a", "not applicable or not available" );
	_addressResolved = YES;
	[tableView reloadData];
}


- (oneway void) lookupAddress;
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	//NSString *ip = [[NSHost hostWithName:[_user address]] address];
	/*
	 * Need to find the proper way to resolve hosts on the iphone
	 *
	CFHostRef host = CFHostCreateWithName(NULL, (CFStringRef)_user.address);
	CFStreamError error;
	BOOL success = CFHostStartInfoResolution(host, kCFHostAddresses, &error);
	NSString *ip;
	if (success) {
		CFArrayRef *addressing = CFHostGetAddressing(host, NULL);
		if (addressing != NULL && CFArrayGetCount(addressing) != 0) {
			CFDateRef data = CFArrayGetValueAtIndex(addressing, 0);
			struct sockaddr_in *addr = CFDataGetBytePtr(data);
			const char *str = inet_ntoa(addr.sin_addr);
			ip = [NSString stringWithUTF8String:str];
		}
		else {
			ip = nil;
		}
	}
	else {
		ip = nil;
	}
	[self performSelectorOnMainThread:@selector(gotAddress:) withObject:ip waitUntilDone:YES];
	*/
	[pool release];
}


- (void)_gotWhois:(NSNotification *) notification;
{
	self.navigationItem.title = _user.nickname;
	
	if (!_addressResolved) {
		[NSThread detachNewThreadSelector:@selector(lookupAddress) toTarget:self withObject:nil];
	}
	[tableView reloadData];
}


- (void)_attributeUpdated:(NSNotification *)notification;
{
	[tableView reloadData];
}


- (IBAction)refreshButtonPressed:(UIBarButtonItem*)sender;
{
	[_user.connection sendRawMessageWithFormat:@"WHOIS %@ %@", _user.nickname, _user.nickname];
}


- (void)setUser:(MVChatUser *)usr;
{
	[usr retain];
	[_user release];
	_user = usr;
	
	_addressResolved = NO;
	address = nil;
	
	if (_user != nil) {
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_attributeUpdated:) name:MVChatUserAttributeUpdatedNotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_gotWhois:) name:MVChatUserInformationUpdatedNotification object:nil];
		[_user.connection sendRawMessageWithFormat:@"WHOIS %@ %@", _user.nickname, _user.nickname];
	}
	else {
		[[NSNotificationCenter defaultCenter] removeObserver:self name:MVChatUserAttributeUpdatedNotification object:nil];
		[[NSNotificationCenter defaultCenter] removeObserver:self name:MVChatUserInformationUpdatedNotification object:nil];
	}

	
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning]; // Releases the view if it doesn't have a superview
    // Release anything that's not essential, such as cached data
}


- (void)dealloc {
    [super dealloc];
}


@end
