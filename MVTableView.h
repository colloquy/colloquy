#import <Cocoa/Cocoa.h>

@interface MVTableView : NSTableView {
	BOOL autosaveTableColumnHighlight;
}
+ (NSImage *) ascendingSortIndicator;
+ (NSImage *) descendingSortIndicator;

- (NSImage *) dragImageForRows:(NSArray *) dragRows event:(NSEvent *) dragEvent dragImageOffset:(NSPointPointer) dragImageOffset;

- (BOOL) autosaveTableColumnHighlight;
- (void) setAutosaveTableColumnHighlight:(BOOL) flag;

- (NSRect) originalRectOfRow:(int) row;
@end

@interface NSObject (MVTableViewDataSource)
- (NSImage *) tableView:(MVTableView *) tableView dragImageForRows:(NSArray *) rows dragImageOffset:(NSPointPointer) dragImageOffset;
- (NSMenu *) tableView:(MVTableView *) view menuForTableColumn:(NSTableColumn *) column row:(int) row;
- (NSString *) tableView:(MVTableView *) view toolTipForTableColumn:(NSTableColumn *) column row:(int) row;
@end

@interface NSObject (MVTableViewDelegate)
- (NSRect) tableView:(MVTableView *) tableView rectOfRow:(int) row defaultRect:(NSRect) defaultRect;
- (NSRange) tableView:(MVTableView *) tableView rowsInRect:(NSRect) rect defaultRange:(NSRange) defaultRange;
@end
