#import "CQModalNavigationController.h"

@class CQBouncerSettings;

NS_ASSUME_NONNULL_BEGIN

@interface CQBouncerCreationViewController : CQModalNavigationController <UINavigationControllerDelegate> {
	@protected
	CQBouncerSettings *_settings;
}
@end

NS_ASSUME_NONNULL_END
