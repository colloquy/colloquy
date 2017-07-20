//
//  RunOnMainThread.h
//  Chat Core
//
//  Created by C.W. Betts on 4/6/15.
//
//

#ifndef Chat_Core_RunOnMainThread_h
#define Chat_Core_RunOnMainThread_h

#import <Foundation/Foundation.h>

static inline void RunOnMainThreadSync(dispatch_block_t __nonnull DISPATCH_NOESCAPE block)
{
	if ([NSThread isMainThread]) {
		block();
	} else {
		dispatch_sync(dispatch_get_main_queue(), block);
	}
}

static inline void RunOnMainThreadAsync(dispatch_block_t __nonnull block)
{
	if ([NSThread isMainThread]) {
		block();
	} else {
		dispatch_async(dispatch_get_main_queue(), block);
	}
}

#endif
