//
//  Edge.m
//  SocialNetworkView
//
//  Created by Karl Adam on Wed Mar 31 2004.
//  Copyright (c) 2004 matrixPointer. All rights reserved.
//

#import "KAEdge.h"


@implementation KAEdge

- (id) initWithStartNode:(KANode *) inStart andEndNode:(KANode *) inEnd {

	if ( self = [super init] ) {
		[inStart retain];
		_startNode = inStart;
	
		[inEnd retain];
		_endNode = inEnd;
	
		_weight = 0;
	}
	
	return self;
}

- (void) dealloc {
	[_startNode release];
	_startNode = nil;
	
	[_endNode release];
	_endNode = nil;
}

#pragma mark Accessors

- (double) weight {
	return _weight;
}

- (KANode *) startNode {
	return _startNode;
}

- (KANode *) endNode {
	return _endNode;
}

#pragma mark Mutators

- (void) setWeight:(double) inWeight {
	_weight = inWeight;
}

#pragma mark Miscellany

- (BOOL) isEqual:(id) inObj {
	return ( _startNode == [inObj startNode] && _endNode == [inObj endNode] || 
			 _startNode == [inObj endNode] && _endNode == [inObj startNode] );
}

- (unsigned) hash {
	return [_startNode hash] + [_endNode hash];
}

@end
