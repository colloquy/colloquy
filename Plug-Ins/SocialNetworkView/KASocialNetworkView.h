//
//  KASocialNetworkGraphView.h
//  SocialNetworkView
//
//  Created by Karl Adam on Sun Apr 04 2004.
//  Copyright (c) 2004 __MyCompanyName__. All rights reserved.
//

#import <AppKit/AppKit.h>
#import "KAGraph.h"

@interface KASocialNetworkView : NSView {
	KAGraph			*_innerGraph;
	KAConfiguration *_config;
}

- (id)initWithFrame:(NSRect)frame andGraph:(KAGraph *) inGraph;
@end
