@interface CQTableViewSectionHeader : UIControl {
	UIImageView *_backgroundImageView;
	UIImageView *_disclosureImageView;
	UIImage *_backgroundImage;
	UIImage *_backgroundHighlightedImage;
	UILabel *_textLabel;
	NSUInteger _section;
	BOOL _showsDisclosureState;
	CGRect _frame;
}

@property (nonatomic, readonly) UILabel *textLabel;
@property (nonatomic) NSUInteger section;
@property (nonatomic) BOOL showsDisclosureState;
@property (nonatomic, readonly) UIImageView *disclosureImageView;
@end
