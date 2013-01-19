#import "CQModalNavigationController.h"

#import "CQColloquyApplication.h"

@implementation CQModalNavigationController
- (id) init {
	if (!(self = [super init]))
		return nil;

	self.delegate = self;

	self.modalPresentationStyle = UIModalPresentationFormSheet;

	return self;
}

- (void) dealloc {
	self.delegate = nil;

	[_rootViewController release];

	[super dealloc];
}

#pragma mark -

- (void) viewDidLoad {
	[super viewDidLoad];

	UIBarButtonItem *cancelItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(close:)];
	_rootViewController.navigationItem.leftBarButtonItem = cancelItem;
	[cancelItem release];

	[self pushViewController:_rootViewController animated:NO];
}

#pragma mark -

- (void) close:(id) sender {
	[[CQColloquyApplication sharedApplication] dismissModalViewControllerAnimated:YES];
}
@end
