//
//  KAConfiguration.h
//  SocialNetworkView
//
//  Created by Karl Adam on Wed Mar 31 2004.
//  Copyright (c) 2004 matrixPointer. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface KAConfiguration : NSObject {
	NSDictionary *properties;
}

//accessors
- (int) getIntForKey:(NSString *) key;
- (double) getDoubleForKey:(NSString *) key;
- (BOOL) getBOOLForKey:(NSString *) key;
- (NSColor *) getColorForKey:(NSString *) key;
- (NSSet *) getSetKorKey:(NSString *) key;
- (NSString *) getStringForKey:(NSString *) key;

#pragma mark -

- (double) temporalDecayAmount;
- (double) k;
- (double) c;
- (double) maxRepulsiveForceDistance;
- (double) maxNodeMovement;
- (double) minDiagramSize;
@end
