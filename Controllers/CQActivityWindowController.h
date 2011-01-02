@class CQGroupCell;
@class CQSubtitleCell;
@class CQFileTransferCell;

@interface CQActivityWindowController : NSWindowController {
@private
	NSMapTable *_activity;

	NSTimeInterval _rowLastClickedTime;
	IBOutlet NSOutlineView *_outlineView;

	CQGroupCell *_groupCell;
	CQSubtitleCell *_titleCell;

	NSDateFormatter *_timeFormatter;
}
+ (CQActivityWindowController *) sharedController;

- (IBAction) showActivityWindow:(id) sender;
- (IBAction) hideActivityWindow:(id) sender;
@end
