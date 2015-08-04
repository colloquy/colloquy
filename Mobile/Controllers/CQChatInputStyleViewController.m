#import "CQChatInputStyleViewController.h"

#import "CQPreferencesSwitchCell.h"
#import "CQColorPickerTableCell.h"

#import "UIColorAdditions.h"

@interface CQChatInputStyleViewController () <UITableViewDataSource, UITableViewDelegate>
@property (atomic, assign) BOOL bold;
@property (atomic, assign) BOOL italicized;
@property (atomic, assign) BOOL underlined;

@property (atomic, assign) BOOL affectingForeground;
@property (atomic, copy) UIColor *foregroundColor;
@property (atomic, copy) UIColor *backgroundColor;
@end

#pragma mark -

@implementation CQChatInputStyleViewController
- (instancetype) init {
	return (self = [super initWithStyle:UITableViewStylePlain]);
}

- (void) viewDidLoad {
	[super viewDidLoad];

	self.affectingForeground = YES;

	CGFloat scale = self.tableView.window ? self.tableView.window.screen.scale : [UIScreen mainScreen].scale;
	self.tableView.layer.cornerRadius = (scale > 1. ? 4.5 : 5.);
	self.tableView.layer.borderWidth = 1. / scale;
	self.tableView.layer.borderColor = [UIApplication sharedApplication].keyWindow.tintColor.CGColor;
	self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
	self.tableView.showsVerticalScrollIndicator = NO;

	self.navigationItem.leftBarButtonItem.target = self;
	self.navigationItem.leftBarButtonItem.action = @selector(close:);
}

#pragma mark -

- (NSInteger) tableView:(UITableView *) tableView numberOfRowsInSection:(NSInteger) section {
	return 3;
}

- (CGFloat) tableView:(UITableView *) tableView heightForRowAtIndexPath:(NSIndexPath *) indexPath {
	if (indexPath.section == 0 && indexPath.row == 1)
		return 160.;
	return 35.;
}

