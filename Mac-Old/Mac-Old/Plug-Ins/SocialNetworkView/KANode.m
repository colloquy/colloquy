//
//  Node.m
//  SocialNetworkView
//
//  Created by Karl Adam on Wed Mar 31 2004.
//  Copyright (c) 2004 matrixPointer. All rights reserved.
//

#import "KANode.h"
#import <stdlib.h>

#pragma mark Java-C Bridge

double jRandom() {
	//yes, this is overkill, but who cares
	srandom( time(0) );
	srand48( random() );
	
	return drand48();
}

@implementation KANode

- (id) initWithNick:(NSString *)nick {
	
	if ( self = [super init] ) {
		_nick = [nick retain];
	
		_weight = 0;
		_x = jRandom();
		_y = jRandom();
		_fx = 0;
		_fy = 0;
	}
	
	return self;
}

- (void) dealloc {
	[_nick release];
	_nick = nil;
	
	[super dealloc];
}

#pragma mark Accessors

- (double) x {
	return _x;
}

- (double) y {
	return _y;
}

- (double) fx {
	return _fx;
}

- (double) fy {
	return _fy;
}

- (double) weight {
	return _weight;
}

#pragma mark Mutators

- (void) setX:(double) inX {
	_x = inX;
}

- (void) setY:(double) inY{
	_y = inY;
}

- (void) setFX:(double) inFX {
	_fx = inFX;
}

- (void) setFY:(double) inFY {
	_fy = inFY;
}

- (void) setWeight:(double) inWeight {
	_weight = inWeight;
}

#pragma mark Miscellany

- (NSString *) description {
	return _nick;
}

- (BOOL) isEqual:(id) inObj {
	return [_nick isEqual:inObj];
}

- (unsigned) hash {
	return [_nick hash];
}
@end
