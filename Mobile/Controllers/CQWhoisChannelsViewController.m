//
//  CQWhoisChannelsViewController.m
//  Mobile Colloquy
//
//  Created by August Joki on 1/3/09.
//  Copyright 2009 Concinnous Software. All rights reserved.
//

#import "CQWhoisChannelsViewController.h"

#import <ChatCore/MVChatConnection.h>


@implementation CQWhoisChannelsViewController

@synthesize channels = _channels, connection = _connection;

static UIImage *image = nil;

+ (void)initialize;
{
    image = [[UIImage imageNamed:@"roomIconSmall.png"] retain];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView;
{
	return 1;
}


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section;
{
    return _channels.count;
}


- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section;
{
    return NSLocalizedString(@"Rooms", "Rooms whois label");
}


- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath;
{
    return image.size.height + 10.;
}


- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)indexPath;
{
    static NSString *CellIdentifier = @"WhoisChannelIdentifier";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[[UITableViewCell alloc] initWithFrame:CGRectZero reuseIdentifier:CellIdentifier] autorelease];
    }
    
	cell.image = image;
    cell.text = [_channels objectAtIndex:indexPath.row];
    
    return cell;
}


- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath;
{
    UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:@"" delegate:self cancelButtonTitle:NSLocalizedString(@"Cancel", "Cancel button title") destructiveButtonTitle:nil otherButtonTitles:NSLocalizedString(@"Join Room", @"Join Room button title"), nil];
    [sheet showInView:self.view];
    [sheet release];
}


- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex;
{
    NSIndexPath *indexPath = [tableView indexPathForSelectedRow];
    if (buttonIndex != actionSheet.cancelButtonIndex) {
        [_connection joinChatRoomNamed:[_channels objectAtIndex:indexPath.row]];
    }
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}


- (void)setChannels:(NSArray *)chans {
    [chans retain];
    [_channels release];
    _channels = chans;
    
    [tableView reloadData];
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning]; // Releases the view if it doesn't have a superview
    // Release anything that's not essential, such as cached data
}


- (void)dealloc {
    [image release];
	[_channels release];
    [super dealloc];
}


@end