- (UITableViewCell *) tableView:(UITableView *) tableView cellForRowAtIndexPath:(NSIndexPath *) indexPath {
	__weak __typeof__((self)) weakSelf = self;

	void (^updateButtonBackgroundAndTitleColorForState)(UIButton *, BOOL) = ^(UIButton *button, BOOL state) {
		if (state) {
			[button setBackgroundColor:[UIApplication sharedApplication].keyWindow.tintColor];
			[button setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
		} else {
			[button setBackgroundColor:[UIColor whiteColor]];
			[button setTitleColor:[UIApplication sharedApplication].keyWindow.tintColor forState:UIControlStateNormal];
		}
	};

	if (indexPath.section == 0) {
		if (indexPath.row == 0) {
			CQMultiButtonTableCell *multiButtonCell = [CQMultiButtonTableCell reusableTableViewCellInTableView:tableView];
			[multiButtonCell addButtonWithConfigurationHandler:^(UIButton *button) {
				__strong __typeof__((weakSelf)) strongSelf = weakSelf;

				[button addTarget:strongSelf action:@selector(startAffectingForeground:) forControlEvents:UIControlEventTouchUpInside];
				[button setTitle:NSLocalizedString(@"Foreground", @"Foreground Cell Button Title") forState:UIControlStateNormal];

				updateButtonBackgroundAndTitleColorForState(button, self.affectingForeground);
			}];

			[multiButtonCell addButtonWithConfigurationHandler:^(UIButton *button) {
				__strong __typeof__((self)) strongSelf = weakSelf;

				[button addTarget:strongSelf action:@selector(startAffectingBackground:) forControlEvents:UIControlEventTouchUpInside];
				[button setTitle:NSLocalizedString(@"Background", @"Background Cell Button Title") forState:UIControlStateNormal];

				updateButtonBackgroundAndTitleColorForState(button, !self.affectingForeground);
			}];

			return multiButtonCell;
		}

		if (indexPath.row == 1) {
			CQColorPickerTableCell *cell = [CQColorPickerTableCell reusableTableViewCellInTableView:tableView];
			cell.colors = @[
				[UIColor colorFromName:@"white"], [UIColor colorFromName:@"ash"], [UIColor colorFromName:@"grey"], [UIColor colorFromName:@"black"],
				[UIColor colorFromName:@"cyan"], [UIColor colorFromName:@"teal"], [UIColor colorFromName:@"blue"], [UIColor colorFromName:@"navy"],
				[UIColor colorFromName:@"yellow"], [UIColor colorFromName:@"orange"], [UIColor colorFromName:@"green"], [UIColor colorFromName:@"forest"],
				[UIColor colorFromName:@"red"], [UIColor colorFromName:@"maroon"], [UIColor colorFromName:@"magenta"], [UIColor colorFromName:@"purple"]
			];

			cell.colorSelectedBlock = ^(UIColor *color) {
				__strong __typeof__((weakSelf)) strongSelf = weakSelf;
				__strong __typeof__((strongSelf.delegate)) strongDelegate = strongSelf.delegate;

				if (strongSelf.affectingForeground) {
					strongSelf.foregroundColor = color;
					[strongDelegate chatInputStyleView:strongSelf didSelectColor:color forColorPosition:CQColorPositionForeground];
				} else {
					strongSelf.backgroundColor = color;
					[strongDelegate chatInputStyleView:strongSelf didSelectColor:color forColorPosition:CQColorPositionBackground];
				}
			};
			cell.activeColor = (self.affectingForeground ? self.foregroundColor : self.backgroundColor);

			return cell;
		}

		if (indexPath.row == 2) {
			CQMultiButtonTableCell *multiButtonCell = [CQMultiButtonTableCell reusableTableViewCellInTableView:tableView];
			multiButtonCell.contentView.layer.cornerRadius = 6.;
			multiButtonCell.expands = YES;

			[multiButtonCell addButtonWithConfigurationHandler:^(UIButton *button) {
				__strong __typeof__((weakSelf)) strongSelf = weakSelf;

				[button addTarget:strongSelf action:@selector(toggleBoldface:) forControlEvents:UIControlEventTouchUpInside];
				[button setTitle:NSLocalizedString(@"Bold", @"Bold Switch Cell Title") forState:UIControlStateNormal];
				button.titleLabel.font = [UIFont boldSystemFontOfSize:15.];

				updateButtonBackgroundAndTitleColorForState(button, strongSelf.bold);
			}];

			[multiButtonCell addButtonWithConfigurationHandler:^(UIButton *button) {
				__strong __typeof__((weakSelf)) strongSelf = weakSelf;

				[button addTarget:strongSelf action:@selector(toggleItalics:) forControlEvents:UIControlEventTouchUpInside];
				[button setTitle:NSLocalizedString(@"Italic", @"Italic Switch Cell Title") forState:UIControlStateNormal];
				button.titleLabel.font = [UIFont italicSystemFontOfSize:15.];

				updateButtonBackgroundAndTitleColorForState(button, strongSelf.italicized);
			}];

			[multiButtonCell addButtonWithConfigurationHandler:^(UIButton *button) {
				__strong __typeof__((weakSelf)) strongSelf = weakSelf;

				[button addTarget:strongSelf action:@selector(toggleUnderline:) forControlEvents:UIControlEventTouchUpInside];
				[button setAttributedTitle:[[NSAttributedString alloc] initWithString:NSLocalizedString(@"Underline", @"Underline Switch Cell Title") attributes:@{
					NSUnderlineStyleAttributeName: @(NSUnderlineStyleSingle),
					NSFontAttributeName: [UIFont systemFontOfSize:15.],
					NSForegroundColorAttributeName: (strongSelf.underlined ? [UIColor whiteColor] : [UIApplication sharedApplication].keyWindow.tintColor)
				}] forState:UIControlStateNormal];

				updateButtonBackgroundAndTitleColorForState(button, strongSelf.underlined);
			}];

			return multiButtonCell;
		}
	}

	return nil;
}

#pragma mark -

- (void) close:(id) sender {
	__strong __typeof__((self.delegate)) strongDelegate = self.delegate;
	[strongDelegate chatInputStyleViewShouldClose:self];
}

#pragma mark -

- (void) setAttributes:(NSDictionary *) attributes {
	_attributes = [attributes copy];

	UIFontDescriptor *descriptor = [attributes[NSFontAttributeName] fontDescriptor];
	self.bold = (descriptor.symbolicTraits & UIFontDescriptorTraitBold) == UIFontDescriptorTraitBold;
	self.italicized = (descriptor.symbolicTraits & UIFontDescriptorTraitItalic) == UIFontDescriptorTraitItalic;
	self.underlined = !!attributes[NSUnderlineStyleAttributeName];
	self.foregroundColor = attributes[NSForegroundColorAttributeName];
	self.backgroundColor = attributes[NSBackgroundColorAttributeName];

	[self.tableView reloadData];
}

#pragma mark -

- (void) toggleBoldface:(id) sender {
	self.bold = !self.bold;
	__strong __typeof__((self.delegate)) strongDelegate = self.delegate;
	[strongDelegate chatInputStyleView:self didChangeTextTrait:CQTextTraitBold toState:self.bold];

	[self.tableView beginUpdates];
	[self.tableView reloadRowsAtIndexPaths:@[ [NSIndexPath indexPathForRow:2 inSection:0] ] withRowAnimation:UITableViewRowAnimationNone];
	[self.tableView endUpdates];
}

- (void) toggleItalics:(id) sender {
	self.italicized = !self.italicized;
	__strong __typeof__((self.delegate)) strongDelegate = self.delegate;
	[strongDelegate chatInputStyleView:self didChangeTextTrait:CQTextTraitItalic toState:self.italicized];

	[self.tableView beginUpdates];
	[self.tableView reloadRowsAtIndexPaths:@[ [NSIndexPath indexPathForRow:2 inSection:0] ] withRowAnimation:UITableViewRowAnimationNone];
	[self.tableView endUpdates];
}

- (void) toggleUnderline:(id) sender {
	self.underlined = !self.underlined;
	__strong __typeof__((self.delegate)) strongDelegate = self.delegate;
	[strongDelegate chatInputStyleView:self didChangeTextTrait:CQTextTraitUnderline toState:self.underlined];

	[self.tableView beginUpdates];
	[self.tableView reloadRowsAtIndexPaths:@[ [NSIndexPath indexPathForRow:2 inSection:0] ] withRowAnimation:UITableViewRowAnimationNone];
	[self.tableView endUpdates];
}

#pragma mark -

- (void) startAffectingForeground:(id) sender {
	[self _toggleAffectingForegroundToState:YES];
}

- (void) startAffectingBackground:(id) sender {
	[self _toggleAffectingForegroundToState:NO];
}

- (void) _toggleAffectingForegroundToState:(BOOL) affectingForeground {
	self.affectingForeground = affectingForeground;
	[self.tableView beginUpdates];
	[self.tableView reloadRowsAtIndexPaths:@[ [NSIndexPath indexPathForRow:0 inSection:0], [NSIndexPath indexPathForRow:1 inSection:0] ] withRowAnimation:UITableViewRowAnimationNone];
	[self.tableView endUpdates];
}

@end
