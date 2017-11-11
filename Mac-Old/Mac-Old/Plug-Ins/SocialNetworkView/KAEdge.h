//
//  Edge.h
//  SocialNetworkView
//
//  Created by Karl Adam on Wed Mar 31 2004.
//  Copyright (c) 2004 matrixPointer. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "KANode.h"

@interface KAEdge : NSObject {
	KANode  *_startNode;
	KANode  *_endNode;
	
	double  _weight;
}

- (id) initWithStartNode:(KANode *) inStart andEndNode:(KANode *) inEnd;

//accessors
- (double) weight;

- (KANode *) startNode;
- (KANode *) endNode;

//mutators
- (void) setWeight:(double) inWeight;

@end
