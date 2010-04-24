#import "CQModalNavigationController.h"

@class CQBouncerSettings;

@interface CQBouncerCreationViewController : CQModalNavigationController <UINavigationControllerDelegate> {
	@protected
	CQBouncerSettings *_settings;
}
@end
