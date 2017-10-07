#import "CQHelpTopicsViewController.h"

#import "CQColloquyApplication.h"
#import "CQHelpTopicViewController.h"

NS_ASSUME_NONNULL_BEGIN

static NSString *CQHelpTopicsURLFormatString = @"http://colloquy.mobi/help.php?locale=%@";

@implementation CQHelpTopicsViewController {
	NSMutableArray *_helpSections;
	BOOL _loading;
}

- (instancetype) init {
	if (!(self = [super initWithStyle:UITableViewStyleGrouped]))
		return nil;

	self.title = NSLocalizedString(@"Help", @"Help view title");

	[self loadHelpContent];

	return self;
}

- (void) dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark -

- (void) loadHelpContent {
	if (_loading)
		return;

	_loading = YES;

	NSString *urlString = [NSString stringWithFormat:CQHelpTopicsURLFormatString, [[NSLocale autoupdatingCurrentLocale] localeIdentifier]];
	NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:urlString] cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:15.];
	[[[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
		_loading = NO;

		dispatch_async(dispatch_get_main_queue(), ^{
			NSArray *help = data.length ? [NSPropertyListSerialization propertyListWithData:data options:NSPropertyListImmutable format:NULL error:NULL] : nil;
			if (help.count)
				[self _generateSectionsFromHelpContent:help];
			else [self loadDefaultHelpContent];
		});
	}] resume];
}

- (void) loadDefaultHelpContent {
	NSArray *help = [NSArray arrayWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"Help" ofType:@"plist"]];

	[self _generateSectionsFromHelpContent:help];
}

#pragma mark -

- (NSInteger) numberOfSectionsInTableView:(UITableView *) tableView {
	return (_helpSections.count ? _helpSections.count : 1);
}

- (NSInteger) tableView:(UITableView *) tableView numberOfRowsInSection:(NSInteger) section {
	if (!_helpSections.count)
		return 1;
	return ((NSArray *)_helpSections[section]).count;
}

- (NSString *__nullable) tableView:(UITableView *) tableView titleForHeaderInSection:(NSInteger) section {
	if (_helpSections.count) {
		NSArray *sectionItems = _helpSections[section];
		NSDictionary *info = sectionItems[0];
		return info[@"SectionHeader"];
	}

	return nil;
}

- (NSString *__nullable) tableView:(UITableView *) tableView titleForFooterInSection:(NSInteger) section {
	if (_helpSections.count) {
		NSArray *sectionItems = _helpSections[section];
		NSDictionary *info = [sectionItems lastObject];
		return info[@"SectionFooter"];
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

		return cell;
	}

	UITableViewCell *cell = [UITableViewCell reusableTableViewCellInTableView:tableView];

	NSArray *sectionItems = _helpSections[indexPath.section];
	NSDictionary *info = sectionItems[indexPath.row];

	cell.textLabel.text = info[@"Title"];

	if (info[@"Content"]) {
		cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
		cell.accessoryView = nil;
	} else if (info[@"Link"]) {
		UIImageView *imageView = nil;
		NSURL *url = [NSURL URLWithString:info[@"Link"]];
		if ([[CQColloquyApplication sharedApplication].handledURLSchemes containsObject:[url.scheme lowercaseString]])
			imageView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"chatBubble.png"] highlightedImage:[UIImage imageNamed:@"chatBubbleSelected.png"]];		
		else imageView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"web.png"] highlightedImage:[UIImage imageNamed:@"webSelected.png"]];		
		cell.accessoryView = imageView;
	}

	return cell;
}

- (NSIndexPath *__nullable) tableView:(UITableView *)tableView willSelectRowAtIndexPath:(NSIndexPath *) indexPath {
	if (!_helpSections.count)
		return nil;
	return indexPath;
}

- (void) tableView:(UITableView *) tableView didSelectRowAtIndexPath:(NSIndexPath *) indexPath {
	if (!_helpSections.count)
		return;

	NSArray *sectionItems = _helpSections[indexPath.section];
	NSDictionary *info = sectionItems[indexPath.row];

	if (info[@"Content"]) {
		CQHelpTopicViewController *helpTopicController = [[CQHelpTopicViewController alloc] initWithHTMLContent:info[@"Content"]];
		helpTopicController.navigationItem.rightBarButtonItem = self.navigationItem.rightBarButtonItem;
		helpTopicController.title = info[@"Title"];

		[self.navigationController pushViewController:helpTopicController animated:YES];
	} else if (info[@"Link"]) {
		NSURL *url = [NSURL URLWithString:info[@"Link"]];

		if (url) {
			[[UIApplication sharedApplication] openURL:url];
		} else {
			[tableView deselectRowAtIndexPath:[tableView indexPathForSelectedRow] animated:YES];
		}
	} else {
		[tableView deselectRowAtIndexPath:[tableView indexPathForSelectedRow] animated:YES];
	}
}

#pragma mark -

- (void) _generateSectionsFromHelpContent:(NSArray *) help {
	_helpSections = [[NSMutableArray alloc] initWithCapacity:5];

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

NS_ASSUME_NONNULL_END
