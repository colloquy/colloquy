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
//     Copyright (C) 2002 David Waite (mass@akuma.org)
// 
// $Id: acid-xpath.h,v 1.1 2004/07/19 03:49:04 jtownsend Exp $
//============================================================================

/*!
  @header acid-xpath.
  @abstract implements XPath-based querying
*/
#import <Foundation/NSObject.h>
#import <Foundation/NSString.h>

/*!
  @class NSMutableString (_ACID_EXT)
  @abstract adds tokenization and range removal to NSMutableString
*/
@interface NSMutableString (_ACID_EXT)
/*!
  @method nextTokenDelimitedBy
  @abstract return a substring up to one of the tokens specified
  @param tokens  string holding nondelimited characters to be used as tokens
  @param substring, or an empty string on failure
*/
-(NSString*) nextTokenDelimitedBy:(NSString*)tokens;
/*!
  @method nextTokenDelimitedBy:searchFromIndex
  @abstract return a substring from a starting index up to one of the
  tokens specified
  @param tokens  string holding nondelimited characters to be used as tokens
  @param substring, or an empty string on failure
*/
-(NSString*) nextTokenDelimitedBy:(NSString*)tokens searchFromIndex:(int)index;
/*!
  @method deleteCharactersFromIndex:toIndex
  @abstract remove a range of characters from within the string
*/
-(void) deleteCharactersFromIndex:(int)start toIndex:(int)end;
/*!
  @method clear
  @abstract reset to an empty string
*/
-(void) clear;
@end

@class XMLElement;

/*!
  @class XPLocation
  @abstract class representing a location within a document
*/
@interface XPLocation : NSObject
{
    XPLocation*     _next;
    NSMutableArray* _predicates;
    NSString*       _elementName;
    NSString*       _attributeName;
}

+(id) createWithPath:(NSString*)path;

-(BOOL) checkPredicates:(XMLElement*)elem;

-(BOOL) matches:(XMLElement*)elem;
-(void) queryForString:(XMLElement*)elem withResultBuffer:(NSMutableString*)result;
-(void) queryForList:(XMLElement*)elem withResultArray:(NSMutableArray*)result;
-(void) queryForStringList:(XMLElement*)elem withResultArray:(NSMutableArray*)result;
//-(XMLCData*) queryForCData:(XMLElement*)elem;

@end

@interface XPPredicate : NSObject
+(XPPredicate *) createWithToken:(NSMutableString*)pathtoken;
+(XPPredicate *) createAttributeExists:(NSString*)attributeName;

-(BOOL) matches:(XMLElement*)elem;
@end

@interface XPathQuery : NSObject {
    NSString*        _path;
    id               _expression;
}

-(id) initWithPath:(NSString*)path;
-(void) dealloc;

-(NSString*) path;

-(BOOL)       matches:(XMLElement*)elem;
-(NSString*)  queryForString:(XMLElement*)elem;
-(NSArray*)   queryForList:(XMLElement*)elem;
-(NSArray*)   queryForStringList:(XMLElement*)elem;

+(BOOL)       matches:(XMLElement*)elem xpath:(NSString*)path;
+(NSString*)  queryForString:(XMLElement*)elem xpath:(NSString*)path;
+(NSArray*)   queryForList:(XMLElement*)elem xpath:(NSString*)path;
+(NSArray*)   queryForStringList:(XMLElement*)elem xpath:(NSString*)path;
@end
