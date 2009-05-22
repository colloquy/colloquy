@interface MVTableView : NSTableView {
	NSUInteger autosaveTableColumnHighlight:1;
	NSUInteger dataSourceDragImageForRows:1;
	NSUInteger dataSourceMenuForTableColumn:1;
	NSUInteger dataSourceToolTipForTableColumn:1;
	NSUInteger delegateRectOfRow:1;
	NSUInteger delegateRowsInRect:1;
}
+ (NSImage *) ascendingSortIndicator;
+ (NSImage *) descendingSortIndicator;

- (BOOL) autosaveTableColumnHighlight;
- (void) setAutosaveTableColumnHighlight:(BOOL) flag;

- (NSRect) originalRectOfRow:(int) row;
@end

@interface NSObject (MVTableViewDataSource)
- (NSMenu *) tableView:(MVTableView *) view menuForTableColumn:(NSTableColumn *) column row:(int) row;
- (NSString *) tableView:(MVTableView *) view toolTipForTableColumn:(NSTableColumn *) column row:(int) row;
@end

@interface NSObject (MVTableViewDelegate)
- (NSRect) tableView:(MVTableView *) tableView rectOfRow:(int) row defaultRect:(NSRect) defaultRect;
- (NSRange) tableView:(MVTableView *) tableView rowsInRect:(NSRect) rect defaultRange:(NSRange) defaultRange;
@end
