#import <Cocoa/Cocoa.h>

@interface MVTableView : NSTableView {
	BOOL autosaveTableColumnHighlight;
}
- (NSImage *) dragImageForRows:(NSArray *) dragRows event:(NSEvent *) dragEvent dragImageOffset:(NSPointPointer) dragImageOffset;

- (BOOL) autosaveTableColumnHighlight;
- (void) setAutosaveTableColumnHighlight:(BOOL) flag;
@end

@interface NSObject (MVTableViewDataSource)
- (NSImage *) tableView:(NSTableView *) tableView dragImageForRows:(NSArray *) rows dragImageOffset:(NSPointPointer) dragImageOffset;
- (NSMenu *) tableView:(NSTableView *) view menuForTableColumn:(NSTableColumn *) column row:(int) row;
@end
