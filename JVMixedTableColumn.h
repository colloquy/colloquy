@interface JVMixedTableColumn : NSTableColumn {
	int delegateDataCellForRow:1;
}
- (id) dataCellForRow:(int) row;
@end

@interface NSObject (JVMixedTableColumnDelegate)
- (id) tableView:(NSTableView *) tableView dataCellForRow:(int) row tableColumn:(NSTableColumn *) tableColumn;
@end
