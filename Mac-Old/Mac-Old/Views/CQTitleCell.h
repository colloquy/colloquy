#import "CQButtonCell.h"

@interface CQTitleCell : CQButtonCell {
@private
	NSString *_titleText;

	NSMutableDictionary *_attributes;
}
@property (nonatomic, copy) NSString *titleText;
@property (nonatomic, readonly) NSDictionary *attributes;
@end
