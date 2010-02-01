#import "CQHelpTopicsViewController.h"

#import "CQColloquyApplication.h"
#import "CQHelpTopicViewController.h"

#import <MediaPlayer/MPMoviePlayerController.h>

static NSString *CQHelpTopicsURLFormatString = @"http://colloquy.mobi/help.php?locale=%@";

@interface CQHelpTopicsViewController (CQHelpTopicsViewControllerPrivate)
- (void) _generateSectionsFromHelpContent:(NSArray *) help;
@end

#pragma mark -

@implementation CQHelpTopicsViewController
- (id) init {
	if (!(self = [super initWithStyle:UITableViewStyleGrouped]))
		return nil;

	self.title = NSLocalizedString(@"Help", @"Help view title");

	[self loadHelpContent];

	return self;
}

- (void) dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];

	self.tableView.dataSource = nil;
	self.tableView.delegate = nil;

	[_helpSections release];
	[_helpData release];
	[_moviePlayer release];

	[super dealloc];
}

#pragma mark -

- (void) loadHelpContent {
	if (_loading)
		return;

	_loading = YES;

	id old = _helpData;
	_helpData = [[NSMutableData alloc] initWithCapacity:4096];
	[old release];

	NSString *urlString = [NSString stringWithFormat:CQHelpTopicsURLFormatString, [[NSLocale autoupdatingCurrentLocale] localeIdentifier]];
	NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:urlString] cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:15.];
	[NSURLConnection connectionWithRequest:request delegate:self];
}

- (void) loadDefaultHelpContent {
	NSArray *help = [NSArray arrayWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"Help" ofType:@"plist"]];

	[self _generateSectionsFromHelpContent:help];
}

#pragma mark -

- (void) connection:(NSURLConnection *) connection didReceiveData:(NSData *) data {
	[_helpData appendData:data];
}

- (void) connectionDidFinishLoading:(NSURLConnection *) connection {
	_loading = NO;

	NSArray *help = [NSPropertyListSerialization propertyListFromData:_helpData mutabilityOption:NSPropertyListImmutable format:NULL errorDescription:NULL];

	[_helpData release];
	_helpData = nil;

	if (help.count)
		[self _generateSectionsFromHelpContent:help];
	else [self loadDefaultHelpContent];
}

- (void) connection:(NSURLConnection *) connection didFailWithError:(NSError *) error {
	_loading = NO;

	[_helpData release];
	_helpData = nil;

	[self loadDefaultHelpContent];
}

#pragma mark -

- (NSInteger) numberOfSectionsInTableView:(UITableView *) tableView {
    return (_helpSections.count ? _helpSections.count : 1);
}

- (NSInteger) tableView:(UITableView *) tableView numberOfRowsInSection:(NSInteger) section {
	if (!_helpSections.count)
		return 1;
	return ((NSArray *)[_helpSections objectAtIndex:section]).count;
}

- (NSString *) tableView:(UITableView *) tableView titleForHeaderInSection:(NSInteger) section {
	if (_helpSections.count) {
		NSArray *sectionItems = [_helpSections objectAtIndex:section];
		NSDictionary *info = [sectionItems objectAtIndex:0];
		return [info objectForKey:@"SectionHeader"];
	}

	return nil;
}

- (NSString *) tableView:(UITableView *) tableView titleForFooterInSection:(NSInteger) section {
	if (_helpSections.count) {
		NSArray *sectionItems = [_helpSections objectAtIndex:section];
		NSDictionary *info = [sectionItems lastObject];
		return [info objectForKey:@"SectionFooter"];
	}

	return nil;
}

- (UITableViewCell *) tableView:(UITableView *) tableView cellForRowAtIndexPath:(NSIndexPath *) indexPath {
	if (!_helpSections.count) {
		UITableViewCell *cell = [UITableViewCell reusableTableViewCellInTableView:tableView withIdentifier:@"Updating"];

		cell.textLabel.text = NSLocalizedString(@"Updating Help Topics...", @"Updating help topics label");
		cell.selectionStyle = UITableViewCellSelectionStyleNone;

		UIActivityIndicatorView *spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
		[spinner startAnimating];

		cell.accessoryView = spinner;

		[spinner release];

		return cell;
	}

	UITableViewCell *cell = [UITableViewCell reusableTableViewCellInTableView:tableView];

	NSArray *sectionItems = [_helpSections objectAtIndex:indexPath.section];
	NSDictionary *info = [sectionItems objectAtIndex:indexPath.row];

	cell.textLabel.text = [info objectForKey:@"Title"];

	if ([info objectForKey:@"Content"]) {
		cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
		cell.accessoryView = nil;
	} else if ([info objectForKey:@"Screencast"]) {
		UIImageView *imageView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"screencast.png"] highlightedImage:[UIImage imageNamed:@"screencastSelected.png"]];
		cell.accessoryView = imageView;
		[imageView release];
	} else if ([info objectForKey:@"Link"]) {
		UIImageView *imageView = nil;
		NSURL *url = [NSURL URLWithString:[info objectForKey:@"Link"]];
		if ([[CQColloquyApplication sharedApplication].handledURLSchemes containsObject:[url.scheme lowercaseString]])
			imageView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"chatBubble.png"] highlightedImage:[UIImage imageNamed:@"chatBubbleSelected.png"]];		
		else imageView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"web.png"] highlightedImage:[UIImage imageNamed:@"webSelected.png"]];		
		cell.accessoryView = imageView;
		[imageView release];
	}

    return cell;
}

