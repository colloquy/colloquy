#import "CQModalNavigationController.h"

#import "CQColloquyApplication.h"

NS_ASSUME_NONNULL_BEGIN

@implementation  CQModalNavigationController
- (instancetype) initWithRootViewController:(UIViewController *) rootViewController {
	if (!(self = [self init]))
		return nil;

	_rootViewController = rootViewController;

	return self;
}

- (instancetype) init {
	if (!(self = [super init]))
		return nil;

	self.delegate = self;

	self.modalPresentationStyle = UIModalPresentationFormSheet;

	_closeButtonItem = UIBarButtonSystemItemCancel;

	return self;
}

- (void) dealloc {
	self.delegate = nil;
}

#pragma mark -

- (void) viewDidLoad {
	[super viewDidLoad];

	UIBarButtonItem *cancelItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:_closeButtonItem target:self action:@selector(close:)];
	_rootViewController.navigationItem.leftBarButtonItem = cancelItem;

	[self pushViewController:_rootViewController animated:NO];
}

#pragma mark -

- (void) close:(__nullable id) sender {
	[[CQColloquyApplication sharedApplication] dismissModalViewControllerAnimated:YES];
}
@end

NS_ASSUME_NONNULL_END
