
@class SCKIndex,SCKSourceFile;

/*! A source collection encapsulates a group of (potentially cross-referenced) source code files. */
@interface SCKSourceCollection : NSObject
{
	NSMutableDictionary *indexes,
                      * files, 	/** Files that have already been created. *///TODO: turn back into NSCache
                      * bundleClasses;
}
@property (nonatomic, readonly, retain) NSMutableDictionary 

  *classes, *bundles, *functions, *globals, *enumerations, *enumerationValues;
  
/*! Generates a new source file object corresponding to the specified on-disk
 * file.  The returned object is not guaranteed to be unique - subsequent calls
 * with the same argument will return the same object. */
- (SCKSourceFile*) sourceFileForPath:(NSString*)aPath;
- (SCKIndex*)  indexForFileExtension:(NSString*)extension;
@end
