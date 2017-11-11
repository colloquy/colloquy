//
//  Node.h
//  SocialNetworkView
//
//  Created by Karl Adam on Wed Mar 31 2004.
//  Copyright (c) 2004 matrixPointer. All rights reserved.
//

#import <Foundation/Foundation.h>

double jRandom();

@interface KANode : NSObject {
	NSString	*_nick;
	
	double		_weight;
	double		_x;
	double		_y;
	double		_fx;
	double		_fy;
}

//accessors
- (double) x;
- (double) y;

- (double) fx;
- (double) fy;

- (double) weight;

//mutators
- (void) setX:(double) inX;
- (void) setY:(double) inY;

- (void) setFX:(double) inFX;
- (void) setFY:(double) inFY;

- (void) setWeight:(double) inWeight;

@end
