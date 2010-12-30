#import "CQButtonCell.h"

@interface CQTitleCell : CQButtonCell {
@private
	NSString *_titleText;
	NSString *_subtitleText;

	NSMutableDictionary *_attributes;
}
@property (nonatomic, copy) NSString *titleText;
@property (nonatomic, copy) NSString *subtitleText;
@end
