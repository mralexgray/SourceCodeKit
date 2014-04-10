
#import "SCKSourceFile.h"
#import "SCKTextTypes.h"

#define SUBCLASSNEEDSTO ({ NSLog(@"%@ must implement %@", self.className, NSStringFromSelector(_cmd)); })

@implementation SCKSourceFile @synthesize fileName, source, collection;

+ (SCKSourceFile*)fileUsingIndex:(SCKIndex*)anIdx { return [self.alloc initUsingIndex:anIdx]; }

- (id)initUsingIndex:(SCKIndex *)anIndex { return SUBCLASSNEEDSTO,self = nil; }

- (void) reparse                                { SUBCLASSNEEDSTO; }
- (void) lexicalHighlightFile                   { SUBCLASSNEEDSTO; }
- (void) syntaxHighlightFile                    { SUBCLASSNEEDSTO; }
- (void) syntaxHighlightRange:(NSRange)r        { SUBCLASSNEEDSTO; }
- (void) addIncludePath:(NSString*)includePath  { SUBCLASSNEEDSTO; }
- (void) collectDiagnostics                     { SUBCLASSNEEDSTO; }

- (SCKCodeCompletionResult*) completeAtLocation:(NSUInteger)location { return SUBCLASSNEEDSTO, nil; }

@end

