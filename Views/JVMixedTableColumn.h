@interface JVMixedTableColumn : NSTableColumn {
	NSUInteger delegateDataCellForRow:1;
}
- (id) dataCellForRow:(int) row;
@end

@protocol JVMixedTableColumnDelegate <NSTableViewDelegate>
@optional
- (id) tableView:(NSTableView *) tableView dataCellForRow:(int) row tableColumn:(NSTableColumn *) tableColumn;
@end
