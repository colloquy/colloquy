#import "CQPreferencesListViewController.h"

@implementation CQPreferencesListViewController
- (id) init {
	if (!(self = [super initWithStyle:UITableViewStyleGrouped]))
		return nil;

	_items = [[NSMutableArray alloc] init];

	self.addItemLabelText = NSLocalizedString(@"Add item", @"Add item label");
	self.noItemsLabelText = NSLocalizedString(@"No items", @"No items label");

	return self;
}

- (void) dealloc {
	[_items release];
	[_itemImage release];
	[_addItemLabelText release];
	[_noItemsLabelText release];
	[super dealloc];
}

#pragma mark -

- (void) viewDidLoad {
	[super viewDidLoad];

	self.tableView.allowsSelectionDuringEditing = YES;
	self.navigationItem.rightBarButtonItem = self.editButtonItem;
}

- (void) viewWillAppear:(BOOL) animated {
	[super viewWillAppear:animated];

	if (!_items.count)
		self.editing = YES;

	[self.tableView reloadData];
}

- (void) viewWillDisappear:(BOOL) animated {
	[super viewWillDisappear:animated];

	[self.tableView endEditing:YES];

	// Workaround a bug were the table view is left in a state
	// were it thinks a keyboard is showing.
	self.tableView.contentInset = UIEdgeInsetsZero;
	self.tableView.scrollIndicatorInsets = UIEdgeInsetsZero;
}

#pragma mark -

@synthesize addItemLabelText = _addItemLabelText;

@synthesize noItemsLabelText = _noItemsLabelText;

@synthesize itemImage = _itemImage;

- (void) setItemImage:(UIImage *) image {
	id old = _itemImage;
	_itemImage = [image retain];
	[old release];

	[self.tableView reloadData];
}

@synthesize items = _items;

- (void) setItems:(NSArray *) items {
	[_items setArray:items];

	[self.tableView reloadData];
}

#pragma mark -

- (void) setEditing:(BOOL) editing animated:(BOOL) animated {
	[super setEditing:editing animated:animated];

	if (_items.count) {
		NSArray *indexPaths = [NSArray arrayWithObject:[NSIndexPath indexPathForRow:_items.count inSection:0]];
		if (editing) [self.tableView insertRowsAtIndexPaths:indexPaths withRowAnimation:UITableViewRowAnimationTop];
		else [self.tableView deleteRowsAtIndexPaths:indexPaths withRowAnimation:UITableViewRowAnimationTop];

		// Workaround a display bug where the cell separator isn't drawn for the new row.
		if (editing) [self.tableView performSelector:@selector(reloadData) withObject:nil afterDelay:0.25];
	} else {
		[self.tableView performSelector:@selector(reloadData) withObject:nil afterDelay:0.25];
	}
}

#pragma mark -

- (NSInteger) tableView:(UITableView *) tableView numberOfRowsInSection:(NSInteger) section {
	if (!self.editing && !_items.count)
		return 1;
	if (self.editing)
		return (_items.count + 1);
	return _items.count;
}

- (UITableViewCell *) tableView:(UITableView *) tableView cellForRowAtIndexPath:(NSIndexPath *) indexPath {
	UITableViewCell *cell = [UITableViewCell reusableTableViewCellInTableView:tableView];

	cell.hidesAccessoryWhenEditing = NO;

	if (indexPath.row < _items.count) {
		cell.textColor = [UIColor blackColor];
		cell.text = [_items objectAtIndex:indexPath.row];
		cell.image = _itemImage;
	} else if (self.editing) {
		cell.textColor = [UIColor blackColor];
		cell.text = _addItemLabelText;
		cell.image = nil;
	} else {
		cell.textColor = [UIColor lightGrayColor];
		cell.text = _noItemsLabelText;
		cell.image = nil;
	}

	return cell;
}

- (NSIndexPath *) tableView:(UITableView *) tableView willSelectRowAtIndexPath:(NSIndexPath *) indexPath {
	if (self.editing)
		return indexPath;
	return nil;
}

- (void) tableView:(UITableView *) tableView didSelectRowAtIndexPath:(NSIndexPath *) indexPath {
	
}

- (UITableViewCellEditingStyle) tableView:(UITableView *) tableView editingStyleForRowAtIndexPath:(NSIndexPath *) indexPath {
	if (!self.editing || !indexPath)
		return UITableViewCellEditingStyleNone;

	if (indexPath.row >= _items.count)
		return UITableViewCellEditingStyleInsert;

	return UITableViewCellEditingStyleDelete;
}

- (BOOL) tableView:(UITableView *) tableView canEditRowAtIndexPath:(NSIndexPath *) indexPath {
	return YES;
}

- (void) tableView:(UITableView *) tableView commitEditingStyle:(UITableViewCellEditingStyle) editingStyle forRowAtIndexPath:(NSIndexPath *) indexPath {
	if (editingStyle == UITableViewCellEditingStyleDelete) {
		[_items removeObjectAtIndex:indexPath.row];
		[tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:YES];
	} else if (editingStyle == UITableViewCellEditingStyleInsert) {
		
	}   
}

- (BOOL) tableView:(UITableView *) tableView canMoveRowAtIndexPath:(NSIndexPath *) indexPath {
	return (indexPath.row < _items.count);
}

- (UITableViewCellAccessoryType) tableView:(UITableView *) tableView accessoryTypeForRowWithIndexPath:(NSIndexPath *) indexPath {
	return (self.editing ? UITableViewCellAccessoryDisclosureIndicator : UITableViewCellAccessoryNone);
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
}
@end

