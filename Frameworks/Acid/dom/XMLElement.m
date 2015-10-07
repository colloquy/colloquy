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
//     Copyright (C) 2002-2003 Dave Smith (dizzyd@jabber.org)
// 
// $Id: XMLElement.m,v 1.3 2004/10/16 21:40:05 gbooker Exp $
//============================================================================

#import "acid-dom.h"
#import <Foundation/NSEnumerator.h>

@interface _ElementEnumerator : NSEnumerator
{
    NSArray*        _elements;
    NSUInteger    _index;
}
-(instancetype) initWithArray:(NSArray*)elems;
-(NSArray*) allObjects;
-(id) nextObject;
@end

@implementation _ElementEnumerator

-(instancetype) initWithArray:(NSArray*)elems
{
    if (self =[self init])
    {
        _elements = elems;
        _index = 0;
    }
    return self;
}

-(NSArray*) allObjects
{
    return nil;
}

-(id) nextObject
{
    while (_index < [_elements count])
    {
        id curr = _elements[_index++];
        if ([curr isKindOfClass:[XMLElement class]])
            return curr;
    }
    return nil;
}

@end

@implementation XMLElement
{
    NSMutableDictionary* _attribs;  // XMLQName->NSString
    NSMutableArray*      _children;
    NSMutableDictionary* _namespaces; // NSString:URI->NSString:prefix
}

+(instancetype) constructElement:(XMLQName*)qname withAttributes:(NSMutableDictionary*)atts withDefaultURI:(NSString*)default_uri
{
    return nil;
}

// Basic initializers
-(instancetype) init
{
    if (self = [super init])
    {
        _attribs  = [[NSMutableDictionary alloc] init];
        _children = [[NSMutableArray alloc] init];
    }
    return self;
}

// Extended initializers
-(instancetype) initWithQName:(XMLQName*)qname
     withAttributes:(NSMutableDictionary*)atts
     withDefaultURI:(NSString*)uri
{
    if (self = [self init])
	{
		_name  = [qname copy];
		_defaultURI = [uri copy];
		_attribs = [atts copy];
	}
    return self;
}

-(instancetype) initWithQName:(XMLQName*)qname
{
    return [self initWithQName:qname withDefaultURI:[qname uri]];
}

-(instancetype) initWithQName:(XMLQName*)qname withDefaultURI:(NSString*)uri
{
    if (self = [self init])
	{
		_name  = [qname copy];
		_defaultURI = [uri copy];
	}
    return self;
}

// High-level child initializers

-(XMLElement*) addElement:(XMLElement*)element
{
    [element setParent:self];
    [_children addObject:element];
    return element;
}

-(XMLElement*) addElementWithName:(NSString*)name
{
    return [self addElementWithName:name withDefaultURI:_defaultURI];
}

-(XMLElement*) addElementWithQName:(XMLQName*)name
{
    return [self addElementWithQName:name withDefaultURI:[name uri]];
}

-(XMLElement*) addElementWithName:(NSString*)name withDefaultURI:(NSString*)uri
{
    return [self addElementWithQName:QNAME(uri, name) withDefaultURI:uri];
}

-(XMLElement*) addElementWithQName:(XMLQName*)name withDefaultURI:(NSString*)uri
{
    XMLElement* result;
    if (!uri)
        uri = _defaultURI;

    // Create a new XMLElement node
    result = [[XMLElement alloc] initWithQName:name withDefaultURI:uri];

    // Add the new node to us as a child
    [self addElement:result];

    return result;
}

-(XMLCData*) addCData:(const char*)cdata ofLength:(NSUInteger)cdatasz
{
    // If the last child is a CData object, just append this data to it
    if ([[_children lastObject] isKindOfClass:[XMLCData class]])
    {
        [[_children lastObject] appendText:cdata ofLength:cdatasz];
        return [_children lastObject];
    }
    else
    {
        XMLCData* result = [[XMLCData alloc] initWithCharPtr:cdata ofLength:cdatasz];
        [_children addObject:result];
        return result;
    }
}

