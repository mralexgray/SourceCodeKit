#import "SCKClangSourceFile.h"
#import "SourceCodeKit.h"
#import <Cocoa/Cocoa.h>
#include <time.h>

#define SCOPED_STR(name, value)\
	__attribute__((unused))\
	__attribute__((cleanup(freestring))) CXString name ## str = value;\
	const char __unused *name = clang_getCString(name ## str);

/*! Converts a clang source range into an NSRange within its enclosing file. */
NSRange NSRangeFromCXSourceRange(CXSourceRange sr)  {
	unsigned start, end;
	CXSourceLocation s = clang_getRangeStart(sr);
	CXSourceLocation e = clang_getRangeEnd(sr);
	clang_getInstantiationLocation(s, 0, 0, 0, &start);
	clang_getInstantiationLocation(e, 0, 0, 0, &end);
	if (end < start)
	{
		return NSMakeRange(end, start-end);
	}
	return NSMakeRange(start, end - start);
}
static void           freestring(CXString *str)     {	clang_disposeString(*str); }

@implementation SCKSourceLocation @synthesize file, offset;

- (id) initWithClangSourceLocation:(CXSourceLocation)l 
{
	if (self != super.init ) return nil;  CXFile f;  unsigned o;
  
  clang_getInstantiationLocation(l, &f, 0, 0, &o);  offset = o;
  SCOPED_STR(fileName, clang_getFileName(f));
  file = [NSString.alloc initWithUTF8String:fileName];	return self;
}
- (NSString*) description   { return [NSString stringWithFormat:@"%@:%d", file, (int)offset]; }
- (NSUInteger) hash         { return file.hash ^ offset; }
- (BOOL) isEqual:(id)object { 

  return object == self ?: ![object isKindOfClass:SCKSourceLocation.class] ? NO : 
                            [file isEqualToString:[(SCKSourceLocation *)object file]] && 
                            offset == [(SCKSourceLocation *)object offset]; 
}
@end

@interface SCKClangIndex : NSObject
@property (readonly) CXIndex clangIndex;
//FIXME: We should have different default arguments for C, C++ and ObjC.
@property (nonatomic) NSMutableArray *defaultArguments;
@end

@implementation SCKClangIndex @synthesize clangIndex, defaultArguments;

- (id)init { if (self != super.init ) return nil;
  
  clang_toggleCrashRecovery(0);
  clangIndex = clang_createIndex(1, 1);

  /* NOTE: If BuildKit becomes usable, it might be sensible to store these defaults in the BuildKit configuration 
      and let BuildKit generate the command line switches for us.  */
      
  NSString *plistPath = [[NSBundle bundleForClass:SCKClangIndex.class] pathForResource:@"DefaultArguments" ofType:@"plist"];
  NSData *plistData   = [NSData dataWithContentsOfFile:plistPath];

  // Load the options required to compile GNUstep apps
  defaultArguments = [(NSArray*)[NSPropertyListSerialization propertyListFromData:plistData
                                                                 mutabilityOption:NSPropertyListImmutable
                                                                           format:NULL
                                                                 errorDescription:NULL] mutableCopy];
	return self;
}
- (void)dealloc {
	clang_disposeIndex(clangIndex);
}
@end

@interface SCKClangSourceFile ()
- (void)highlightRange:(CXSourceRange)r syntax:(BOOL)highightSyntax;
@end

@implementation SCKClangSourceFile {
	NSMutableArray *args;               /** Compiler arguments */
	SCKClangIndex *idx;                 /** Index shared between code files */
	CXTranslationUnit translationUnit; 	/** libclang translation unit handle. */
	CXFile file;
} @synthesize classes, functions, globals, enumerations, enumerationValues;

static NSString *classNameFromCategory(CXCursor category) {
	__block NSString *className = nil;
	clang_visitChildrenWithBlock(category, ^ enum CXChildVisitResult (CXCursor cursor, CXCursor parent) {
        if (CXCursor_ObjCClassRef == cursor.kind)
        {
            SCOPED_STR(name, clang_getCursorSpelling(cursor));
            className = @(name);
            return CXChildVisit_Break;
        }
        return CXChildVisit_Continue;
    });
	return className;
}

-   (id) initUsingIndex:(SCKIndex*)anIndex  {
	if (self != super.init ) return nil;
  idx = (SCKClangIndex*)anIndex;
  NSAssert([idx isKindOfClass:SCKClangIndex.class], @"Initializing SCKClangSourceFile with incorrect kind of index");
  args = idx.defaultArguments.mutableCopy;
  classes = NSMutableDictionary.new;
  functions = NSMutableDictionary.new;
  globals = NSMutableDictionary.new;
  enumerations = NSMutableDictionary.new;
  enumerationValues = NSMutableDictionary.new; return self;
}

- (void) setLocation:(SCKSourceLocation*)aLocation
           forMethod:(NSString*)methodName
             inClass:(NSString*)className
            category:(NSString*)categoryName
        isDefinition:(BOOL)isDefinition        {
	SCKClass *cls = classes[className];
	if (nil == cls)
	{
		cls = [SCKClass new];
		cls.name = className;
		classes[className] = cls;
	}
    
	NSMutableDictionary *methods = cls.methods;
	if (nil != categoryName)
	{
		SCKCategory *cat = (cls.categories)[categoryName];
		if (nil == cat)
		{
			cat = [SCKCategory new];
			cat.name = categoryName;
			cat.parent = cls;
			(cls.categories)[categoryName] = cat;
		}
		methods = cat.methods;
	}
    
	SCKMethod *m = methods[methodName];
	if (isDefinition)
	{
		m.definition = aLocation;
	}
	else
	{
		m.declaration = aLocation;
	}
}

- (void) setLocation:(SCKSourceLocation*)l
           forGlobal:(const char*)name
            withType:(const char*)type
          isFunction:(BOOL)isFunction
        isDefinition:(BOOL)isDefinition        {
	NSMutableDictionary *dict = isFunction ? functions : globals;
	NSString *symbol = @(name);

	SCKTypedProgramComponent *global = dict[symbol];
	SCKTypedProgramComponent *g = nil;
	if (nil == global)
	{
		g = isFunction ? [SCKFunction new] : [SCKGlobal new];
		global = g;
		global.name = symbol;
		[global setTypeEncoding:@(type)];
	}
    
	if (isDefinition)
	{
		global.definition = l;
	}
	else
	{
		global.declaration = l;
	}

	dict[symbol] = global;
}

- (void) rebuildIndex {
	if (0 == translationUnit)
    {
        return;
    }
    
	clang_visitChildrenWithBlock(clang_getTranslationUnitCursor(translationUnit), ^ enum CXChildVisitResult (CXCursor cursor, CXCursor parent) {
        switch(cursor.kind)
        {
            default:
                break;
            case CXCursor_ObjCImplementationDecl: {
                clang_visitChildrenWithBlock(clang_getTranslationUnitCursor(translationUnit), ^ enum CXChildVisitResult (CXCursor cursor, CXCursor parent) {
                    if (CXCursor_ObjCInstanceMethodDecl == cursor.kind)
                    {
                        SCOPED_STR(methodName, clang_getCursorSpelling(cursor));
                        SCOPED_STR(className, clang_getCursorSpelling(parent));
                        //clang_visitChildren((parent), findClass, NULL);
                        SCKSourceLocation *l = [[SCKSourceLocation alloc] initWithClangSourceLocation:clang_getCursorLocation(cursor)];
                        [self setLocation:l
                                forMethod:@(methodName)
                                  inClass:@(className)
                                 category:nil
                             isDefinition:clang_isCursorDefinition(cursor)];
                    }
                    return CXChildVisit_Continue;
                });
                break;
            }
            case CXCursor_ObjCCategoryImplDecl: {
                clang_visitChildrenWithBlock(clang_getTranslationUnitCursor(translationUnit), ^ enum CXChildVisitResult (CXCursor cursor, CXCursor parent) {
                    if (CXCursor_ObjCInstanceMethodDecl == cursor.kind)
                    {
                        SCOPED_STR(methodName, clang_getCursorSpelling(cursor));
                        SCOPED_STR(categoryName, clang_getCursorSpelling(parent));
                        NSString *className = classNameFromCategory(parent);
                        SCKSourceLocation *l = [[SCKSourceLocation alloc] initWithClangSourceLocation:clang_getCursorLocation(cursor)];
                        [self setLocation:l
                                forMethod:@(methodName)
                                  inClass:className
                                 category:@(categoryName)
                             isDefinition:clang_isCursorDefinition(cursor)];
                    }
                    return CXChildVisit_Continue;
                });
                break;
            }
            case CXCursor_FunctionDecl:
            case CXCursor_VarDecl: {
                if (clang_getCursorLinkage(cursor) == CXLinkage_External)
                {
                    SCOPED_STR(name, clang_getCursorSpelling(cursor));
                    SCOPED_STR(type, clang_getDeclObjCTypeEncoding(cursor));
                    SCKSourceLocation *l = [[SCKSourceLocation alloc] initWithClangSourceLocation:clang_getCursorLocation(cursor)];
                    [self setLocation:l
                            forGlobal:name
                             withType:type
                           isFunction:(cursor.kind == CXCursor_FunctionDecl)
                         isDefinition:clang_isCursorDefinition(cursor)];
                }
                break;
            }
//#pragma clang diagnostic push
//#pragma clang diagnostic ignored "-Wprotocol"
            case CXCursor_EnumDecl: {
                SCOPED_STR(enumName, clang_getCursorSpelling(cursor));
                SCOPED_STR(type, clang_getDeclObjCTypeEncoding(cursor));
                NSString *name = @(enumName);
                SCKEnumeration *e = enumerations[name];
                
                __block BOOL foundType;
                if (e == nil)
                {
                    e = [SCKEnumeration new];
                    foundType = NO;
                    e.name = name;
                    e.declaration = [[SCKSourceLocation alloc] initWithClangSourceLocation:clang_getCursorLocation(cursor)];
                }
                else
                {
                    foundType = e.typeEncoding != nil;
                }
                
                clang_visitChildrenWithBlock(cursor, ^ enum CXChildVisitResult (CXCursor enumCursor, CXCursor parent) {
                    if (enumCursor.kind == CXCursor_EnumConstantDecl)
                    {
                        if (!foundType)
                        {
                            SCOPED_STR(type, clang_getDeclObjCTypeEncoding(enumCursor));
                            foundType = YES;
                            e.typeEncoding = @(type);
                        }
                        SCOPED_STR(valName, clang_getCursorSpelling(enumCursor));
                        NSString *vName = @(valName);
                        
                        SCKEnumerationValue *v = (e.values)[vName];
                        if (nil == v)
                        {
                            v = [SCKEnumerationValue new];
                            v.name = vName;
                            v.declaration = [[SCKSourceLocation alloc] initWithClangSourceLocation:clang_getCursorLocation(enumCursor)];
                            v.longLongValue = clang_getEnumConstantDeclValue(enumCursor);
                            (e.values)[vName] = v;
                        }
                        
                        SCKEnumerationValue *ev = enumerationValues[vName];
                        if (ev)
                        {
                            if (ev.longLongValue != v.longLongValue)
                            {
                                enumerationValues[vName] = [NSMutableArray arrayWithObjects:v, ev, nil];
                            }
                        }
                        else
                        {
                            enumerationValues[vName] = v;
                        }
                    }
                    return CXChildVisit_Continue;
                });
                break;
            }
        }
        return CXChildVisit_Continue;
    });
}

- (void) addIncludePath:(NSString*)includePath {
	[args addObject:[NSString stringWithFormat:@"-I%@", includePath]];
	// After we've added an include path, we may change how the file is parsed,
	// so parse it again, if required
	if (NULL != translationUnit)
	{
		clang_disposeTranslationUnit(translationUnit);
		translationUnit = NULL;
		[self reparse];
	}
}
- (void) dealloc {
	if (NULL != translationUnit)
	{
		clang_disposeTranslationUnit(translationUnit);
	}
}
- (void) reparse {
	const char *fn = self.fileName.UTF8String;
	struct CXUnsavedFile unsaved[] = {{fn, self.source.string.UTF8String, self.source.length},
                                    {NULL, NULL, 0}};
    
	int unsavedCount = !!self.source;
    
	const char *mainFile = fn;
	if ([@"h" isEqualToString:self.fileName.pathExtension])
	{
		unsaved[unsavedCount].Filename = "/tmp/foo.m";
		unsaved[unsavedCount].Contents = [NSString stringWithFormat:@"#import \"%@\"\n", self.fileName].UTF8String;
		unsaved[unsavedCount].Length = strlen(unsaved[unsavedCount].Contents);
		mainFile = unsaved[unsavedCount].Filename;
		unsavedCount++;
	}
    
	file = NULL;
	if (NULL == translationUnit)
	{
		int argc = (int)[args count];
		const char *argv[argc];
		int i=0;
		for (NSString *arg in args)
		{
			argv[i++] = [arg UTF8String];
		}
		translationUnit =clang_parseTranslationUnit(idx.clangIndex,
                                                    mainFile, argv, argc, unsaved,
                                                    unsavedCount,
                                                    clang_defaultEditingTranslationUnitOptions());
		file = clang_getFile(translationUnit, fn);
	}
	else
	{
		if (0 != clang_reparseTranslationUnit(translationUnit, unsavedCount, unsaved, clang_defaultReparseOptions(translationUnit)))
		{
			clang_disposeTranslationUnit(translationUnit);
			translationUnit = 0;
		}
		else
		{
			file = clang_getFile(translationUnit, fn);
		}
	}
	[self rebuildIndex];
}
- (void) lexicalHighlightFile {
	CXSourceLocation start = clang_getLocation(translationUnit, file, 1, 1);
	CXSourceLocation end = clang_getLocationForOffset(translationUnit, file, (unsigned int)self.source.length);
	[self highlightRange:clang_getRange(start, end) syntax:NO];
}
- (void) highlightRange:(CXSourceRange)r syntax:(BOOL)highightSyntax {
	NSString *TokenTypes[] = {
        SCKTextTokenTypePunctuation,
        SCKTextTokenTypeKeyword,
		SCKTextTokenTypeIdentifier,
        SCKTextTokenTypeLiteral,
		SCKTextTokenTypeComment
    };
    
	if (clang_equalLocations(clang_getRangeStart(r), clang_getRangeEnd(r)))
	{
		NSLog(@"Range has no length!");
		return;
	}
    
	CXToken *tokens;
	unsigned tokenCount;
	clang_tokenize(translationUnit, r , &tokens, &tokenCount);

	if (tokenCount > 0)
	{
		CXCursor *cursors = NULL;
		if (highightSyntax)
		{
			cursors = calloc(sizeof(CXCursor), tokenCount);
			clang_annotateTokens(translationUnit, tokens, tokenCount, cursors);
		}
        
		for (unsigned i = 0 ; i < tokenCount ; i++)
		{
			CXSourceRange sr = clang_getTokenExtent(translationUnit, tokens[i]);
			NSRange range = NSRangeFromCXSourceRange(sr);
			if (range.location > 0)
			{
				if ([self.source.string characterAtIndex:range.location - 1] == '@')
				{
					range.location--;
					range.length++;
				}
			}
            
			if (highightSyntax)
			{
				id type;
				switch (cursors[i].kind)
				{
					case CXCursor_FirstRef... CXCursor_LastRef:
						type = SCKTextTypeReference;
						break;
					case CXCursor_MacroDefinition:
						type = SCKTextTypeMacroDefinition;
						break;
					case CXCursor_MacroInstantiation:
						type = SCKTextTypeMacroInstantiation;
						break;
					case CXCursor_FirstDecl...CXCursor_LastDecl:
						type = SCKTextTypeDeclaration;
						break;
					case CXCursor_ObjCMessageExpr:
						type = SCKTextTypeMessageSend;
						break;
					case CXCursor_DeclRefExpr:
						type = SCKTextTypeDeclRef;
						break;
					case CXCursor_PreprocessingDirective:
						type = SCKTextTypePreprocessorDirective;
						break;
					default:
						type = nil;
				}
                
				if (nil != type)
				{
					[self.source addAttribute:kSCKTextSemanticType
								   value:type
								   range:range];
				}
			}
			[self.source addAttribute:kSCKTextTokenType
			               value:TokenTypes[clang_getTokenKind(tokens[i])]
			               range:range];
		}
		clang_disposeTokens(translationUnit, tokens, tokenCount);
		free(cursors);
	}
}
- (void) syntaxHighlightRange:(NSRange)r  {
	CXSourceLocation start  = clang_getLocationForOffset(translationUnit, file, (unsigned int)r.location);
	CXSourceLocation end    = clang_getLocationForOffset(translationUnit, file, (unsigned int)r.location + (unsigned int)r.length);
	[self highlightRange:clang_getRange(start, end) syntax:YES];
}
- (void) syntaxHighlightFile  {
	[self syntaxHighlightRange:NSMakeRange(0,self.source.length)];
}
- (void) collectDiagnostics   {

	unsigned diagnosticCount  = clang_getNumDiagnostics(translationUnit);
	unsigned __unused opts    = clang_defaultDiagnosticDisplayOptions();
    
	for (unsigned i=0 ; i<diagnosticCount ; i++) 	{
  
		CXDiagnostic d  = clang_getDiagnostic(translationUnit, i);
		unsigned s      = clang_getDiagnosticSeverity(d);

		if (!s) continue;
    CXString str          = clang_getDiagnosticSpelling(d);
    CXSourceLocation loc  = clang_getDiagnosticLocation(d);
    unsigned rangeCount   = clang_getDiagnosticNumRanges(d);
          
    if (rangeCount == 0) {    //FIXME: probably somewhat redundant
    
      SCKSourceLocation* sloc = [SCKSourceLocation.alloc initWithClangSourceLocation:loc];
      [self.source addAttribute:kSCKDiagnostic
                     value:@{kSCKDiagnosticSeverity: @(s),
                                     kSCKDiagnosticText: @(clang_getCString(str))}
                     range:NSMakeRange(sloc.offset, 1)];
    }
    for (unsigned j=0 ; j<rangeCount ; j++)
      [self.source addAttribute:kSCKDiagnostic 
                          value:@{kSCKDiagnosticSeverity: @(s), //kSCKDiagnostic
                                      kSCKDiagnosticText: @(clang_getCString(str))} 
                          range:NSRangeFromCXSourceRange(clang_getDiagnosticRange(d, j))];
    clang_disposeString(str);
	}
}
- (SCKCodeCompletionResult*) completeAtLocation:(NSUInteger)location {
	SCKCodeCompletionResult *result = [SCKCodeCompletionResult new];

	struct CXUnsavedFile unsavedFile;
	unsavedFile.Filename = self.fileName.UTF8String;
	unsavedFile.Contents = self.source.string.UTF8String;
	unsavedFile.Length = self.source.string.length;

	CXSourceLocation l = clang_getLocationForOffset(translationUnit, file, (unsigned)location);
	unsigned line, column;
	clang_getInstantiationLocation(l, file, &line, &column, 0);
	clock_t c1 = clock();

	int options = CXCompletionContext_AnyType |
			CXCompletionContext_AnyValue |
			CXCompletionContext_ObjCInterface;

	CXCodeCompleteResults *cr = clang_codeCompleteAt(translationUnit, self.fileName.UTF8String, line, column, &unsavedFile, 1, options);
	clock_t c2 = clock();
	NSLog(@"Complete time: %f\n", 
	((double)c2 - (double)c1) / (double)CLOCKS_PER_SEC);
	for (unsigned i = 0 ; i < clang_codeCompleteGetNumDiagnostics(cr); i++)
	{
		CXDiagnostic d = clang_codeCompleteGetDiagnostic(cr, i);
		unsigned fixits = clang_getDiagnosticNumFixIts(d);
		printf("Found %d fixits\n", fixits);
		if (1 == fixits)
		{
			CXSourceRange r;
			CXString str = clang_getDiagnosticFixIt(d, 0, &r);
			result.fixitRange = NSRangeFromCXSourceRange(r);
			result.fixitText = [[NSString alloc] initWithUTF8String:clang_getCString(str)];
			clang_disposeString(str);
			break;
		}
		clang_disposeDiagnostic(d);
	}
	NSMutableArray *completions = [NSMutableArray new];
	clang_sortCodeCompletionResults(cr->Results, cr->NumResults);

	for (unsigned i = 0 ; i < cr->NumResults; i++)
	{
		CXCompletionString cs = cr->Results[i].CompletionString;
		NSMutableAttributedString *completion = [NSMutableAttributedString new];
		NSMutableString *s = [completion mutableString];
		unsigned chunks = clang_getNumCompletionChunks(cs);
		for (unsigned j=0 ; j<chunks ; j++)
		{
			switch (clang_getCompletionChunkKind(cs, j))
			{
				case CXCompletionChunk_Optional:
				case CXCompletionChunk_TypedText:
				case CXCompletionChunk_Text:
				{
					CXString str = clang_getCompletionChunkText(cs, j);
					[s appendFormat:@"%s", clang_getCString(str)];
					clang_disposeString(str);
					break;
				}
				case CXCompletionChunk_Placeholder:
				{
					CXString str = clang_getCompletionChunkText(cs, j);
					[s appendFormat:@" %s ", clang_getCString(str)];
					clang_disposeString(str);
					break;
				}
				case CXCompletionChunk_Informative:
				{
					CXString str = clang_getCompletionChunkText(cs, j);
					[s appendFormat:@"/* %s */", clang_getCString(str)];
					clang_disposeString(str);
					break;
				}
				case CXCompletionChunk_CurrentParameter:
				case CXCompletionChunk_LeftParen:
					[s appendString:@"("];
                    break;
				case CXCompletionChunk_RightParen:
					[s appendString:@"("];
                    break;
				case CXCompletionChunk_LeftBracket:
					[s appendString:@"["];
                    break;
				case CXCompletionChunk_RightBracket:
					[s appendString:@"]"];
                    break;
				case CXCompletionChunk_LeftBrace:
					[s appendString:@"{"];
                    break;
				case CXCompletionChunk_RightBrace:
					[s appendString:@"}"];
                    break;
				case CXCompletionChunk_LeftAngle:
					[s appendString:@"<"];
                    break;
				case CXCompletionChunk_RightAngle:
					[s appendString:@">"];
                    break;
				case CXCompletionChunk_Comma:
					[s appendString:@","];
                    break;
				case CXCompletionChunk_ResultType:
					break;
				case CXCompletionChunk_Colon:
					[s appendString:@":"];
                    break;
				case CXCompletionChunk_SemiColon:
					[s appendString:@";"];
                    break;
				case CXCompletionChunk_Equal:
					[s appendString:@"="];
                    break;
				case CXCompletionChunk_HorizontalSpace:
					[s appendString:@" "];
                    break;
				case CXCompletionChunk_VerticalSpace:
					[s appendString:@"\n"];
                    break;
			}
		}
		[completions addObject:completion];
	}
	result.completions = completions;
	clang_disposeCodeCompleteResults(cr);
	return result;
}

@end

