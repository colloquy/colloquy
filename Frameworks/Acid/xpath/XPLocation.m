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
// $Id: XPLocation.m,v 1.2 2004/10/03 11:09:07 jtownsend Exp $
//============================================================================

#import "acid-xpath.h"
#import "acid-dom.h"

@interface XPLocation (Private)
-(id) initWithTokens:(NSMutableString*)pathtokens;
@end

@implementation XPLocation

-(id) init
{
    if ((self = [super init]))
    {
        _predicates = [[NSMutableArray alloc] init];
    }
    return self;
}

-(void) dealloc
{
    [_predicates release];
    [_next release];
    [_elementName release];
    [_attributeName release];
    [super dealloc];
}

+(id) createWithPath:(NSString*)basepath
{
    NSMutableString* pathtokens = [[basepath mutableCopy] autorelease];
    XPLocation* result = [[XPLocation alloc] initWithTokens:pathtokens];
    return [result autorelease];
}

-(id) initWithTokens:(NSMutableString*)pathtokens
{
    self = [super init];
    if (self == nil)
        return nil;

    _predicates = [[NSMutableArray alloc] init];

    // Remove the / from the front of the path tokens
    [pathtokens deleteCharactersFromIndex:0 toIndex:1];

    // Search for either a path delimiter or predicate delimiter; note
    // that after this call, path's data will now be pointing at the
    // delimiter -- the actual token will have been removed
    _elementName = [pathtokens nextTokenDelimitedBy:@"/@[" searchFromIndex:0];
    assert(_elementName != nil);

    // Save a copy of the element location name
    [_elementName retain];

    // Begin looping
    while (YES)
    {
        // If the string's length is now 0, stop tokenizing
        if ([pathtokens length] == 0)
            break;	
        
        // Determine what delimiter stopped the tokenizer and act
        // accordingly
        switch([pathtokens characterAtIndex:0])
        {
        case '/':
            // Instantiate the next XPLocation with the remainder of the path
            _next = [[XPLocation alloc] initWithTokens:pathtokens];
            break;
        case '[':
            // Add a predicate and continue on
            [_predicates addObject: [XPPredicate createWithToken:pathtokens]];
            break;
        case '@':
            // This means, that the next token is an attribute name
            // used for accessing an attribute directly on this
            // location. This is a special case and we deal with it as
            // such
            [pathtokens deleteCharactersFromIndex:0 toIndex:1];
            _attributeName = [[NSString alloc] initWithString:pathtokens];
            [pathtokens clear];
            [_predicates addObject: [XPPredicate createAttributeExists:_attributeName]];
            break;
        }

        // Kick out of the loop if there is a following XPLocation; we rely
        // upon them to complete parsing
        if (_next != nil)
            break;
    }

    return self;
}

-(BOOL) matches:(XMLElement*)elem 
{
    // Check predicates (includes base name)
    if (![self checkPredicates:elem])
        return NO;

    if (_next != nil)
    {
        NSEnumerator* e = [elem childElementsEnumerator];
        id curr;
        while ((curr = [e nextObject]))
        {
            if ([_next matches:curr])
                return YES;
        }
        return NO;
    }
    return YES;
}

-(void) queryForString:(XMLElement*)elem withResultBuffer:(NSMutableString*)result
{
    // Check element base name and predicates
    if ([self checkPredicates:elem])
    {
        if (_attributeName != nil)
        {
            [result appendString:[elem getAttribute:_attributeName]];
            return;
        }
        
        // If there is another expression, pass the call on..
        if (_next != nil)
        {
            NSEnumerator* e = [elem childElementsEnumerator];
            id curr;
            while ((curr = [e nextObject]))
            {
                [_next queryForString:curr withResultBuffer:result];
            }
        }
        // Otherwise, this is the "terminal" location and we extract
        // CData from the element 
        else
        {
            NSString* cdata = [elem cdata];
            if (cdata != nil)
                [result appendString:[elem cdata]];
        }
    }
}

-(void) queryForList:(XMLElement*)elem withResultArray:(NSMutableArray*)result
{
    
   // Check element base name and predicates
    if ([self checkPredicates:elem])
    {
        if (_attributeName != nil)
        {
            if ([elem getAttribute:_attributeName] != nil)
                [result addObject:elem];
            return;
        }
        
        // If there is another expression, pass the call on..
        if (_next != nil)
        {
            NSEnumerator* e = [elem childElementsEnumerator];
            id curr;
            while ((curr = [e nextObject]))
            {
                [_next queryForList:curr withResultArray:result];
            }
        }
        // Otherwise, this is the "terminal" location and we extract
        // the element
        else
        {
            [result addObject:elem];
        }
    }
}


-(void) queryForStringList:(XMLElement*)elem withResultArray:(NSMutableArray*)result
{
    // Check element base name and predicates
    if ([self checkPredicates:elem])
    {
        if (_attributeName != nil)
        {
            if ([elem getAttribute:_attributeName] != nil)
                [result addObject:elem];
            return;
        }
        
        // If there is another expression, pass the call on..
        if (_next != nil)
        {
            NSEnumerator* e = [elem childElementsEnumerator];
            id curr;
            while ((curr = [e nextObject]))
            {
                [_next queryForStringList:curr withResultArray:result];
            }
        }
        // Otherwise, this is the "terminal" location and we extract
        // CData from the element
        else
        {
            NSString* c = [elem cdata];
            if (c != nil)
                [result addObject:c];
        }
    }    
}

-(BOOL) checkPredicates:(XMLElement*)elem
{
    if (![_elementName isEqual:[elem name]])
        return NO;

    if (_predicates != nil)
    {
        NSEnumerator* e = [_predicates objectEnumerator];
        id curr;
        while ((curr = [e nextObject]))
        {
            if (![curr matches:elem])
                return NO;
        }
    }
    return YES;
}


@end
