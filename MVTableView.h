@interface MVTableView : NSTableView {
	unsigned int autosaveTableColumnHighlight:1;
	unsigned int dataSourceDragImageForRows:1;
	unsigned int dataSourceMenuForTableColumn:1;
	unsigned int dataSourceToolTipForTableColumn:1;
	unsigned int delegateRectOfRow:1;
	unsigned int delegateRowsInRect:1;
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
