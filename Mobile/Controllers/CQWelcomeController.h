#import "CQModalNavigationController.h"

@interface CQWelcomeController : CQModalNavigationController {
	@protected
	BOOL _shouldShowOnlyHelpTopics;
}
@property (nonatomic) BOOL shouldShowOnlyHelpTopics;
@end
