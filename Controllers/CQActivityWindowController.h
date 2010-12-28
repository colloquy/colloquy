@class CQGroupCell;

@interface CQActivityWindowController : NSWindowController {
@private
	NSMapTable *_activity;
	NSTimeInterval _rowLastClickedTime;

	IBOutlet NSOutlineView *_outlineView;

	CQGroupCell *_groupCell;
}
+ (CQActivityWindowController *) sharedController;

- (IBAction) showActivityWindow:(id) sender;
- (IBAction) hideActivityWindow:(id) sender;
@end
