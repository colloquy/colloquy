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
		else return [self menu];
	}

	[self deselectAll:nil];
	return [self menu];
}

- (void) keyDown:(NSEvent *) event {
	NSString *chars = [event charactersIgnoringModifiers];
	if( [chars length] && [chars characterAtIndex:0] == NSDeleteCharacter ) {
		if( [[self delegate] respondsToSelector:@selector( clear: )] ) {
			[[self delegate] clear:nil];
			return;
		}
	}
	[super keyDown:event];
}

- (NSRect) rectOfRow:(int) row {
	NSRect defaultRect = [super rectOfRow:row];
	if( [[self delegate] respondsToSelector:@selector( tableView:rectOfRow:defaultRect: )] )
		return [[self delegate] tableView:self rectOfRow:row defaultRect:defaultRect];
	return defaultRect;
}

- (NSRect) originalRectOfRow:(int) row {
	return [super rectOfRow:row];
}

- (NSRange) rowsInRect:(NSRect) rect {
	NSRange defaultRange = [super rowsInRect:rect];
	if( [[self delegate] respondsToSelector:@selector( tableView:rowsInRect:defaultRange: )] )
		return [[self delegate] tableView:self rowsInRect:rect defaultRange:defaultRange];
	return defaultRange;
}

- (NSRect) frameOfCellAtColumn:(int) column row:(int) row {
	NSRect ret = [super frameOfCellAtColumn:column row:row];
	int enc = ( row | ( ( column && 0xFFFF ) << 16 ) );
	[self addToolTipRect:ret owner:self userData:(void *)enc];
	return ret;
}

- (void) display {
	[self removeAllToolTips];
	[super display];
}

- (NSString *) view:(NSView *) view stringForToolTip:(NSToolTipTag) tag point:(NSPoint) point userData:(void *) userData {
	int row = ( (int) userData & 0xFFFF );
	int column = ( (int) userData >> 16 );
	NSTableColumn *tcolumn = nil;
	if( column >= 0 ) tcolumn = [[self tableColumns] objectAtIndex:column];

	if( row >= 0 && [[self dataSource] respondsToSelector:@selector( tableView:toolTipForTableColumn:row: )] )
		return [[self dataSource] tableView:self toolTipForTableColumn:tcolumn row:row];

	return [self toolTip];
}
@end
