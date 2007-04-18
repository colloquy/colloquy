//============================================================================
// 
//     License:
// 
//     This library is free software; you can redistribute it and/or
//     modify it under the terms of the GNU General Public
//     License as published by the Free Software Foundation; either
//     version 2 of the License, or (at your option) any later version.
// 
//     This library is distributed in the hope that it will be useful,
//     but WITHOUT ANY WARRANTY; without even the implied warranty of
//     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
//     General Public License for more details.
// 
//     You should have received a copy of the GNU General Public
//     License along with this library; if not, write to the Free Software
//     Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  021-1307  
//     USA
// 
//     Copyright (C) 2002 Dave Smith (dizzyd@jabber.org)
// 
// $Id: NSMutableArray+InsertSort.h,v 1.1 2004/07/19 03:49:03 jtownsend Exp $
//============================================================================

#import <Foundation/Foundation.h>

@interface NSMutableArray (AcidExtensions)

/*!
 @method addObject:sortStringSelector:
 @abstract insert the item, return the index the item was inserted at, or -1 if
 the item is already inserted.
 */
-(int) addObject:(id)object sortStringSelector:(SEL)selector;
@end