- (NSIndexPath *) tableView:(UITableView *)tableView willSelectRowAtIndexPath:(NSIndexPath *) indexPath {
	if (!_helpSections.count)
		return nil;
	return indexPath;
}

- (void) tableView:(UITableView *) tableView didSelectRowAtIndexPath:(NSIndexPath *) indexPath {
	if (!_helpSections.count)
		return;

	NSArray *sectionItems = [_helpSections objectAtIndex:indexPath.section];
	NSDictionary *info = [sectionItems objectAtIndex:indexPath.row];

	if ([info objectForKey:@"Content"]) {
		CQHelpTopicViewController *helpTopicController = [[CQHelpTopicViewController alloc] initWithHTMLContent:[info objectForKey:@"Content"]];
		helpTopicController.navigationItem.rightBarButtonItem = self.navigationItem.rightBarButtonItem;
		helpTopicController.title = [info objectForKey:@"Title"];

		[self.navigationController pushViewController:helpTopicController animated:YES];

		[helpTopicController release];
	} else if ([info objectForKey:@"Screencast"]) {
		[[NSNotificationCenter defaultCenter] removeObserver:self name:MPMoviePlayerPlaybackDidFinishNotification object:_moviePlayer];

		[_moviePlayer release];
		_moviePlayer = nil;

		@try {
			_moviePlayer = [[MPMoviePlayerController alloc] initWithContentURL:[NSURL URLWithString:[info objectForKey:@"Screencast"]]];
			_moviePlayer.movieControlMode = MPMovieControlModeDefault;
			_moviePlayer.scalingMode = MPMovieScalingModeAspectFit;

			[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_screencastDidFinishPlaying) name:MPMoviePlayerPlaybackDidFinishNotification object:_moviePlayer];

			[_moviePlayer play];
		} @catch (NSException *exception) {
			[tableView deselectRowAtIndexPath:[tableView indexPathForSelectedRow] animated:YES];

			[[NSNotificationCenter defaultCenter] removeObserver:self name:MPMoviePlayerPlaybackDidFinishNotification object:_moviePlayer];

			[_moviePlayer release];
			_moviePlayer = nil;
		}
	} else if ([info objectForKey:@"Link"]) {
		NSURL *url = [NSURL URLWithString:[info objectForKey:@"Link"]];

		if ([[NSUserDefaults standardUserDefaults] boolForKey:@"CQDisableBuiltInBrowser"] && url) {
			[[UIApplication sharedApplication] openURL:url];
		} else if (url) {
			[tableView deselectRowAtIndexPath:[tableView indexPathForSelectedRow] animated:YES];

			[self dismissModalViewControllerAnimated:YES];

			[[UIApplication sharedApplication] performSelector:@selector(openURL:) withObject:url afterDelay:0.5];			
		} else {
			[tableView deselectRowAtIndexPath:[tableView indexPathForSelectedRow] animated:YES];
		}
	} else {
		[tableView deselectRowAtIndexPath:[tableView indexPathForSelectedRow] animated:YES];
	}
}

#pragma mark -

- (void) _screencastDidFinishPlaying {
	[[NSNotificationCenter defaultCenter] removeObserver:self name:MPMoviePlayerPlaybackDidFinishNotification object:_moviePlayer];

	[_moviePlayer stop];
	[_moviePlayer release];
	_moviePlayer = nil;

	[self.tableView deselectRowAtIndexPath:[self.tableView indexPathForSelectedRow] animated:YES];
}

- (void) _generateSectionsFromHelpContent:(NSArray *) help {
	id old = _helpSections;
	_helpSections = [[NSMutableArray alloc] initWithCapacity:5];
	[old release];

	NSUInteger i = 0;
	NSUInteger sectionStart = 0;

	for (id item in help) {
		if ([item isKindOfClass:[NSString class]] && [item isEqualToString:@"Space"]) {
			if (i == sectionStart)
				continue;

			NSArray *section = [help subarrayWithRange:NSMakeRange(sectionStart, (i - sectionStart))];
			[_helpSections addObject:section];

			sectionStart = (i + 1);
		}

		++i;
	}

	if (i != sectionStart) {
		NSArray *section = [help subarrayWithRange:NSMakeRange(sectionStart, (i - sectionStart))];
		[_helpSections addObject:section];
	}

	[self.tableView reloadData];
}
@end
