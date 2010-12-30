@class CQGroupCell;
@class CQTitleCell;

@interface CQActivityWindowController : NSWindowController {
@private
	NSMapTable *_activity;
	NSTimeInterval _rowLastClickedTime;

	IBOutlet NSOutlineView *_outlineView;

	CQGroupCell *_groupCell;
	CQTitleCell *_titleCell;

	NSDateFormatter *_timeFormatter;
}
+ (CQActivityWindowController *) sharedController;

- (IBAction) showActivityWindow:(id) sender;
- (IBAction) hideActivityWindow:(id) sender;
@end
