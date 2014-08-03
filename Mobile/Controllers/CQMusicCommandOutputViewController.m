#import "CQMusicCommandOutputViewController.h"
#import "CQPreferencesTextCell.h"

#import <MediaPlayer/MPMediaItem.h>

@implementation CQMusicCommandOutputViewController {
	NSMutableArray *_activeOutput;
	NSMutableArray *_inactiveOutput;
}

- (id) init {
	if (!(self = [super initWithStyle:UITableViewStyleGrouped]))
		return nil;

	_activeOutput = [[[NSUserDefaults standardUserDefaults] objectForKey:@"CQMusicCommandActiveOutput"] mutableCopy];
	if (!_activeOutput) {
		_activeOutput = [@[
			[@{
				@"title": NSLocalizedString(@"is listening to", @"is listening to sentence fragment"),
				@"isCustomizable": @(YES) } mutableCopy],
			[@{
				@"metadata": MPMediaItemPropertyTitle,
				@"title": NSLocalizedString(@"Title", @"Title cell text"), } mutableCopy],
			[@{
				@"title": NSLocalizedString(@"By", @"by sentence fragment"),
				@"isCustomizable": @(YES) } mutableCopy],
			[@{
				@"metadata": MPMediaItemPropertyArtist,
				@"title": NSLocalizedString(@"Artist", @"Artist cell text"), } mutableCopy],
			[@{
				@"title": NSLocalizedString(@"On", @"on sentence fragment"),
				@"isCustomizable": @(YES) } mutableCopy],
			[@{
				@"metadata": MPMediaItemPropertyAlbumTitle,
				@"title": NSLocalizedString(@"Album", @"Album cell text"), } mutableCopy],
		] mutableCopy];
	}

	_inactiveOutput = [[[NSUserDefaults standardUserDefaults] objectForKey:@"CQMusicCommandInactiveOutput"] mutableCopy];
	if (!_inactiveOutput) {
		_inactiveOutput = [@[
			[@{
				@"metadata": MPMediaItemPropertyAlbumTrackNumber,
				@"title": NSLocalizedString(@"Track Number", @"Track Number cell text") } mutableCopy],
			[@{
				@"metadata": MPMediaItemPropertyAlbumTrackCount,
				@"title": NSLocalizedString(@"Tracks On Album", @"Tracks On Album cell text") } mutableCopy],
			[@{
				@"metadata": MPMediaItemPropertyDiscNumber,
				@"title": NSLocalizedString(@"Disc Number", @"Disc Number cell text") } mutableCopy],
			[@{
				@"metadata": MPMediaItemPropertyDiscCount,
				@"title": NSLocalizedString(@"Discs In Album", @"Discs In Album cell text") } mutableCopy],
			[@{
			   @"metadata": MPMediaItemPropertyRating,
			   @"title": NSLocalizedString(@"Rating", @"Rating cell text") } mutableCopy],
		] mutableCopy];

	}
	return self;
}

- (void) viewDidLoad {
	[super viewDidLoad];

	self.tableView.delegate = self;
	self.tableView.dataSource = self;
	self.tableView.editing = YES;

	[self.tableView registerClass:[CQPreferencesTextCell class] forCellReuseIdentifier:@"textCell"];
	[self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"cell"];
}

- (void) viewDidDisappear:(BOOL) animated {
	[super viewDidDisappear:animated];

	[[NSUserDefaults standardUserDefaults] setObject:_activeOutput forKey:@"CQMusicCommandActiveOutput"];
	[[NSUserDefaults standardUserDefaults] setObject:_inactiveOutput forKey:@"CQMusicCommandInactiveOutput"];
}

#pragma mark -

- (NSInteger) numberOfSectionsInTableView:(UITableView *) tableView {
	return 2;
}

- (NSInteger) tableView:(UITableView *) tableView numberOfRowsInSection:(NSInteger) section {
	if (section == 0)
		return _activeOutput.count + 1;
	if (section == 1)
		return _inactiveOutput.count;
	return 0;
}

