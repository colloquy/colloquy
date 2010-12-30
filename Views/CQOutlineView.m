#define CQCellNotSelected -1

#import "CQOutlineView.h"

@interface NSCell (CQGroupCell)
- (void) mouseEntered:(NSEvent *) event;
- (void) mouseExited:(NSEvent *) event;
- (void) addTrackingAreasForView:(NSView *) controlView inRect:(NSRect) cellFrame withUserInfo:(NSDictionary *) userInfo mouseLocation:(NSPoint) mouseLocation;
@end

@implementation CQOutlineView
- (id) init {
	if (!(self = [super init]))
		return nil;

	_mouseoverRow = CQCellNotSelected;
	_mouseoverColumn = CQCellNotSelected;

	return self;
}

- (id) initWithCoder:(NSCoder *) coder {
	if (!(self = [super initWithCoder:coder]))
		return nil;

	_mouseoverRow = CQCellNotSelected;
	_mouseoverColumn = CQCellNotSelected;

    return self;
}

- (void) dealloc {
	[_mouseoverCell release];

	[super dealloc];
}

#pragma mark -

- (void) updateTrackingAreas {
	for (NSTrackingArea *area in [self trackingAreas])
		if ((area.owner == self) && ([area.userInfo objectForKey:@"Row"]))
			[self removeTrackingArea:area];

	NSRange visibleRows = [self rowsInRect:self.visibleRect];
	NSPoint mouseLocation = [self convertPoint:[self.window convertScreenToBase:[NSEvent mouseLocation]] fromView:nil];
	for (NSUInteger row = visibleRows.location; row < visibleRows.location + visibleRows.length; row++ ) {
		NSCell *fullWidthCell = [self preparedCellAtColumn:CQCellNotSelected row:row];

		if (fullWidthCell) {
			if (![fullWidthCell respondsToSelector:@selector(addTrackingAreasForView:inRect:withUserInfo:mouseLocation:)])
				continue;

			NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInteger:CQCellNotSelected], @"Column", [NSNumber numberWithInteger:row], @"Row", nil];
			[fullWidthCell addTrackingAreasForView:self inRect:[self frameOfCellAtColumn:CQCellNotSelected row:row] withUserInfo:userInfo mouseLocation:mouseLocation];
		} else {
			NSIndexSet *visibleColumnIndexes = [self columnIndexesInRect:self.visibleRect];
			for (NSInteger column = visibleColumnIndexes.firstIndex; column != NSNotFound; column = [visibleColumnIndexes indexGreaterThanIndex:column]) {
				NSCell *cell = [self preparedCellAtColumn:column row:row];
				if (![cell respondsToSelector:@selector(addTrackingAreasForView:inRect:withUserInfo:mouseLocation:)])
					continue;

				NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInteger:column], @"Column", [NSNumber numberWithInteger:row], @"Row", nil];
				[cell addTrackingAreasForView:self inRect:[self frameOfCellAtColumn:column row:row] withUserInfo:userInfo mouseLocation:mouseLocation];
			}
		}
	}
}

- (void) mouseEntered:(NSEvent *) event {
	NSDictionary *userData = event.userData;
    NSNumber *row = [userData valueForKey:@"Row"];
    NSNumber *column = [userData valueForKey:@"Column"];
	if (!row || !column)
		return;

	NSInteger rowInteger = [row integerValue]; 
	NSInteger columnInteger = [column integerValue];
	NSCell *cell = [self preparedCellAtColumn:columnInteger row:rowInteger];

	if (_mouseoverCell == cell)
		return;

	if (![cell respondsToSelector:@selector(mouseEntered:)])
		return;

	id old = _mouseoverCell;
	_mouseoverCell = [cell copyWithZone:nil];
	_mouseoverCell.controlView = self;
	[_mouseoverCell mouseEntered:event];

	[old release];

	_mouseoverColumn = columnInteger;
	_mouseoverRow = rowInteger;
}

- (void) mouseExited:(NSEvent *) event {
    NSDictionary *userData = event.userData;
    NSNumber *row = [userData valueForKey:@"Row"];
    NSNumber *column = [userData valueForKey:@"Column"];
	if (!row || !column)
		return;

	NSCell *cell = [self preparedCellAtColumn:[column integerValue] row:[row integerValue]];
	if (![cell respondsToSelector:@selector(mouseExited:)])
		return;

	cell.controlView = self;
	[cell mouseExited:event];

	// We are now done with the copied cell
	[_mouseoverCell release];
	_mouseoverCell = nil;

	_mouseoverRow = CQCellNotSelected;
	_mouseoverColumn = CQCellNotSelected;
}

#pragma mark -

- (NSCell *) preparedCellAtColumn:(NSInteger) column row:(NSInteger) row {
	if (!self.selectedCell && (row == _mouseoverRow) && (column == _mouseoverColumn))
		return _mouseoverCell;
	return [super preparedCellAtColumn:column row:row];
}

- (void) updateCell:(NSCell *) cell {
	if (cell == _mouseoverCell)
		[self setNeedsDisplayInRect:[self frameOfCellAtColumn:_mouseoverColumn row:_mouseoverRow]];
	else [super updateCell:cell];
}
@end
