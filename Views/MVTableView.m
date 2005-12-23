#import "MVTableView.h"

@implementation MVTableView
+ (NSImage *) ascendingSortIndicator {
	NSImage *result = [NSImage imageNamed:@"NSAscendingSortIndicator"];
	if( ! result && [[NSTableView class] respondsToSelector:@selector( _defaultTableHeaderSortImage )])
		result = [NSTableView performSelector:@selector( _defaultTableHeaderSortImage )];
	return result;
}

+ (NSImage *) descendingSortIndicator {
	NSImage *result = [NSImage imageNamed:@"NSDescendingSortIndicator"];
	if( ! result && [[NSTableView class] respondsToSelector:@selector( _defaultTableHeaderReverseSortImage )] )
		result = [NSTableView performSelector:@selector( _defaultTableHeaderReverseSortImage )];
	return result;
}

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
	int row = -1, col = -1;

	where = [self convertPoint:[event locationInWindow] fromView:nil];
	row = [self rowAtPoint:where];
	col = [self columnAtPoint:where];

	if( row >= 0 ) {
		NSTableColumn *column = nil;
		if( col >= 0 ) column = [_tableColumns objectAtIndex:col];

		if( _tvFlags.delegateShouldSelectRow ) {
			if( [_delegate tableView:self shouldSelectRow:row] )
				[self selectRow:row byExtendingSelection:NO];
		} else [self selectRow:row byExtendingSelection:NO];

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

- (NSRect) rectOfRow:(int) row {
	NSRect defaultRect = [super rectOfRow:row];
	if( delegateRectOfRow )
		return [_delegate tableView:self rectOfRow:row defaultRect:defaultRect];
	return defaultRect;
}

- (NSRect) originalRectOfRow:(int) row {
	return [super rectOfRow:row];
}

- (NSRange) rowsInRect:(NSRect) rect {
	NSRange defaultRange = [super rowsInRect:rect];
	if( delegateRowsInRect )
		return [_delegate tableView:self rowsInRect:rect defaultRange:defaultRange];
	return defaultRange;
}

- (void) rebuildTooltipRects {
	int rows = [self numberOfRows];
	int columns = [self numberOfColumns];
	int ri = 0, ci = 0;

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
	int row = [self rowAtPoint:point];
    int column = [self columnAtPoint:point];

	NSTableColumn *tcolumn = nil;
	if( column >= 0 ) tcolumn = [_tableColumns objectAtIndex:column];

	if( row >= 0 && [_dataSource respondsToSelector:@selector( tableView:toolTipForTableColumn:row: )] )
		return [_dataSource tableView:self toolTipForTableColumn:tcolumn row:row];

	return [self toolTip];
}
@end