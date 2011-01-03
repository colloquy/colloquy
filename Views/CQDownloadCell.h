#import "CQTitleCell.h"

@interface CQDownloadCell : CQTitleCell {
@private
	NSProgressIndicator *_progressIndicator;
	NSString *_subtitleText;
}
@property (nonatomic, copy) NSString *subtitleText;
@property (nonatomic, readonly) NSProgressIndicator *progressIndicator;

- (void) downloadFinished;
@end