-(XMLCData*) addCData:(NSString*)cdata
{
    // If the last child is a CData object, just append this data to it
    if ([[_children lastObject] isKindOfClass:[XMLCData class]])
    {
        [[_children lastObject] appendText:cdata];
        return [_children lastObject];
    }
    else
    {
        XMLCData* result = [[XMLCData alloc] initWithString:cdata];
        [_children addObject:result];
        return result;
    }    
}


// Raw child management
-(void) appendChildNode:(id <XMLNode>)node
{
    [_children addObject:node];
}

-(void) detachChildNode:(id <XMLNode>)node
{
    [_children removeObjectIdenticalTo:node];
}

// Child node info
-(BOOL) hasChildren
{
    return ([_children count] > 0);
}

-(NSUInteger) childCount
{
    return [_children count];
}

// Attribute management
-(void)      putAttribute:(NSString*)name withValue:(NSString*)value
{
    XMLQName* qn = [XMLQName construct:name withURI:_defaultURI];
    _attribs[qn] = value;
}

-(NSString*) getAttribute:(NSString*)name
{
    XMLQName* qn = [XMLQName construct:name withURI:_defaultURI];
    return _attribs[qn];
}

-(void) delAttribute:(NSString*)name
{
    XMLQName* qn = [XMLQName construct:name withURI:_defaultURI];
    [_attribs removeObjectForKey:qn];
}

-(BOOL)  cmpAttribute:(NSString*)name withValue:(NSString*)value
{
    XMLQName* qn = [XMLQName construct:name withURI:_defaultURI];
    return [_attribs[qn] isEqual:value];
}

-(void) putQualifiedAttribute:(XMLQName*)name withValue:(NSString*)value
{
    _attribs[name] = value;
}

-(NSString*) getQualifiedAttribute:(XMLQName*)qname
{
    return _attribs[qname];
}

-(BOOL)  cmpQualifiedAttribute:(XMLQName*)qname withValue:(NSString*)value
{
    return [_attribs[qname] isEqual:value];
}


-(void) delQualifiedAttribute:(XMLQName*)qname
{
    [_attribs removeObjectForKey:qname];
}

// Convert this node to string representation
-(NSString*) description
{
    return [XMLAccumulator process:self];
}

// Implementation of XMLNode protocol
@synthesize qname = _name;

-(NSString*) name
{
    return [_name name];
}

-(NSString*) uri
{
    return [_name uri];
}

-(void) description:(XMLAccumulator*)acc
{
    [acc openElement:self];

    for (id it in _attribs)
    {
        [acc addAttribute:it withValue:_attribs[it] ofElement:self];
    }

	if ([_children count]) {
		[acc addChildren:_children ofElement:self];
		[acc closeElement:self];
	} else {
		[acc selfCloseElement];
	}
}

-(id<XMLNode>) firstChild
{
    return _children[0];
}

-(NSEnumerator*) childElementsEnumerator
{
    NSEnumerator* result = [[_ElementEnumerator alloc] initWithArray:_children];
    return result;
}

// Extract first child CDATA from this Element
-(NSString*) cdata
{
    unsigned int i;
    for (i = 0; i < [_children count]; ++i)
    {
        id curr = _children[i];
        if ([curr isKindOfClass:[XMLCData class]])
            return [curr text];
    }
    return nil;
}

// Convert a name and uri into a XMLQName structure
-(XMLQName*) getQName:(NSString*)name ofURI:(NSString*)uri
{
    return [XMLQName construct:name withURI:uri];
}

-(XMLQName*) getQName:(const char*)expatname
{
    return [XMLQName construct:expatname];
}

-(NSString*) addUniqueIDAttribute
{
    static int UID = 0;
    NSString* result = [NSString stringWithFormat:@"ACID_%d", ++UID];
    [self putAttribute:@"id" withValue:result];
    return result;
}

-(void) setup
{}

-(void) addNamespaceURI:(NSString*)uri withPrefix:(NSString*)prefix
{}

-(void) delNamespaceURI:(NSString*)uri
{}

- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)state objects:(id __unsafe_unretained [])buffer count:(NSUInteger)len
{
    return [[self childElementsEnumerator] countByEnumeratingWithState:state objects:buffer count:len];
}

@end

