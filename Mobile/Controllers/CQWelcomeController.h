#import "CQModalNavigationController.h"

NS_ASSUME_NONNULL_BEGIN

@interface CQWelcomeController : CQModalNavigationController {
	@protected
	BOOL _shouldShowOnlyHelpTopics;
}
@property (nonatomic) BOOL shouldShowOnlyHelpTopics;
@end

NS_ASSUME_NONNULL_END
