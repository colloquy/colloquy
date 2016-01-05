#import "CQRootContainerViewController.h"

#import "CQChatController.h"
#import "CQChatListViewController.h"
#import "CQChatNavigationController.h"
#import "CQChatOrderingController.h"
#import "CQChatPresentationController.h"

typedef NS_ENUM(NSInteger, CQSidebarOrientation) {
	CQSidebarOrientationNone,
	CQSidebarOrientationPortrait,
	CQSidebarOrientationLandscape,
	CQSidebarOrientationAll
};

@interface CQRootContainerViewController () <UISplitViewControllerDelegate>
@property (strong) UISplitViewController *splitViewController;
@end

@implementation CQRootContainerViewController
- (void) buildRootViewController {
	if (self.splitViewController) {
		[self.splitViewController willMoveToParentViewController:nil];
		[self.splitViewController.view removeFromSuperview];
		[self.splitViewController removeFromParentViewController];
	}

	self.splitViewController = [[UISplitViewController alloc] init];
	CQChatPresentationController *presentationController = [CQChatController defaultController].chatPresentationController;
	[presentationController setStandardToolbarItems:@[] animated:NO];

	self.splitViewController.viewControllers = @[[CQChatController defaultController].chatNavigationController, presentationController];
	self.splitViewController.delegate = self;
	self.splitViewController.preferredDisplayMode = [self targetDisplayModeForActionInSplitViewController:self.splitViewController];

	[self addChildViewController:self.splitViewController];
	[self.view addSubview:self.splitViewController.view];
	[self didMoveToParentViewController:self];
}

#pragma mark -

- (UISplitViewControllerDisplayMode) targetDisplayModeForActionInSplitViewController:(UISplitViewController *) splitViewController {
#if !SYSTEM(TV)
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
#endif
	return UISplitViewControllerDisplayModeAllVisible;
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

#pragma mark -

- (void) viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>) coordinator {
	[self.splitViewController viewWillTransitionToSize:size withTransitionCoordinator:coordinator];

	[coordinator animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext> context) {
		UISplitViewControllerDisplayMode displayMode = [self targetDisplayModeForActionInSplitViewController:self.splitViewController];
		self.splitViewController.preferredDisplayMode = displayMode;

		BOOL displayModeDesiresButton = displayMode == UISplitViewControllerDisplayModePrimaryHidden || displayMode == UISplitViewControllerDisplayModePrimaryOverlay;
		BOOL traitCollectionAllowsButton = self.traitCollection.horizontalSizeClass == UIUserInterfaceSizeClassRegular;
		[self _updateRightNavigationItemButtonWithDisplayModeDesiresButton:displayModeDesiresButton traitCollectionAllowsButton:traitCollectionAllowsButton];
	} completion:nil];
}

- (void) willTransitionToTraitCollection:(UITraitCollection *) newCollection withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>) coordinator {
	[self.splitViewController willTransitionToTraitCollection:newCollection withTransitionCoordinator:coordinator];

	[coordinator animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext> context) {
		UISplitViewControllerDisplayMode displayMode = self.splitViewController.displayMode;

		BOOL displayModeDesiresButton = displayMode == UISplitViewControllerDisplayModePrimaryHidden || displayMode == UISplitViewControllerDisplayModePrimaryOverlay;
		BOOL traitCollectionAllowsButton = newCollection.horizontalSizeClass == UIUserInterfaceSizeClassRegular;
		[self _updateRightNavigationItemButtonWithDisplayModeDesiresButton:displayModeDesiresButton traitCollectionAllowsButton:traitCollectionAllowsButton];
	} completion:nil];
}

#pragma mark -

- (void) _updateRightNavigationItemButtonWithDisplayModeDesiresButton:(BOOL) displayModeDesiresButton traitCollectionAllowsButton:(BOOL) traitCollectionAllowsButton {
	for (UIViewController <CQChatViewController> *chatController in [CQChatOrderingController defaultController].chatViewControllers) {
		if (displayModeDesiresButton && traitCollectionAllowsButton) {
			UIBarButtonItem *item = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Colloquies", @"Colloquies") style:UIBarButtonItemStylePlain target:self action:@selector(toggleColloquies:)];
			chatController.navigationItem.leftBarButtonItem = item;
		} else {
			chatController.navigationItem.leftBarButtonItem = nil;
		}
	}
}

- (void) toggleColloquies:(id) sender {
	self.splitViewController.preferredDisplayMode = UISplitViewControllerDisplayModePrimaryOverlay;
}
@end
