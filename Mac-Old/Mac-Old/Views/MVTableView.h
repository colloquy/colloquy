@protocol MVTableViewDataSource;
@protocol MVTableViewDelegate;

@interface MVTableView : NSTableView {
	NSUInteger autosaveTableColumnHighlight:1;
	NSUInteger dataSourceDragImageForRows:1;
	NSUInteger dataSourceMenuForTableColumn:1;
	NSUInteger dataSourceToolTipForTableColumn:1;
	NSUInteger delegateRectOfRow:1;
	NSUInteger delegateRowsInRect:1;
}

@property (nonatomic, weak) id <MVTableViewDataSource> dataSource;
@property (nonatomic, weak) id <MVTableViewDelegate> delegate;

- (BOOL) autosaveTableColumnHighlight;
- (void) setAutosaveTableColumnHighlight:(BOOL) flag;

- (NSRect) originalRectOfRow:(NSInteger) row;
@end

@protocol MVTableViewDataSource <NSTableViewDataSource>
- (NSMenu *) tableView:(MVTableView *) view menuForTableColumn:(NSTableColumn *) column row:(NSInteger) row;
- (NSString *) tableView:(MVTableView *) view toolTipForTableColumn:(NSTableColumn *) column row:(NSInteger) row;
@end

@protocol MVTableViewDelegate <NSTableViewDelegate>
- (void) clear:(id) sender;
- (NSRect) tableView:(MVTableView *) tableView rectOfRow:(NSInteger) row defaultRect:(NSRect) defaultRect;
- (NSRange) tableView:(MVTableView *) tableView rowsInRect:(NSRect) rect defaultRange:(NSRange) defaultRange;
@end
