//
//  KAGraph.m
//  Colloquy
//
//  Created by Karl Adam on Fri Apr 02 2004.
//  Copyright (c) 2004 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "KAGraph.h"
#import "KAEdge.h"

@implementation KAGraph

- (id) initWithLabel:(NSString *) inLabel andConfiguration:(KAConfiguration *) inConfig {
	if ( self = [super init] ) {
		_label			= [inLabel retain];
		_caption		= @"";
		_nodes			= [[NSMutableDictionary alloc] initWithCapacity:10];
		_edges			= [[NSMutableDictionary alloc] initWithCapacity:10];
		_allSeenNodes   = [[NSMutableSet alloc] initWithCapacity:10];
	
		_config			= [inConfig retain];;
	
		_maxWeight		= 0.0;
		_framecount		= 0;
	}
	return self;
}

#pragma mark -

- (KANode *) getNode:(KANode *) inNode {
	//why the Object and it's key are one and the same I may never know
	return [_nodes objectForKey:inNode];
}

- (KAEdge *) getEdge:(KAEdge *) inEdge {
	//why the Object and it's key are one and the same I may never know
	return [_edges objectForKey:inEdge];
}

- (int) getFrameCount {
	return _framecount;
}

- (NSString *) getLabel {
	return _label;
}

#pragma mark -

- (void) addNode:(KANode *) inNode {
	[_nodes setObject:inNode forKey:inNode];
	[_allSeenNodes addObject:inNode];
	[inNode setWeight:[inNode weight] +1];
}

- (BOOL) addEdgeWithStart:(KANode *) inStart andEnd:(KANode *) inEnd; {
	BOOL retVal = NO;
	
	if ( inStart != inEnd ) {
		[self addNode:inStart];
		[self addNode:inEnd];
		
		KAEdge *aEdge = [[KAEdge alloc] initWithStartNode:inStart andEndNode:inEnd];
		[_edges setObject:aEdge forKey:aEdge];
		
		[aEdge setWeight:[aEdge weight] +1];
		
		// The graph has changed in structure. Let's make everything else
        // decay slightly.
        [self decayBy:[_config temporalDecayAmount]];
		
		// The graph has changed.
        _framecount++;
		
		retVal = YES;
	}
	
	return retVal;
}

- (BOOL) removeNode:(KANode *) inNode {
	BOOL retVal = NO;
	if ( [_nodes objectForKey:inNode] != nil ) {
		[_nodes removeObjectForKey:inNode];
		
		//now remove the edge if any is associated with this node
		NSEnumerator *anObj = [_edges objectEnumerator];
		KAEdge *curObj = nil;
		
		while ( anObj = [anObj nextObject] ) {
			curObj = (KAEdge *)anObj;
			if ( inNode == [curObj startNode] || inNode == [curObj endNode] ) {
				[_edges removeObjectForKey:curObj];
			} //if
		} //while
		
		// The graph has changed.
		_framecount++;
		
		retVal = YES;
	}
	
	return retVal;
}

- (void) setCaption:(NSString *) inCaption {
	_caption = [inCaption retain];
}

#pragma mark -

- (BOOL) containsNode:(KANode *) inNode {
	return [_allSeenNodes member:inNode] != nil;
}

- (BOOL) containsEdge:(KAEdge *) inEdge {
	return [_edges objectForKey:inEdge] != nil;
}

#pragma mark -

- (void) decayBy:(double) amount {
	NSEnumerator *edgeEnumerator = [_edges objectEnumerator];
	NSEnumerator *nodeEnumerator = [_nodes objectEnumerator];
	
	KAEdge *anEdge = nil;
	while ( edgeEnumerator = [edgeEnumerator nextObject] ) {
		anEdge = (KAEdge *)edgeEnumerator;
		[anEdge setWeight:[anEdge weight] - amount];
		
		if ( [anEdge weight] <= 0 ) {
			[_edges removeObjectForKey:anEdge];
		}
	}
	
	KANode *anNode = nil;
	while ( nodeEnumerator = [nodeEnumerator nextObject] ) {
		anNode = (KANode *)edgeEnumerator;
		[anNode setWeight:[anNode weight] - amount];
		
		if ( [anNode weight] <= 0 ) {
			[_nodes removeObjectForKey:anNode];
		}
	}
	
}

