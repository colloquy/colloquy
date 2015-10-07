#import "CQPreferencesListViewController.h"

#import "CQPreferencesListChannelEditViewController.h"
#import "CQPreferencesTextViewController.h"

#import "UIFontAdditions.h"

#import <AVFoundation/AVFoundation.h>

enum {
	CQTableViewCellAccessoryPlay = (UITableViewCellAccessoryCheckmark + 10)
};

NS_ASSUME_NONNULL_BEGIN

@implementation CQPreferencesListViewController {
	NSMutableArray *_items;
	UIImage *_itemImage;
	NSString *_addItemLabelText;
	NSString *_noItemsLabelText;
	NSString *_editViewTitle;
	NSString *_editPlaceholder;
	NSString *_footerText;
	NSUInteger _editingIndex;
	NSInteger _selectedItemIndex;
	CQPreferencesListEditViewController *_editingViewController;
	id _customEditingViewController;
	id __weak _target;
	SEL _action;
	CQPreferencesListBlock _preferencesListBlock;
	BOOL _pendingChanges;
	BOOL _allowEditing;

	CQPreferencesListType _listType;

	AVAudioPlayer *_audioPlayer;
}

- (instancetype) init {
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

#pragma mark -

- (void) viewDidLoad {
	[super viewDidLoad];

	self.tableView.allowsSelectionDuringEditing = YES;
}

- (void) viewWillAppear:(BOOL) animated {
	UITableView *tableView = self.tableView;

	if (_editingViewController) {
		NSIndexPath *changedIndexPath = [NSIndexPath indexPathForRow:_editingIndex inSection:0];
		NSArray *changedIndexPaths = @[changedIndexPath];

#define validListItem(item) \
	(([item isKindOfClass:[NSString class]] && [item length]) || (item && ![item isKindOfClass:[NSString class]]))
		if (_editingIndex < _items.count) {
			if (validListItem(_editingViewController.listItem)) {
				_items[_editingIndex] = _editingViewController.listItem;

				[tableView updateCellAtIndexPath:changedIndexPath withAnimation:UITableViewRowAnimationFade];
			} else {
				[_items removeObjectAtIndex:_editingIndex];
				[tableView deleteRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:_editingIndex inSection:0]] withRowAnimation:UITableViewRowAnimationFade];
			}

			_pendingChanges = YES;
		} else if (validListItem(_editingViewController.listItem)) {
			if (![_items containsObject:_editingViewController.listItem]) {
				[tableView deselectRowAtIndexPath:[tableView indexPathForSelectedRow] animated:NO];
				[_items insertObject:_editingViewController.listItem atIndex:_editingIndex];
				_pendingChanges = YES;

				[tableView insertRowsAtIndexPaths:changedIndexPaths withRowAnimation:UITableViewRowAnimationFade];

				[tableView selectRowAtIndexPath:changedIndexPath animated:NO scrollPosition:UITableViewScrollPositionNone];
			}
		}
#undef validListItem

		_editingViewController = nil;
	}

	[super viewWillAppear:animated];

	if (!_items.count && _allowEditing)
		self.editing = YES;
}

- (void) viewWillDisappear:(BOOL) animated {
	[super viewWillDisappear:animated];

	if (_editingViewController || !_pendingChanges || (!_action && !self.preferencesListBlock))
		return;

	__strong __typeof__((_target)) strongTarget = _target;
	if (!strongTarget || [strongTarget respondsToSelector:_action])
		if ([[UIApplication sharedApplication] sendAction:_action to:strongTarget from:self forEvent:nil])
			_pendingChanges = NO;

	if (self.preferencesListBlock) {
		self.preferencesListBlock(self);
		_pendingChanges = NO;
	}
}

#pragma mark -

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

- (void) setSelectedItemIndex:(NSInteger) index {
	_selectedItemIndex = (_allowEditing ? NSNotFound : index);
}

- (void) setItemImage:(UIImage *) image {
	_itemImage = image;

	[self.tableView reloadData];
}

- (void) setItems:(NSArray *) items {
	_pendingChanges = NO;

	[_items setArray:items];

	[self.tableView reloadData];
}

#pragma mark -

