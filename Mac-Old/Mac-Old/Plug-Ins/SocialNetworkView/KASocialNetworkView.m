//
//  KASocialNetworkGraphView.m
//  SocialNetworkView
//
//  Created by Karl Adam on Sun Apr 04 2004.
//  Copyright (c) 2004 __MyCompanyName__. All rights reserved.
//

#import "KASocialNetworkView.h"


@implementation KASocialNetworkView

- (id)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        _innerGraph = nil;
    }
    return self;
}

- (id)initWithFrame:(NSRect)frame andGraph:(KAGraph *) inGraph {
    self = [super initWithFrame:frame];
    if (self) {
        _innerGraph = [inGraph retain];
    }
    return self;
}

- (void) dealloc {
	[_innerGraph release];
	_innerGraph = nil;
	
	[super dealloc];
}

- (void)drawRect:(NSRect)rect {
    NSSet *nodes = [_innerGraph getConnectedNodes];
	
	
}

@end
