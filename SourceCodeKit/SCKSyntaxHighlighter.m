
#import "SCKTextTypes.h"
#import "SCKSyntaxHighlighter.h"
#include <time.h>

static NSDictionary *noAttributes;

@implementation SCKSyntaxHighlighter @synthesize tokenAttributes, semanticAttributes;

+ (void)initialize { static dispatch_once_t once = 0L;
    dispatch_once(&once, ^{ noAttributes = NSDictionary.new; });
}

- (id)init {
	self = [super init];
	NSDictionary *comment = @{NSForegroundColorAttributeName: [NSColor grayColor]},
               *keyword = @{NSForegroundColorAttributeName: [NSColor redColor]},
               *literal = @{NSForegroundColorAttributeName: [NSColor redColor]};
	tokenAttributes = [@{
                       SCKTextTokenTypeComment: comment,
                       SCKTextTokenTypePunctuation: noAttributes,
                       SCKTextTokenTypeKeyword: keyword,
                       SCKTextTokenTypeLiteral: literal}
                       mutableCopy];

	semanticAttributes = [@{
                          SCKTextTypeDeclRef: @{NSForegroundColorAttributeName: [NSColor blueColor]},
                          SCKTextTypeMessageSend: @{NSForegroundColorAttributeName: [NSColor brownColor]},
                          SCKTextTypeDeclaration: @{NSForegroundColorAttributeName: [NSColor greenColor]},
                          SCKTextTypeMacroInstantiation: @{NSForegroundColorAttributeName: [NSColor magentaColor]},
                          SCKTextTypeMacroDefinition: @{NSForegroundColorAttributeName: [NSColor magentaColor]},
                          SCKTextTypePreprocessorDirective: @{NSForegroundColorAttributeName: [NSColor orangeColor]},
                          SCKTextTypeReference: @{NSForegroundColorAttributeName: [NSColor purpleColor]}}
                          mutableCopy];
	return self;
}

- (void)transformString:(NSMutableAttributedString *)source;
{
	NSUInteger end = [source length];
	NSUInteger i = 0;
	NSRange r;
	do
	{
		NSDictionary *attrs = [source attributesAtIndex:i
		                          longestEffectiveRange:&r
		                                        inRange:NSMakeRange(i, end-i)];
		i = r.location + r.length;
        
		NSString *token = attrs[kSCKTextTokenType];
		NSString *semantic = attrs[kSCKTextSemanticType];
		NSDictionary *diagnostic = attrs[kSCKDiagnostic];
        
		// Skip ranges that have attributes other than semantic markup
		if ((nil == semantic) && (nil == token)) continue;
		attrs = 
    semantic == SCKTextTypePreprocessorDirective  ? semanticAttributes[semantic] :
    !token || token != SCKTextTokenTypeIdentifier ?    tokenAttributes[token] :
                                                    semanticAttributes[kSCKTextSemanticType]
                                                  ?:      noAttributes;
		[source setAttributes:attrs range:r];
        
		// Re-apply the diagnostic
		if (!!diagnostic)	{
    
			[source addAttribute:NSToolTipAttributeName
			               value:diagnostic[kSCKDiagnosticText]
			               range:r];
			[source addAttribute:NSUnderlineStyleAttributeName
                           value:@(NSSingleUnderlineStyle)
                           range:r];
			[source addAttribute:NSUnderlineColorAttributeName
			               value:[NSColor redColor]
			               range:r];
		}
	} while (i < end);
}

@end

