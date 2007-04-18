//============================================================================
// 
//     License:
// 
//     This library is free software; you can redistribute it and/or
//     modify it under the terms of the GNU Lesser General Public
//     License as published by the Free Software Foundation; either
//     version 2.1 of the License, or (at your option) any later version.
// 
//     This library is distributed in the hope that it will be useful,
//     but WITHOUT ANY WARRANTY; without even the implied warranty of
//     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
//     Lesser General Public License for more details.
// 
//     You should have received a copy of the GNU Lesser General Public
//     License along with this library; if not, write to the Free Software
//     Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  
//     USA
// 
//     Copyright (C) 2002 Dave Smith (dizzyd@jabber.org)
// 
// $Id: NSMutableString.m,v 1.1 2004/07/19 03:49:03 jtownsend Exp $
//============================================================================

#import <Foundation/Foundation.h>

@implementation NSMutableString(_ACID_EXT)

-(NSString*) nextTokenDelimitedBy:(NSString*)tokens searchFromIndex:(int)index
{
    NSString* result;
    NSCharacterSet* cset = [NSCharacterSet characterSetWithCharactersInString:tokens];
    NSRange startingRange = { index, [self length] - index };
    NSRange r = [self rangeOfCharacterFromSet:cset options:0 range:startingRange];
    if (r.length == 0)
    {
        r = startingRange;
        result = [NSString stringWithString:self];
    }
    else
    {
        r.length = r.location - index;
        r.location = index;
        result = [self substringWithRange:r];
     }
    [self deleteCharactersInRange:r];
    return result;
}

-(NSString*) nextTokenDelimitedBy:(NSString*)tokens
{
    return [self nextTokenDelimitedBy:tokens searchFromIndex:0];
}

-(void) deleteCharactersFromIndex:(int)start toIndex:(int)end
{
    NSRange r = {start, end - start};
    [self deleteCharactersInRange:r];
}

-(void) clear
{
    NSRange r = {0, [self length]};
    [self deleteCharactersInRange:r];
}

@end
