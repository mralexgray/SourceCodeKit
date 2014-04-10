
#import <SourceCodeKit/SCKSourceFile.h>
#import <clang-c/Index.h>

@class SCKClangIndex;

/*! SCKSourceFile implementation that uses clang to perform handle [Objective-]C[++] files. */

@interface SCKClangSourceFile : SCKSourceFile

@property (nonatomic) NSMutableDictionary *classes, *functions, *globals, 
                                           *enumerations, *enumerationValues;
@end
