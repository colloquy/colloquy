#import "CQTitleCell.h"

@interface CQFileTransferCell : CQTitleCell {
@private
	NSProgressIndicator *_progressIndicator;
	NSString *_subtitleText;
}
@property (nonatomic, copy) NSString *subtitleText;
@property (nonatomic, readonly) NSProgressIndicator *progressIndicator;
@end
