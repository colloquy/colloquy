#import "JVMixedTableColumn.h"
#import <AppKit/NSTableView.h>
#import <Cocoa/Cocoa.h>

@implementation JVMixedTableColumn
- (void) awakeFromNib {
	delegateDataCellForRow = [[_tableView delegate] respondsToSelector:@selector( tableView:dataCellForRow:tableColumn: )];
}
	
- (void) setTableView:(NSTableView *) tableView {
	[super setTableView:tableView];
	delegateDataCellForRow = [[_tableView delegate] respondsToSelector:@selector( tableView:dataCellForRow:tableColumn: )];
}

- (id) dataCellForRow:(int) row {
	id ret = nil;
	if( delegateDataCellForRow && ( ret = [[_tableView delegate] tableView:_tableView dataCellForRow:row tableColumn:self] ) )
		return ret;
	return [super dataCellForRow:row];
}
@end