- (UITableViewCell *) tableView:(UITableView *) tableView cellForRowAtIndexPath:(NSIndexPath *) indexPath {
	NSArray *dataSource = nil;
	if (indexPath.section == 0)
		dataSource = _activeOutput;
	else if (indexPath.section == 1)
		dataSource = _inactiveOutput;
	else NSAssert(NO, @"Bad state when laying out music commands");

	if (indexPath.row >= dataSource.count) {
		UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell"];
		return cell;
	} else if ([dataSource[indexPath.row][@"isCustomizable"] boolValue]) {
		CQPreferencesTextCell *cell = [tableView dequeueReusableCellWithIdentifier:@"textCell"];
		cell.showsReorderControl = YES;
		cell.textField.text = dataSource[indexPath.row][@"title"];
		cell.textFieldBlock = ^(UITextField *textField) {
			dataSource[indexPath.row][@"title"] = textField.text;
		};
		return cell;
	} else {
		UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell"];
		cell.showsReorderControl = YES;
		cell.textLabel.text = dataSource[indexPath.row][@"title"];
		return cell;
	}

	return nil;
}

- (NSString *) tableView:(UITableView *) tableView titleForHeaderInSection:(NSInteger) section {
	if (section == 0)
		return NSLocalizedString(@"In Use", @"In Use section title");
	if (section == 1)
		return NSLocalizedString(@"Unused", @"Unused section title");
	return nil;
}

- (BOOL) tableView:(UITableView *) tableView canMoveRowAtIndexPath:(NSIndexPath *) indexPath {
	return YES;
}

- (void) tableView:(UITableView *) tableView moveRowAtIndexPath:(NSIndexPath *) sourceIndexPath toIndexPath:(NSIndexPath *) destinationIndexPath {
	NSMutableArray *fromDataSource = nil;
	if (sourceIndexPath.section == 0)
		fromDataSource = _activeOutput;
	else if (sourceIndexPath.section == 1)
		fromDataSource = _inactiveOutput;
	else NSAssert(NO, @"Bad state when reordering music commands");

	NSMutableArray *toDataSource = nil;
	if (destinationIndexPath.section == 0)
		toDataSource = _activeOutput;
	else if (destinationIndexPath.section == 1)
		toDataSource = _inactiveOutput;
	else NSAssert(NO, @"Bad state when reordering music commands");

	id moving = fromDataSource[sourceIndexPath.row];
	[fromDataSource removeObjectAtIndex:sourceIndexPath.row];
	[toDataSource insertObject:moving atIndex:destinationIndexPath.row];
}

- (BOOL) tableView:(UITableView *) tableView canEditRowAtIndexPath:(NSIndexPath *) indexPath {
	return YES;
}

- (UITableViewCellEditingStyle) tableView:(UITableView *) tableView editingStyleForRowAtIndexPath:(NSIndexPath *) indexPath {
	NSArray *dataSource = nil;
	if (indexPath.section == 0)
		dataSource = _activeOutput;
	else if (indexPath.section == 1)
		dataSource = _inactiveOutput;
	else NSAssert(NO, @"Bad state when editing out music commands");

	if ([dataSource[indexPath.row][@"isCustomizable"] boolValue])
		return UITableViewCellEditingStyleDelete;
	return UITableViewCellEditingStyleNone;
}

- (void) tableView:(UITableView *) tableView commitEditingStyle:(UITableViewCellEditingStyle) editingStyle forRowAtIndexPath:(NSIndexPath *) indexPath {
	NSMutableArray *dataSource = nil;
	if (indexPath.section == 0)
		dataSource = _activeOutput;
	else if (indexPath.section == 1)
		dataSource = _inactiveOutput;
	else NSAssert(NO, @"Bad state when editing out music commands");

	[dataSource removeObjectAtIndex:indexPath.row];

	[tableView beginUpdates];
	[tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
	[tableView endUpdates];
}
@end
