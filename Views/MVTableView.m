#import "MVTableView.h"

@implementation MVTableView

- (void) setDelegate:(id) delegate {
	[super setDelegate:delegate];
	delegateRectOfRow = [_delegate respondsToSelector:@selector( tableView:rectOfRow:defaultRect: )];
	delegateRowsInRect = [_delegate respondsToSelector:@selector( tableView:rowsInRect:defaultRange: )];
}

- (void) setDataSource:(id) source {
	[super setDataSource:source];
	dataSourceMenuForTableColumn = [_dataSource respondsToSelector:@selector( tableView:menuForTableColumn:row: )];
	dataSourceToolTipForTableColumn = [_dataSource respondsToSelector:@selector( tableView:toolTipForTableColumn:row: )];
}

- (BOOL) autosaveTableColumnHighlight {
	return autosaveTableColumnHighlight;
}

- (void) setAutosaveTableColumnHighlight:(BOOL) flag {
	autosaveTableColumnHighlight = flag;
	if( flag && [self autosaveName] )
		[self setHighlightedTableColumn:[self highlightedTableColumn]];
}

- (void) setHighlightedTableColumn:(NSTableColumn *) tableColumn {
	[super setHighlightedTableColumn:tableColumn];
	if( autosaveTableColumnHighlight && [self autosaveName] ) {
		NSString *key = [[NSUserDefaults standardUserDefaults] stringForKey:[NSString stringWithFormat:@"%@ Highlighted Column %@", [self class], [self autosaveName]]];
		[[NSUserDefaults standardUserDefaults] setObject:[tableColumn identifier] forKey:key];
	}
}

- (NSMenu *) menuForEvent:(NSEvent *) event {
	NSPoint where;
	NSInteger row = -1, col = -1;

	where = [self convertPoint:[event locationInWindow] fromView:nil];
	row = [self rowAtPoint:where];
	col = [self columnAtPoint:where];

	if( row >= 0 ) {
		NSTableColumn *column = nil;
		if( col >= 0 ) column = _tableColumns[col];

		if( _tvFlags.delegateShouldSelectRow ) {
			if( [_delegate tableView:self shouldSelectRow:row] )
				[self selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
		} else [self selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];

		if( dataSourceMenuForTableColumn )
			return [_dataSource tableView:self menuForTableColumn:column row:row];
		else return [self menu];
	}

	[self deselectAll:nil];
	return [self menu];
}

- (void) keyDown:(NSEvent *) event {
	NSString *chars = [event charactersIgnoringModifiers];
	if( [chars length] && [chars characterAtIndex:0] == NSDeleteCharacter ) {
		if( [_delegate respondsToSelector:@selector( clear: )] ) {
			[_delegate clear:self];
			return;
		}
	}
	[super keyDown:event];
}

- (NSRect) rectOfRow:(NSInteger) row {
	NSRect defaultRect = [super rectOfRow:row];
	if( delegateRectOfRow )
		return [_delegate tableView:self rectOfRow:row defaultRect:defaultRect];
	return defaultRect;
}

- (NSRect) originalRectOfRow:(NSInteger) row {
	return [super rectOfRow:row];
}

- (NSRange) rowsInRect:(NSRect) rect {
	NSRange defaultRange = [super rowsInRect:rect];
	if( delegateRowsInRect )
		return [_delegate tableView:self rowsInRect:rect defaultRange:defaultRange];
	return defaultRange;
}

- (void) rebuildTooltipRects {
	NSUInteger rows = [self numberOfRows];
	NSUInteger columns = [self numberOfColumns];
	NSUInteger ri = 0, ci = 0;

	[self removeAllToolTips];

	for( ri = 0; ri < rows; ri++ ) {
		for( ci = 0; ci < columns; ci++ ) {
			NSRect rect = [self frameOfCellAtColumn:ci row:ri];
			[self addToolTipRect:rect owner:self userData:NULL];
		}
	}
}

- (void) reloadData {
	[super reloadData];
	[self rebuildTooltipRects];
}

- (void) noteNumberOfRowsChanged {
	[super noteNumberOfRowsChanged];
	[self rebuildTooltipRects];
}

- (NSString *) view:(NSView *) view stringForToolTip:(NSToolTipTag) tag point:(NSPoint) point userData:(void *) userData {
	NSInteger row = [self rowAtPoint:point];
	NSInteger column = [self columnAtPoint:point];

	NSTableColumn *tcolumn = nil;
	if( column >= 0 ) tcolumn = _tableColumns[column];

	if( row >= 0 && [_dataSource respondsToSelector:@selector( tableView:toolTipForTableColumn:row: )] )
		return [_dataSource tableView:self toolTipForTableColumn:tcolumn row:row];

	return [self toolTip];
}
@end
