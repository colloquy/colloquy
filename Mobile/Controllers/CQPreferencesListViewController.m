#import "CQPreferencesListViewController.h"
#import "CQPreferencesListEditViewController.h"
#import "CQPreferencesListChannelEditViewController.h"

@implementation CQPreferencesListViewController
- (id) init {
	if (!(self = [super initWithStyle:UITableViewStyleGrouped]))
		return nil;

	_items = [[NSMutableArray alloc] init];
	_allowEditing = YES;
	_selectedItemIndex = NSNotFound;

	self.navigationItem.rightBarButtonItem = self.editButtonItem;

	self.addItemLabelText = NSLocalizedString(@"Add item", @"Add item label");
	self.noItemsLabelText = NSLocalizedString(@"No items", @"No items label");
	self.editViewTitle = NSLocalizedString(@"Edit", @"Edit view title");

	return self;
}

- (void) dealloc {
	[_items release];
	[_itemImage release];
	[_addItemLabelText release];
	[_noItemsLabelText release];
	[_editViewTitle release];
	[_editPlaceholder release];
	[_editingViewController release];
	[_customEditingViewController release];

	[super dealloc];
}

#pragma mark -

- (void) viewDidLoad {
	[super viewDidLoad];

	self.tableView.allowsSelectionDuringEditing = YES;
}

- (void) viewWillAppear:(BOOL) animated {
	UITableView *tableView = self.tableView;

	if (_editingViewController) {
		NSIndexPath *changedIndexPath = [NSIndexPath indexPathForRow:_editingIndex inSection:0];
		NSArray *changedIndexPaths = [NSArray arrayWithObject:changedIndexPath];

		if (_editingIndex < _items.count) {
			if (_editingViewController.listItemText.length)
				[_items replaceObjectAtIndex:_editingIndex withObject:_editingViewController.listItemText];
			else [_items removeObjectAtIndex:_editingIndex];

			_pendingChanges = YES;

			[tableView updateCellAtIndexPath:changedIndexPath withAnimation:UITableViewRowAnimationFade];
		} else if (_editingViewController.listItemText.length) {
			if (![_items containsObject:_editingViewController.listItemText]) {
				[tableView deselectRowAtIndexPath:[tableView indexPathForSelectedRow] animated:NO];
				[_items insertObject:_editingViewController.listItemText atIndex:_editingIndex];
				_pendingChanges = YES;

				[tableView insertRowsAtIndexPaths:changedIndexPaths withRowAnimation:UITableViewRowAnimationFade];

				[tableView selectRowAtIndexPath:changedIndexPath animated:NO scrollPosition:UITableViewScrollPositionNone];
			}
		}

		[_editingViewController release];
		_editingViewController = nil;
	}

	[super viewWillAppear:animated];

	if (!_items.count && _allowEditing)
		self.editing = YES;
}

- (void) viewWillDisappear:(BOOL) animated {
	[super viewWillDisappear:animated];

	if (_editingViewController || !_pendingChanges || !_action)
		return;

	if (!_target || [_target respondsToSelector:_action])
		if ([[UIApplication sharedApplication] sendAction:_action to:_target from:self forEvent:nil])
			_pendingChanges = NO;
}

#pragma mark -

@synthesize allowEditing = _allowEditing;

- (void) setAllowEditing:(BOOL) allowEditing {
	_allowEditing = allowEditing;

	if (allowEditing) {
		self.navigationItem.rightBarButtonItem = self.editButtonItem;
		_selectedItemIndex = NSNotFound;
	} else {
		self.navigationItem.rightBarButtonItem = nil;
		self.editing = NO;
	}
}

@synthesize selectedItemIndex = _selectedItemIndex;

- (void) setSelectedItemIndex:(NSUInteger) index {
	_selectedItemIndex = (_allowEditing ? NSNotFound : index);
}

@synthesize addItemLabelText = _addItemLabelText;

@synthesize noItemsLabelText = _noItemsLabelText;

@synthesize editViewTitle = _editViewTitle;

@synthesize editPlaceholder = _editPlaceholder;

@synthesize target = _target;

@synthesize action = _action;

@synthesize itemImage = _itemImage;

- (void) setItemImage:(UIImage *) image {
	id old = _itemImage;
	_itemImage = [image retain];
	[old release];

	[self.tableView reloadData];
}

@synthesize items = _items;

- (void) setItems:(NSArray *) items {
	_pendingChanges = NO;

	[_items setArray:items];

	[self.tableView reloadData];
}

@synthesize customEditingViewController = _customEditingViewController;

#pragma mark -

- (void) editItemAtIndex:(NSUInteger) index {
	if (_customEditingViewController)
		_editingViewController = [_customEditingViewController retain];
	else _editingViewController = [[CQPreferencesListEditViewController alloc] init];

	_editingIndex = index;

	_editingViewController.title = _editViewTitle;
	_editingViewController.listItemText = (index < _items.count ? [_items objectAtIndex:index] : @"");
	_editingViewController.listItemPlaceholder = _editPlaceholder;

	[self.navigationController pushViewController:_editingViewController animated:YES];
}

#pragma mark -

