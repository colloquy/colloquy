// Created by Joar Wingfors.
// Modified by Timothy Hatcher for Colloquy.
// Copyright Joar Wingfors and Timothy Hatcher. All rights reserved.

#import "JVViewCell.h"

@implementation JVViewCell
- (void) dealloc {
    _view = nil;
}

- (void) setView:(NSView *) view {
    _view = view;
}

- (NSView *) view {
    return _view;
}

- (void) drawWithFrame:(NSRect) cellFrame inView:(NSView *) controlView {
    [super drawWithFrame:cellFrame inView:controlView];

    [[self view] setFrame:cellFrame];

    if( [[self view] superview] != controlView )
		[controlView addSubview:[self view]];
}
@end
