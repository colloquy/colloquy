//
//  NSString+MaddsPathExtensions.h
//  Colloquy (Old)
//
//  Created by C.W. Betts on 2/6/17.
//
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSString (MaddsPathExtensions)
- (NSString*)stringByAppendingPathComponents:(NSArray<NSString*>*)components;
@end

@interface NSMutableString (MaddsPathExtensions)
- (void)appendPathComponents:(NSArray<NSString*>*)components;
@end

@interface NSURL (MaddsPathExtensions)
- (nullable NSURL*)URLByAppendingPathComponents:(NSArray<NSString*>*)components;
@end

NS_ASSUME_NONNULL_END
