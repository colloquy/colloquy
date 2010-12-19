@interface CQActivityWindowController : NSWindowController <NSOutlineViewDataSource, NSOutlineViewDelegate> {
@private
	NSMapTable *_activity;

	IBOutlet NSOutlineView *_outlineView;
}
+ (CQActivityWindowController *) sharedController;

- (IBAction) showActivityWindow:(id) sender;
- (IBAction) hideActivityWindow:(id) sender;
@end