- (int) accessoryTypeForIndexPath:(NSIndexPath *) indexPath allowingForSelection:(BOOL) allowingForSelection {
	if (allowingForSelection && indexPath.row == _selectedItemIndex)
		return UITableViewCellAccessoryCheckmark;

	if ((NSUInteger)indexPath.row >= _items.count)
		return UITableViewCellAccessoryNone;

	NSString *item = _items[indexPath.row];
	if (_listType == CQPreferencesListTypeAudio) {
		NSString *path = [[NSBundle mainBundle] pathForResource:item ofType:@"aiff"];
		if (path.length)
			return CQTableViewCellAccessoryPlay;
	} else if (_listType == CQPreferencesListTypeImage) {
		NSString *path = [[NSBundle mainBundle] pathForResource:item ofType:@"aiff"];
		if (path.length)
			return UITableViewCellAccessoryDetailDisclosureButton;
	} else {
		NSString *license = self.details[indexPath.row];
		if (license.length)
			return UITableViewCellAccessoryDetailDisclosureButton;
	}

	return UITableViewCellAccessoryNone;
}

- (UIView *) accessoryViewForAccessoryType:(int) accessoryType {
	if (accessoryType != CQTableViewCellAccessoryPlay)
		return nil;

	UIImageView *imageView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"playAudioAccessory.png"] highlightedImage:[UIImage imageNamed:@"playAudioAccessory-pressed.png"]];
	imageView.userInteractionEnabled = YES;

	UITapGestureRecognizer *tapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(customAccessoryViewTapped:)];
	[imageView addGestureRecognizer:tapGestureRecognizer];

	return imageView;
}

- (UITableViewCellAccessoryType) accessoryTypeForIndexPath:(NSIndexPath *) indexPath {
	return [self accessoryTypeForIndexPath:indexPath allowingForSelection:YES];
}

#pragma mark -

- (void) customAccessoryViewTapped:(UITapGestureRecognizer *) tapGesturRecognizer {
	CGPoint point = [tapGesturRecognizer locationInView:tapGesturRecognizer.view];
	point = [tapGesturRecognizer.view convertPoint:point toView:self.tableView];

	NSIndexPath *indexPath = [self.tableView indexPathForRowAtPoint:point];
	id <UITableViewDelegate> delegate = self.tableView.delegate;
	if ([delegate respondsToSelector:@selector(tableView:accessoryButtonTappedForRowWithIndexPath:)])
		[delegate tableView:self.tableView accessoryButtonTappedForRowWithIndexPath:indexPath];
}

#pragma mark -

- (void) editItemAtIndex:(NSUInteger) index {
	if (_customEditingViewController)
		_editingViewController = _customEditingViewController;
	else _editingViewController = [[CQPreferencesListEditViewController alloc] init];

	_editingIndex = index;

	_editingViewController.title = _editViewTitle;
	_editingViewController.listItem = (index < _items.count ? _items[index] : @"");
	_editingViewController.listItemPlaceholder = _editPlaceholder;

	[self.navigationController pushViewController:_editingViewController animated:YES];
}

#pragma mark -

- (void) setEditing:(BOOL) editing animated:(BOOL) animated {
	[super setEditing:editing animated:animated];

	if (_items.count) {
		NSArray *indexPaths = @[[NSIndexPath indexPathForRow:_items.count inSection:0]];
		if (editing) [self.tableView insertRowsAtIndexPaths:indexPaths withRowAnimation:UITableViewRowAnimationTop];
		else [self.tableView deleteRowsAtIndexPaths:indexPaths withRowAnimation:UITableViewRowAnimationTop];
	} else {
		[self.tableView performSelector:@selector(reloadData) withObject:nil afterDelay:0.25];
	}

	__strong __typeof__((_target)) strongTarget = _target;
	if (!editing && _pendingChanges && _action && (!strongTarget || [strongTarget respondsToSelector:_action]))
		if ([[UIApplication sharedApplication] sendAction:_action to:strongTarget from:self forEvent:nil])
			_pendingChanges = NO;

	if (self.preferencesListBlock) {
		self.preferencesListBlock(self);
		_pendingChanges = NO;
	}
}

#pragma mark -

- (NSInteger) tableView:(UITableView *) tableView numberOfRowsInSection:(NSInteger) section {
	if (self.editing)
		return (_items.count + 1);
	if (!_items.count)
		return 1;
	return _items.count;
}

- (NSString *__nullable) tableView:(UITableView *) tableView titleForFooterInSection:(NSInteger) section {
	return _footerText;
}