- (void) setEditing:(BOOL) editing animated:(BOOL) animated {
	[super setEditing:editing animated:animated];

	if (_items.count) {
		NSArray *indexPaths = [NSArray arrayWithObject:[NSIndexPath indexPathForRow:_items.count inSection:0]];
		if (editing) [self.tableView insertRowsAtIndexPaths:indexPaths withRowAnimation:UITableViewRowAnimationTop];
		else [self.tableView deleteRowsAtIndexPaths:indexPaths withRowAnimation:UITableViewRowAnimationTop];
	} else {
		[self.tableView performSelector:@selector(reloadData) withObject:nil afterDelay:0.25];
	}

	if (!editing && _pendingChanges && _action && (!_target || [_target respondsToSelector:_action]))
		if ([[UIApplication sharedApplication] sendAction:_action to:_target from:self forEvent:nil])
			_pendingChanges = NO;
}

#pragma mark -

- (NSInteger) tableView:(UITableView *) tableView numberOfRowsInSection:(NSInteger) section {
	if (self.editing)
		return (_items.count + 1);
	if (!_items.count)
		return 1;
	return _items.count;
}

- (UITableViewCell *) tableView:(UITableView *) tableView cellForRowAtIndexPath:(NSIndexPath *) indexPath {
	UITableViewCell *cell = [UITableViewCell reusableTableViewCellInTableView:tableView];

	if (indexPath.row < _items.count) {
		cell.textLabel.textColor = [UIColor blackColor];
		cell.textLabel.text = [_items objectAtIndex:indexPath.row];
		cell.imageView.image = _itemImage;
	} else if (self.editing) {
		cell.textLabel.textColor = [UIColor blackColor];
		cell.textLabel.text = _addItemLabelText;
		cell.imageView.image = nil;
	} else {
		cell.textLabel.textColor = [UIColor lightGrayColor];
		cell.textLabel.text = _noItemsLabelText;
		cell.imageView.image = nil;
	}

	if (indexPath.row == _selectedItemIndex)
		cell.textLabel.textColor = [UIColor colorWithRed:(50. / 255.) green:(79. / 255.) blue:(133. / 255.) alpha:1.];
	else cell.textLabel.textColor = [UIColor blackColor];

	if (self.editing)
		cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
	else if (indexPath.row == _selectedItemIndex)
		cell.accessoryType = UITableViewCellAccessoryCheckmark;
	else cell.accessoryType = UITableViewCellAccessoryNone;

	return cell;
}

- (NSIndexPath *) tableView:(UITableView *) tableView willSelectRowAtIndexPath:(NSIndexPath *) indexPath {
	if (self.editing || !_allowEditing)
		return indexPath;
	return nil;
}

- (void) tableView:(UITableView *) tableView didSelectRowAtIndexPath:(NSIndexPath *) indexPath {
	if (_allowEditing) {
		[self editItemAtIndex:indexPath.row];
	} else {
		UITableViewCell *cell = (_selectedItemIndex != NSNotFound ? [tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:_selectedItemIndex inSection:0]] : nil);
		cell.accessoryType = UITableViewCellAccessoryNone;
		cell.textLabel.textColor = [UIColor blackColor];

		_selectedItemIndex = indexPath.row;
		_pendingChanges = YES;

		cell = [tableView cellForRowAtIndexPath:indexPath];
		cell.accessoryType = UITableViewCellAccessoryCheckmark;
		cell.textLabel.textColor = [UIColor colorWithRed:(50. / 255.) green:(79. / 255.) blue:(133. / 255.) alpha:1.];

		[tableView deselectRowAtIndexPath:[tableView indexPathForSelectedRow] animated:YES];
	}
}

- (UITableViewCellEditingStyle) tableView:(UITableView *) tableView editingStyleForRowAtIndexPath:(NSIndexPath *) indexPath {
	if (!self.editing)
		return UITableViewCellEditingStyleNone;

	if (indexPath.row >= _items.count)
		return UITableViewCellEditingStyleInsert;

	return UITableViewCellEditingStyleDelete;
}

- (BOOL) tableView:(UITableView *) tableView canEditRowAtIndexPath:(NSIndexPath *) indexPath {
	return _allowEditing;
}

- (void) tableView:(UITableView *) tableView commitEditingStyle:(UITableViewCellEditingStyle) editingStyle forRowAtIndexPath:(NSIndexPath *) indexPath {
	if (editingStyle == UITableViewCellEditingStyleDelete) {
		[_items removeObjectAtIndex:indexPath.row];
		[tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:YES];
		_pendingChanges = YES;
	} else if (editingStyle == UITableViewCellEditingStyleInsert) {
		[self editItemAtIndex:indexPath.row];
	}
}

- (BOOL) tableView:(UITableView *) tableView canMoveRowAtIndexPath:(NSIndexPath *) indexPath {
	return (indexPath.row < _items.count);
}

- (NSIndexPath *) tableView:(UITableView *) tableView targetIndexPathForMoveFromRowAtIndexPath:(NSIndexPath *) sourceIndexPath toProposedIndexPath:(NSIndexPath *) proposedDestinationIndexPath {
	if (proposedDestinationIndexPath.row >= _items.count)
		return [NSIndexPath indexPathForRow:(_items.count - 1) inSection:0];
	return proposedDestinationIndexPath;
}

- (void) tableView:(UITableView *) tableView moveRowAtIndexPath:(NSIndexPath *) fromIndexPath toIndexPath:(NSIndexPath *) toIndexPath {
	if (toIndexPath.row >= _items.count)
		return;

	id item = [[_items objectAtIndex:fromIndexPath.row] retain];
	[_items removeObject:item];
	[_items insertObject:item atIndex:toIndexPath.row];
	[item release];

	_pendingChanges = YES;
}
@end
