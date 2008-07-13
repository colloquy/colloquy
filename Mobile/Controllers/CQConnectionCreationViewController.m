#import "CQConnectionCreationViewController.h"
#import "CQConnectionEditViewController.h"

@implementation CQConnectionCreationViewController
- (id) init {
	if( ! ( self = [super init] ) )
		return nil;
	return self;
}

- (void) dealloc {
	[editViewController release];
	[super dealloc];
}

- (void) viewDidLoad {
	[super viewDidLoad];

	editViewController = [[CQConnectionEditViewController alloc] init];
	editViewController.title = NSLocalizedString(@"New Connection", @"New Connection view title");
	editViewController.navigationItem.prompt = NSLocalizedString(@"Enter the server and your identity information", @"New connection prompt");

	UIBarButtonItem *cancelItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector( cancel: )];
	editViewController.navigationItem.leftBarButtonItem = cancelItem;
	[cancelItem release];

	UIBarButtonItem *saveItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemSave target:self action:@selector( commit: )];
	editViewController.navigationItem.rightBarButtonItem = saveItem;
	[saveItem release];

	editViewController.navigationItem.rightBarButtonItem.enabled = NO;

	[self pushViewController:editViewController animated:NO];
}

- (void) didReceiveMemoryWarning {
	if( ! self.view.superview ) {
		[editViewController release];
		editViewController = nil;
	}

	[super didReceiveMemoryWarning];
}

- (void) cancel:(id) sender {
	[self.parentViewController dismissModalViewControllerAnimated:YES];
}

- (void) commit:(id) sender {
	[self.parentViewController dismissModalViewControllerAnimated:YES];
}
@end
