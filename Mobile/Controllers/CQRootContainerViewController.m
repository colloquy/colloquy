#import "CQRootContainerViewController.h"

#import "CQChatController.h"
#import "CQChatListViewController.h"
#import "CQChatNavigationController.h"
#import "CQChatPresentationController.h"

typedef NS_ENUM(NSInteger, CQSidebarOrientation) {
	CQSidebarOrientationNone,
	CQSidebarOrientationPortrait,
	CQSidebarOrientationLandscape,
	CQSidebarOrientationAll
};

@interface CQRootContainerViewController () <UISplitViewControllerDelegate>
@property (strong) UISplitViewController *rootViewController;
@end

@implementation CQRootContainerViewController
- (void) buildRootViewController {
	UISplitViewController *splitViewController = [[UISplitViewController alloc] init];
	CQChatPresentationController *presentationController = [CQChatController defaultController].chatPresentationController;
	[presentationController setStandardToolbarItems:@[] animated:NO];

	splitViewController.viewControllers = @[[CQChatController defaultController].chatNavigationController, presentationController];
	splitViewController.delegate = self;
	splitViewController.preferredDisplayMode = [self targetDisplayModeForActionInSplitViewController:splitViewController];

	self.rootViewController = splitViewController;
}

#pragma mark -

- (UISplitViewControllerDisplayMode) targetDisplayModeForActionInSplitViewController:(UISplitViewController *) splitViewController {
	NSUInteger allowedOrientation = [[CQSettingsController settingsController] integerForKey:@"CQSplitSwipeOrientations"];
	if (allowedOrientation == CQSidebarOrientationNone)
		return UISplitViewControllerDisplayModeAllVisible;

	if (allowedOrientation == CQSidebarOrientationAll)
		return UISplitViewControllerDisplayModePrimaryOverlay;

	UIInterfaceOrientation interfaceOrientation = [UIApplication sharedApplication].statusBarOrientation;
	if (UIInterfaceOrientationIsLandscape(interfaceOrientation) && (allowedOrientation == CQSidebarOrientationLandscape))
		return UISplitViewControllerDisplayModePrimaryOverlay;

	if (UIInterfaceOrientationIsPortrait(interfaceOrientation) && (allowedOrientation == CQSidebarOrientationPortrait))
		return UISplitViewControllerDisplayModePrimaryOverlay;

	return UISplitViewControllerDisplayModeAllVisible;
}

- (void) splitViewController:(UISplitViewController *) splitViewController willChangeToDisplayMode:(UISplitViewControllerDisplayMode) displayMode {
	if (displayMode == UISplitViewControllerDisplayModePrimaryHidden || displayMode == UISplitViewControllerDisplayModePrimaryOverlay)
		[self cq_splitViewController:splitViewController willHideViewController:splitViewController.viewControllers.firstObject];
	else [self cq_splitViewController:splitViewController willShowViewController:splitViewController.viewControllers.firstObject];
}

- (BOOL) splitViewController:(UISplitViewController *) splitViewController collapseSecondaryViewController:(UIViewController *) secondaryViewController ontoPrimaryViewController:(UIViewController *) primaryViewController {
	if (!secondaryViewController)
		return YES;

	if ([secondaryViewController isKindOfClass:[CQChatPresentationController class]]) {
		CQChatPresentationController *presentationController = (CQChatPresentationController *)secondaryViewController;
		if (!presentationController.topChatViewController)
			return YES;
	}

	return [secondaryViewController isFirstResponder];
}

- (BOOL) splitViewController:(UISplitViewController *) splitViewController showDetailViewController:(UIViewController *) viewController sender:(nullable id) sender {
	[self cq_splitViewController:splitViewController willPresentViewController:viewController];

	return NO;
}

- (void) cq_splitViewController:(UISplitViewController *) splitViewController willPresentViewController:(UIViewController *) viewController {
	if (![viewController isKindOfClass:[CQChatNavigationController class]])
		return;

	CQChatNavigationController *navigationController = (CQChatNavigationController *)viewController;
	((CQChatListViewController *)(navigationController.topViewController)).active = YES;
}

- (void) cq_splitViewController:(UISplitViewController *) splitViewController willHideViewController:(UIViewController *) viewController {
}

- (void) cq_splitViewController:(UISplitViewController *) splitViewController willShowViewController:(UIViewController *) viewController {
}

#pragma mark -

- (void) viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>) coordinator {
	UISplitViewController *splitViewController = (UISplitViewController *)self.rootViewController;
	[coordinator animateAlongsideTransition:nil completion:^(id <UIViewControllerTransitionCoordinatorContext> context) {
		splitViewController.preferredDisplayMode = [self targetDisplayModeForActionInSplitViewController:splitViewController];
	}];
}
@end
