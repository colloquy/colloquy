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
//      General Public License for more details.
// 
//     You should have received a copy of the GNU General Public
//     License along with this library; if not, write to the Free Software
//     Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  021-1307  
//     USA
// 
//     Copyright (C) 2002 Dave Smith (dizzyd@jabber.org)
// 
// $Id: NSMutableArray+InsertSort.m,v 1.2 2004/11/12 07:31:53 alangh Exp $
//============================================================================

#import "NSMutableArray+InsertSort.h"

@implementation NSMutableArray (AcidExtensions)
-(int) addObject: (id) object sortStringSelector: (SEL) selector
{
    NSString* lvalue = [object performSelector: selector];
    unsigned int i;
    for (i = 0; i < [self count]; i++)
    {
        NSString* rvalue = [[self objectAtIndex: i] performSelector: selector];
        switch([lvalue compare: rvalue options: NSCaseInsensitiveSearch])
        {
            case NSOrderedAscending:
                [self insertObject: object atIndex: i];
                return i;
            case NSOrderedSame:
                if ([object isEqual: [self objectAtIndex: i]])
                {
                    return -1;
                }
            case NSOrderedDescending:
                break;
        }
    }
    // If we make it here, just add the object to the end
    [self addObject: object];
    return [self count] - 1;
}
@end