- (UITableViewCell *) tableView:(UITableView *) tableView cellForRowAtIndexPath:(NSIndexPath *) indexPath {
	UITableViewCell *cell = [UITableViewCell reusableTableViewCellInTableView:tableView];

	if (indexPath.row < (NSInteger)_items.count) {
		cell.textLabel.textColor = [UIColor blackColor];
		id item = _items[indexPath.row];
		if ([item isKindOfClass:[NSString class]])
			cell.textLabel.text = item;
		else cell.textLabel.text = [item description];
		cell.imageView.image = _itemImage;
	} else if (self.editing) {
		cell.selectionStyle = UITableViewCellSelectionStyleBlue;
		cell.textLabel.textColor = [UIColor blackColor];
		cell.textLabel.text = _addItemLabelText;
		cell.imageView.image = nil;
	} else {
		cell.selectionStyle = UITableViewCellSelectionStyleNone;
		cell.textLabel.text = _noItemsLabelText;
		cell.imageView.image = nil;
	}

	if (_listType == CQPreferencesListTypeFont) {
		UIFont *font = [UIFont fontWithName:cell.textLabel.text size:cell.textLabel.font.pointSize];
		if (font) cell.textLabel.font = font;
		else cell.textLabel.font = [UIFont systemFontOfSize:cell.textLabel.font.pointSize];
	}

	if (indexPath.row == _selectedItemIndex)
		cell.textLabel.textColor = [UIColor colorWithRed:(50. / 255.) green:(79. / 255.) blue:(133. / 255.) alpha:1.];
	else cell.textLabel.textColor = [UIColor blackColor];

	cell.editingAccessoryType = UITableViewCellAccessoryDisclosureIndicator;
	int accessoryType = [self accessoryTypeForIndexPath:indexPath];
	cell.accessoryType = accessoryType;
	cell.accessoryView = [self accessoryViewForAccessoryType:accessoryType];

	return cell;
}

- (NSIndexPath *__nullable) tableView:(UITableView *) tableView willSelectRowAtIndexPath:(NSIndexPath *) indexPath {
	if (self.editing || !_allowEditing)
		return indexPath;
	return nil;
}

- (void) tableView:(UITableView *) tableView didSelectRowAtIndexPath:(NSIndexPath *) indexPath {
	if (_allowEditing) {
		[self editItemAtIndex:indexPath.row];
	} else {
		NSIndexPath *previouslySelectedIndexPath = [NSIndexPath indexPathForRow:_selectedItemIndex inSection:0];
		
		UITableViewCell *cell = (_selectedItemIndex != NSNotFound ? [tableView cellForRowAtIndexPath:previouslySelectedIndexPath] : nil);
		int previouslySelectedAccessoryType = [self accessoryTypeForIndexPath:previouslySelectedIndexPath];
		cell.accessoryType = previouslySelectedAccessoryType;
		cell.accessoryView = [self accessoryViewForAccessoryType:previouslySelectedAccessoryType];
		cell.textLabel.textColor = [UIColor blackColor];

		if (_selectedItemIndex == indexPath.row)
			[self _previewAudioAlertAtIndex:_selectedItemIndex];

		_selectedItemIndex = indexPath.row;
		_pendingChanges = YES;

		cell = [tableView cellForRowAtIndexPath:indexPath];
		int accessoryType = [self accessoryTypeForIndexPath:indexPath];
		cell.accessoryType = accessoryType;
		cell.accessoryView = [self accessoryViewForAccessoryType:accessoryType];
		cell.textLabel.textColor = [UIColor colorWithRed:(50. / 255.) green:(79. / 255.) blue:(133. / 255.) alpha:1.];

		if (self.listType == CQPreferencesListTypeFont) {
			UIFont *font = [UIFont fontWithName:self.values[indexPath.row] size:12.];
			UIFont *systemFont = [UIFont systemFontOfSize:12.];
			if ((!font || [font.familyName isCaseInsensitiveEqualToString:systemFont.familyName]) && [[UIFont cq_availableRemoteFontNames] containsObject:self.values[indexPath.row]])
			{
				__weak __typeof__((self)) weakSelf = self;
				[UIFont cq_loadFontWithName:self.values[indexPath.row] withCompletionHandler:^(NSString *fontName, UIFont *loadedFont) {
					__strong __typeof__((weakSelf)) strongSelf = weakSelf;
					[strongSelf.tableView beginUpdates];
					[strongSelf.tableView reloadRowsAtIndexPaths:@[ indexPath ] withRowAnimation:UITableViewRowAnimationFade];
					[strongSelf.tableView endUpdates];
				}];
			}
		}
		// If the accessory type isn't custom, the accessory view will refresh right away. Otherwise, we help it out a bit.
		if (previouslySelectedAccessoryType < CQTableViewCellAccessoryPlay) {
			[tableView beginUpdates];
			[tableView reloadRowsAtIndexPaths:@[previouslySelectedIndexPath] withRowAnimation:UITableViewRowAnimationNone];
			[tableView endUpdates];
		}
		[tableView deselectRowAtIndexPath:[tableView indexPathForSelectedRow] animated:YES];
	}
}

