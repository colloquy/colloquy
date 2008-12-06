#import "CQSearchCell.h"

@implementation CQSearchCell
- (id) initWithFrame:(CGRect) frame reuseIdentifier:(NSString *) reuseIdentifier {
	if (!(self = [super initWithFrame:frame reuseIdentifier:reuseIdentifier]))
		return nil;

	self.selectionStyle = UITableViewCellSelectionStyleNone;

	_searchBar = [[UISearchBar alloc] initWithFrame:CGRectZero];
	_searchBar.autoresizingMask = (UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleBottomMargin);
	_searchBar.placeholder = NSLocalizedString(@"Search", @"Search placeholder text");
	_searchBar.tintColor = [UIColor colorWithRed:(190. / 255.) green:(199. / 255.) blue:(205. / 255.) alpha:1.];
	_searchBar.autocapitalizationType = UITextAutocapitalizationTypeNone;
	_searchBar.autocorrectionType = UITextAutocorrectionTypeNo;
	_searchBar.delegate = self;

	[_searchBar sizeToFit];

	[self addSubview:_searchBar];

	return self;
}

- (void) dealloc {
	[_searchBar release];
    [super dealloc];
}

- (BOOL) canBecomeFirstResponder {
	return [_searchBar canBecomeFirstResponder];
}

- (BOOL) becomeFirstResponder {
	return [_searchBar becomeFirstResponder];
}

- (BOOL) canResignFirstResponder {
	return [_searchBar canResignFirstResponder];
}

- (BOOL) resignFirstResponder {
	return [_searchBar resignFirstResponder];
}

- (BOOL) isFirstResponder {
	return [_searchBar isFirstResponder];
}

@synthesize searchAction = _searchAction;

- (UIView *) backgroundView {
	return nil;
}

- (UIView *) selectedBackgroundView {
	return nil;
}

- (NSString *) text {
	return _searchBar.text;
}

- (void) setText:(NSString *) text {
	_searchBar.text = text;
}

- (void) searchBar:(UISearchBar *) searchBar textDidChange:(NSString *) searchText {
	if (self.searchAction && (!self.target || [self.target respondsToSelector:self.searchAction]))
		[[UIApplication sharedApplication] sendAction:self.searchAction to:self.target from:self forEvent:nil];
}
@end
