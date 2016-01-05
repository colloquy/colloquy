#import <Cocoa/Cocoa.h>

@interface MVTableView : NSTableView {
	NSUInteger autosaveTableColumnHighlight:1;
	NSUInteger dataSourceDragImageForRows:1;
	NSUInteger dataSourceMenuForTableColumn:1;
	NSUInteger dataSourceToolTipForTableColumn:1;
	NSUInteger delegateRectOfRow:1;
	NSUInteger delegateRowsInRect:1;
}

@property BOOL autosaveTableColumnHighlight;

- (NSRect) originalRectOfRow:(NSInteger) row;
@end

@protocol MVTableViewDataSource
- (NSMenu *) tableView:(NSTableView *) view menuForTableColumn:(NSTableColumn *) column row:(NSInteger) row;
- (NSString *) tableView:(MVTableView *) view toolTipForTableColumn:(NSTableColumn *) column row:(NSInteger) row;
@end

@protocol MVTableViewDelegate
- (void) clear:(id) sender;
- (NSRect) tableView:(MVTableView *) tableView rectOfRow:(NSInteger) row defaultRect:(NSRect) defaultRect;
- (NSRange) tableView:(MVTableView *) tableView rowsInRect:(NSRect) rect defaultRange:(NSRange) defaultRange;
@end
