#import "MVTableView.h"

@implementation MVTableView
- (NSImage *) dragImageForRows:(NSArray *) dragRows event:(NSEvent *) dragEvent dragImageOffset:(NSPointPointer) dragImageOffset {
	NSImage *ret = nil;
	if( [[self dataSource] respondsToSelector:@selector( tableView:dragImageForRows:dragImageOffset: )] )
		ret = [[self dataSource] tableView:self dragImageForRows:dragRows dragImageOffset:dragImageOffset];
	if( ! ret ) ret = [super dragImageForRows:dragRows event:dragEvent dragImageOffset:dragImageOffset];
	return ret;
}

- (BOOL) autosaveTableColumnHighlight {
	return autosaveTableColumnHighlight;
}

- (void) setAutosaveTableColumnHighlight:(BOOL) flag {
	autosaveTableColumnHighlight = flag;
	if( flag && [self autosaveName] ) {
		NSString *ident = [[NSUserDefaults standardUserDefaults] stringForKey:[NSString stringWithFormat:@"%@ Highlighted Column %@", [self class], [self autosaveName]]];
		[self setHighlightedTableColumn:[self tableColumnWithIdentifier:ident]];
	}
}

- (void) setHighlightedTableColumn:(NSTableColumn *) aTableColumn {
	[super setHighlightedTableColumn:aTableColumn];
	if( autosaveTableColumnHighlight && [self autosaveName] ) {
		[[NSUserDefaults standardUserDefaults] setObject:[aTableColumn identifier] forKey:[NSString stringWithFormat:@"%@ Highlighted Column %@", [self class], [self autosaveName]]];
	}
}

- (NSMenu *) menuForEvent:(NSEvent *) event {
	NSPoint where;
	int row = -1, col = -1;

	where = [self convertPoint:[event locationInWindow] fromView:nil];
	row = [self rowAtPoint:where];
	col = [self columnAtPoint:where];

	if( row >= 0 ) {
		NSTableColumn *column = nil;
		if( col >= 0 ) column = [[self tableColumns] objectAtIndex:col];

		if( [[self delegate] respondsToSelector:@selector( tableView:shouldSelectRow: )] ) {
			if( [[self delegate] tableView:self shouldSelectRow:row] )
				[self selectRow:row byExtendingSelection:NO];
		} else [self selectRow:row byExtendingSelection:NO];
	
		if( [[self dataSource] respondsToSelector:@selector( tableView:menuForTableColumn:row: )] )
			return [[self dataSource] tableView:self menuForTableColumn:column row:row];
	} else {
		[self deselectAll:nil];
		return [self menu];
	}

	return nil;
}

- (void) keyDown:(NSEvent *) event {
	if( [[event charactersIgnoringModifiers] characterAtIndex:0] == NSDeleteCharacter ) {
		if( [[self delegate] respondsToSelector:@selector( clear: )] ) {
			[[self delegate] clear:nil];
			return;
		}
	}
	[super keyDown:event];
}
@end