- (UITableViewCellEditingStyle) tableView:(UITableView *) tableView editingStyleForRowAtIndexPath:(NSIndexPath *) indexPath {
	if (!self.editing)
		return UITableViewCellEditingStyleNone;

	if (indexPath.row >= (NSInteger)_items.count)
		return UITableViewCellEditingStyleInsert;

	return UITableViewCellEditingStyleDelete;
}

- (void) tableView:(UITableView *) tableView accessoryButtonTappedForRowWithIndexPath:(NSIndexPath *) indexPath {
	NSString *item = _items[indexPath.row];
	NSString *path = nil;
	if (_listType == CQPreferencesListTypeAudio)
		path = [[NSBundle mainBundle] pathForResource:item ofType:@"aiff"];
	else if (_listType == CQPreferencesListTypeImage)
		path = [[NSBundle mainBundle] pathForResource:item ofType:@"png"];
	else {
		NSString *license = self.details[indexPath.row];
		if (!license.length)
			return;

		CQPreferencesTextViewController *textViewController = [[CQPreferencesTextViewController alloc] init];
		textViewController.text = license;
		textViewController.title = [self tableView:tableView cellForRowAtIndexPath:indexPath].textLabel.text;
		[self.navigationController pushViewController:textViewController animated:YES];

		return;
	}

	if (!path.length)
		return;

	if (_listType == CQPreferencesListTypeAudio)
		[self _previewAudioAlertAtIndex:indexPath.row];

	// Call this ourselves because we have a custom accessory view, and it steals the tap from the cell otherwise
	if ([self accessoryTypeForIndexPath:indexPath] >= (UITableViewCellAccessoryType)CQTableViewCellAccessoryPlay)
		[self tableView:tableView didSelectRowAtIndexPath:indexPath];
}

- (BOOL) tableView:(UITableView *) tableView canEditRowAtIndexPath:(NSIndexPath *) indexPath {
	return _allowEditing;
}

- (void) tableView:(UITableView *) tableView commitEditingStyle:(UITableViewCellEditingStyle) editingStyle forRowAtIndexPath:(NSIndexPath *) indexPath {
	if (editingStyle == UITableViewCellEditingStyleDelete) {
		[_items removeObjectAtIndex:indexPath.row];
		[tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:YES];
		_pendingChanges = YES;
	} else if (editingStyle == UITableViewCellEditingStyleInsert) {
		[self editItemAtIndex:indexPath.row];
	}
}

- (BOOL) tableView:(UITableView *) tableView canMoveRowAtIndexPath:(NSIndexPath *) indexPath {
	return (indexPath.row < (NSInteger)_items.count);
}

- (NSIndexPath *) tableView:(UITableView *) tableView targetIndexPathForMoveFromRowAtIndexPath:(NSIndexPath *) sourceIndexPath toProposedIndexPath:(NSIndexPath *) proposedDestinationIndexPath {
	if (proposedDestinationIndexPath.row >= (NSInteger)_items.count)
		return [NSIndexPath indexPathForRow:(_items.count - 1) inSection:0];
	return proposedDestinationIndexPath;
}

- (void) tableView:(UITableView *) tableView moveRowAtIndexPath:(NSIndexPath *) fromIndexPath toIndexPath:(NSIndexPath *) toIndexPath {
	if (toIndexPath.row >= (NSInteger)_items.count)
		return;

	id item = _items[fromIndexPath.row];
	[_items removeObject:item];
	[_items insertObject:item atIndex:toIndexPath.row];

	_pendingChanges = YES;
}

#pragma mark -

- (void) _previewAudioAlertAtIndex:(NSUInteger) index {
	NSString *item = _items[index];
	NSString *path = [[NSBundle mainBundle] pathForResource:[item description] ofType:@"aiff"];
	if (!path)
		return;

	NSURL *audioURL = [NSURL fileURLWithPath:path];

	if (![_audioPlayer.url isEqual:audioURL]) {
		_audioPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:[NSURL fileURLWithPath:path] error:nil];
	}

	[_audioPlayer play];
}
@end

NS_ASSUME_NONNULL_END
