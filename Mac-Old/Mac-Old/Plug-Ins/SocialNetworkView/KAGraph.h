//
//  KAGraph.h
//  Colloquy
//
//  Created by Karl Adam on Fri Apr 02 2004.
//  Copyright (c) 2004 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "KAConfiguration.h"
#import "KAEdge.h"

@interface KAGraph : NSObject {
	NSString			*_label;
	NSString			*_caption;
	NSMutableDictionary	*_nodes;
	NSMutableDictionary	*_edges;
	NSMutableSet		*_allSeenNodes;
	
	KAConfiguration		*_config;
	
	double				_maxWeight;
	int					_framecount;
	
}

#pragma mark -

- (KANode *) getNode:(KANode *) inNode;
- (KAEdge *) getEdge:(KAEdge *) inEdge;
- (int) getFrameCount;
- (NSString *) getLabel;

#pragma mark -

- (void) addNode:(KANode *) inNode;
- (BOOL) addEdgeWithStart:(KANode *) inStart andEnd:(KANode *) inEnd;
- (BOOL) removeNode:(KANode *) inNode;
- (void) setCaption:(NSString *) inCaption;

#pragma mark -

- (BOOL) containsNode:(KANode *) inNode;
- (BOOL) containsEdge:(KAEdge *) inEdge;

#pragma mark -

- (void) decayBy:(double) amount;
- (NSSet *) getConnectedNodes;
- (void) doLayout:(int) iterations;
- (void) calculateBoundsUsingWidth:(int) inWidth andHeight:(int) inHeight;
- (void) draw:(NSString *) channel inRect:(NSRect) inRect withNodeRadius:(int) nodeRadius andEdgeThreshold:(double) edgeThreshold andShowEdges:(BOOL) showEdges;
@end
