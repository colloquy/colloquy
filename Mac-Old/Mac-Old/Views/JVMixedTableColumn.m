#import "JVMixedTableColumn.h"

@implementation JVMixedTableColumn
- (void) awakeFromNib {
	delegateDataCellForRow = [[self.tableView delegate] respondsToSelector:@selector( tableView:dataCellForRow:tableColumn: )];
}

- (void) setTableView:(NSTableView *) tableView {
	[super setTableView:tableView];
	delegateDataCellForRow = [[self.tableView delegate] respondsToSelector:@selector( tableView:dataCellForRow:tableColumn: )];
}

- (id) dataCellForRow:(int) row {
	id ret = nil;
	if( delegateDataCellForRow && ( ret = [(id <JVMixedTableColumnDelegate>)[self.tableView delegate] tableView:_tableView dataCellForRow:row tableColumn:self] ) )
		return ret;
	return [super dataCellForRow:row];
}
@end
