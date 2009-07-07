@interface CQBouncerSectionHeader : UIControl {
	UIImageView *_backgroundImageView;
	UIImageView *_disclosureImageView;
	UIImage *_backgroundImage;
	UIImage *_backgroundHighlightedImage;
	UILabel *_textLabel;
	NSUInteger _section;
}

@property (nonatomic, readonly) UILabel *textLabel;
@property (nonatomic) NSUInteger section;

@end