- (NSSet *) getConnectedNodes {
	NSMutableSet *aSet = [NSMutableSet setWithCapacity:10];
	NSEnumerator *aEnumerator = [_edges objectEnumerator];
	KAEdge *aEdge = nil;
	
	while ( aEnumerator = [aEnumerator nextObject] ) {
		aEdge = (KAEdge *)aEnumerator;
		
		[aSet addObject:[aEdge startNode]];
		[aSet addObject:[aEdge endNode]];
	}

	return aSet;
}

- (void) doLayout:(int) iterations {
	double k = [_config k];
	double c = [_config c];
	int iterCounter, nodeCounter1, nodeCounter2, edgeCounter, moveCounter = 0;
	
	//dump them into Arrays
	NSArray *nodes = [_nodes allValues];
	NSArray *edges = [_edges allValues];
	
	// Repulsive forces between nodes that are further apart than this are ignored.
	double maxRepulsiveForceDistance = [_config maxRepulsiveForceDistance];
	
	// For each iteration...
	for ( iterCounter = 0; iterCounter < iterations; iterCounter++ ) {
	
		// Calculate forces acting on nodes due to node-node repulsions...
		for ( nodeCounter1 = 0; nodeCounter1 < [nodes count]; nodeCounter1++) {
			for ( nodeCounter2 = nodeCounter1 + 1; nodeCounter2 < [nodes count]; nodeCounter2++ ) {
				KANode *nodeA = [nodes objectAtIndex:nodeCounter1];
				KANode *nodeB = [nodes objectAtIndex:nodeCounter2];
				
				double deltaX = [nodeB x] - [nodeA x];
				double deltaY = [nodeB y] - [nodeA y];
				
				double distanceSquared = deltaX * deltaX + deltaY * deltaY;
				
				if ( distanceSquared < 0.01 ) {
					deltaX = jRandom() / 10 + 0.1;
					deltaY = jRandom() / 10 + 0.1;
					distanceSquared = deltaX * deltaX + deltaY * deltaY;
				}
				
				double distance = sqrt( distanceSquared );
				
				if ( distance < maxRepulsiveForceDistance ) {
					double repulsiveForce = ( k* k / distance );
					
					[nodeB setFX:[nodeB fx] + (repulsiveForce * deltaX / distance )];
					[nodeB setFY:[nodeB fy] + (repulsiveForce * deltaY / distance )];
					[nodeA setFX:[nodeA fx] - (repulsiveForce * deltaX / distance )];
					[nodeA setFY:[nodeA fy] - (repulsiveForce * deltaY / distance )];
					
				}
			}
		}
		
		
		// Calculate forces acting on nodes due to edge attractions.
		for ( edgeCounter = 0; edgeCounter < [edges count]; edgeCounter++) {
			KAEdge *aEdge = [edges objectAtIndex:edgeCounter];
			KANode *nodeA = [aEdge startNode];
			KANode *nodeB = [aEdge endNode];
			
			double deltaX = [nodeB x] - [nodeA x];
			double deltaY = [nodeB y] - [nodeA y];
			
			double distanceSquared = deltaX * deltaX + deltaY * deltaY;
			
			// Avoid division by zero error or Nodes flying off to
			// infinity.  Pretend there is an arbitrary distance between
			// the Nodes.
			if (distanceSquared < 0.01) {
				deltaX = jRandom() / 10 + 0.1;
				deltaY = jRandom() / 10 + 0.1;
				distanceSquared = deltaX * deltaX + deltaY * deltaY;
			}
			
			double distance = sqrt( distanceSquared );
			
			if ( distance > maxRepulsiveForceDistance ) {
				distance = maxRepulsiveForceDistance;
			}
			
			distanceSquared = distance * distance;
			
			double attractiveForce = ( distanceSquared - k* k ) / k;
			
			// Make edges stronger if people know each other.
			double weight = [aEdge weight];
			if ( weight < 1 ) {
				weight = 1;
			}
			attractiveForce *= log(weight) * 0.5 + 1;
			
			[nodeB setFX:[nodeB fx] - attractiveForce * deltaX / distance];
			[nodeB setFY:[nodeB fy] - attractiveForce * deltaY / distance];
			[nodeA setFX:[nodeB fx] - attractiveForce * deltaX / distance];
			[nodeA setFY:[nodeB fy] - attractiveForce * deltaY / distance];
		}
		
		// Now move each node to its new location...
		for ( moveCounter = 0; moveCounter < [nodes count]; moveCounter++) {
			KANode *aNode = [nodes objectAtIndex:moveCounter];
			
			double xMovement = c * [aNode fx];
			double yMovement = c * [aNode fy];
			
			// Limit movement values to stop nodes flying into oblivion.
			double max = [_config maxNodeMovement];
			if ( xMovement > max ) {
				xMovement = max;
			} else if ( xMovement < -max ) {
				xMovement = -max;
			}
			
			if ( yMovement > max ) {
				yMovement = max;
			} else if ( yMovement < -max ) {
				yMovement = -max;
			}
			
			[aNode setX:[aNode x] + xMovement];
			[aNode setY:[aNode y] + yMovement];
			
			// Reset the forces
			[aNode setFX:0];
			[aNode setFY:0];
		}//for
	
	}//for iterCounter
}


