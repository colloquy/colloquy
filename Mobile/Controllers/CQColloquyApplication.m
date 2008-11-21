#import "CQColloquyApplication.h"
#import "CQConnectionsController.h"
#import "CQChatController.h"

@implementation CQColloquyApplication
+ (CQColloquyApplication *) sharedApplication {
	return (CQColloquyApplication *)[super sharedApplication];
}

@synthesize tabBarController, mainWindow;

- (void) dealloc {
	[tabBarController release];
	[mainWindow release];
	[super dealloc];
}

- (void) applicationDidFinishLaunching:(UIApplication *) application {
	NSDictionary *defaults = [NSDictionary dictionaryWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"Defaults" ofType:@"plist"]];
	[[NSUserDefaults standardUserDefaults] registerDefaults:defaults];

	NSArray *viewControllers = [[NSArray alloc] initWithObjects:[CQConnectionsController defaultController], [CQChatController defaultController], nil];
	tabBarController.viewControllers = viewControllers;
	[viewControllers release];

	[mainWindow addSubview:tabBarController.view];
	[mainWindow makeKeyAndVisible];
}
@end
