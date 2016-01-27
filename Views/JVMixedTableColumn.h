#import <Cocoa/Cocoa.h>

@interface JVMixedTableColumn : NSTableColumn {
	NSUInteger delegateDataCellForRow:1;
}
- (id) dataCellForRow:(NSInteger) row;
@end

@protocol JVMixedTableColumnDelegate <NSTableViewDelegate>
@optional
- (id) tableView:(NSTableView *) tableView dataCellForRow:(NSInteger) row tableColumn:(NSTableColumn *) tableColumn;
@end