- (void) calculateBoundsUsingWidth:(int) inWidth andHeight:(int) inHeight {
	NSEnumerator *setEnumerator, *edgeEnumerator = nil;
	double minX, maxX, minY, maxY = 0;
	_maxWeight = 0;
	
	NSSet *aNodes = [self getConnectedNodes];
	setEnumerator = [aNodes objectEnumerator];
	//some ridiculous code sat here
	//it is being ignored instead we just find out maxX and MaxY
		while ( setEnumerator = [setEnumerator nextObject] ) {
			KANode *curNode = (KANode *)setEnumerator;
			
			if ( [curNode x] > maxX ) {
				maxX = [curNode x];
			} else if ( [curNode x] < minX ) {
				minX = [curNode x];
			}
			
			if ( [curNode y] > maxY ) {
				maxY = [curNode y];
			} else if ( [curNode y] < minY ) {
				minY = [curNode y];
			}
		}
	
	// Increase size if too small.
	double minSize = [_config minDiagramSize];
	if (maxX - minX < minSize) {
		double midX = (maxX + minX) / 2;
		minX = midX - (minSize / 2);
		maxX = midX + (minSize / 2);
	}
	if (maxY - minY < minSize) {
		double midY = (maxY + minY) / 2;
		minY = midY - (minSize / 2);
		maxY = midY + (minSize / 2);
	}
	
	// Work out the maximum weight.
	while ( edgeEnumerator = [edgeEnumerator nextObject] ) {
		KAEdge *aEdge = (KAEdge *) edgeEnumerator;
		
		if ( [aEdge weight] > _maxWeight ) {
			_maxWeight = [aEdge weight];
		}
	}
	
	// Jibble the boundaries to maintain the aspect ratio.
	double xyRatio = ((maxX - minX) / (maxY - minY)) / (inWidth / inHeight);
	if (xyRatio > 1) {
		// diagram is wider than it is high.
		double dy = maxY - minY;
		dy = dy * xyRatio - dy;
		minY = minY - dy / 2;
		maxY = maxY + dy / 2;
	}
	else if (xyRatio < 1) {
		// Diagram is higher than it is wide.
		double dx = maxX - minX;
		dx = dx / xyRatio - dx;
		minX = minX - dx / 2;
		maxX = maxX + dx / 2;
	}
	
}

- (void) draw:(NSString *) channel inRect:(NSRect) inRect withNodeRadius:(int) nodeRadius andEdgeThreshold:(double) edgeThreshold andShowEdges:(BOOL) showEdges {
	NSSet *allNodes = [self getConnectedNodes];
	
	// Now actually draw the thing...
	
}

@end
