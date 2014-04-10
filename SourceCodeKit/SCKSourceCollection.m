
#import "SourceCodeKit.h"

static NSDictionary *fileClasses; /*! Mapping from source file extensions to SCKSourceFile subclasses. */

@interface SCKClangIndex : NSObject @end

@implementation SCKSourceCollection

@synthesize bundles;

+ (void)initialize {  	NSMutableDictionary *d = @{}.mutableCopy;

	Class clang = NSClassFromString(@"SCKClangSourceFile");

  d[@"m"] = d[@"cc"] = d[@"c"] = d[@"h"] = d[@"cpp"] = clang; fileClasses = d.copy;
}

- (id)init  {

	self            = super.init;
	indexes         = NSMutableDictionary.new;
	// A single clang index instance for all of the clang-supported file types
	id index        = SCKClangIndex.new;
	indexes[@"m"]   = indexes[@"c"]   = 
  indexes[@"h"]   = indexes[@"cpp"] =
	indexes[@"cc"]  = index;
	files           = NSMutableDictionary.new;
	bundles         = NSMutableDictionary.new;
	bundleClasses   = NSMutableDictionary.new;
	int count       = objc_getClassList(NULL, 0);
	Class *classList = (__unsafe_unretained Class *)calloc(sizeof(Class), count);
	objc_getClassList(classList, count);
	for (int i = 0 ; i < count; i++)
	{
		SCKClass *cls           = [SCKClass.alloc initWithClass:classList[i]];
		bundleClasses[cls.name] = cls;

		NSBundle *b; if (!(b = [NSBundle bundleForClass:classList[i]])) continue;
    
    [((SCKBundle*)bundles[b.bundlePath] ?: ({  SCKBundle *bndl = SCKBundle.new;
    
     bndl.name = b.bundlePath; (SCKBundle *)(bundles[b.bundlePath] = bndl);

    })).classes addObject:cls];
	}
  
	free(classList); return self;
}

- (NSMutableDictionary*)programComponentsFromFilesForKey:(NSString *)key
{
	NSMutableDictionary *components = NSMutableDictionary.new;
	for (SCKSourceFile *file in [files objectEnumerator])
	{
		[components addEntriesFromDictionary:[file valueForKey:key]];
	}
	return components;
}

- (NSDictionary*)classes
{
	NSMutableDictionary* classes = [self programComponentsFromFilesForKey: @"classes"];
	[classes addEntriesFromDictionary: bundleClasses];
	return classes;
}

- (NSDictionary*)functions
{
	return [self programComponentsFromFilesForKey: @"functions"];
}

- (NSDictionary*)enumerationValues
{
	return [self programComponentsFromFilesForKey: @"enumerationValues"];
}

- (NSDictionary*)enumerations
{
	return [self programComponentsFromFilesForKey: @"enumerations"];
}

- (NSDictionary*)globals
{
	return [self programComponentsFromFilesForKey: @"globals"];
}

- (SCKIndex*)indexForFileExtension:(NSString *)extension
{
	return indexes[extension];
}

- (SCKSourceFile*)sourceFileForPath:(NSString *)aPath
{
	NSString *path = [aPath stringByStandardizingPath];
  
  return files[path] ?: ({  	NSString *extension = path.pathExtension;
  
    SCKSourceFile *file = [fileClasses[extension] fileUsingIndex: indexes[extension]];
    file.fileName   = path;
    file.collection = self;
    [file reparse];
    !!file ? files[path] = file : NSLog(@"Failed to load %@", path); file; });
}

@end
