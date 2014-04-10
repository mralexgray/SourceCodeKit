//
//  SCKTBAppDelegate.m
//  SCKTestBed
//
//  Created by Alex Gray on 4/10/14.
//  Copyright (c) 2014 Étoile. All rights reserved.
//

#import "SCKTBAppDelegate.h"
#import <SourceCodeKit/SourceCodeKit.h>

@implementation SCKTBAppDelegate { 	SCKSyntaxHighlighter *highlighter; }

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
	NSString *fileName                = @"/Users/localadmin/Desktop/test.m";
	SCKSourceCollection *collection   = [SCKSourceCollection new];
	SCKSourceFile *file               = [collection sourceFileForPath: fileName];
	NSString *sourceString            = [NSString stringWithContentsOfFile: fileName encoding:NSUTF8StringEncoding error:nil];
	NSMutableAttributedString *source = [NSMutableAttributedString.alloc initWithString:sourceString];
	highlighter                       = SCKSyntaxHighlighter.new;
	file.source                       = source;
	[file addIncludePath: @"."];
	[file addIncludePath: @"/usr/local/include"];
	[file addIncludePath: @"/usr/local/GNUstep/Local/Library/Headers"];
	[file addIncludePath: @"/usr/local/GNUstep/System/Library/Headers"];

	clock_t c1 = clock();
	[file reparse];
	[file syntaxHighlightFile];
	clock_t c2 = clock();
	NSLog(@"Syntax highlighting took %f seconds.  .",(CGFloat)(c2 - c1) / CLOCKS_PER_SEC);
	c1 = clock();
	[highlighter transformString: source];
	c2 = clock();
	NSLog(@"Syntax highlighting took %f seconds.  .",(CGFloat)(c2 - c1) / CLOCKS_PER_SEC);

	fileName = [fileName stringByDeletingPathExtension];
	fileName = [fileName stringByAppendingPathExtension: @"rtf"];

  _textView.textStorage.attributedString = source;
	[[source RTFFromRange: NSMakeRange(0, [source length]) documentAttributes: 0] writeToFile: fileName atomically: NO];
	
//  NSLog(@"Source Tree: %@", sourceTree);
}

/* Services */
- (void) openDocumentWithPath: (NSPasteboard *) pboard
                     userData: (NSString *) userData
                        error: (NSString **) error
{
  if ([[pboard types] containsObject: NSStringPboardType])
  {
    /* Should be string */
    NSString *string = [pboard stringForType: NSStringPboardType];
    if (string)
    {
      NSDocumentController *docController = [NSDocumentController sharedDocumentController];
      [docController openDocumentWithContentsOfFile: [string stringByTrimmingCharactersInSet: [NSCharacterSet whitespaceAndNewlineCharacterSet]]
                                            display: YES];
    }
  }
}

- (void) newDocumentWithSelection: (NSPasteboard *) pboard
                         userData: (NSString *) userData
                            error: (NSString **) error
{
  if ([[pboard types] containsObject: NSStringPboardType])
  {
    /* Should be string */
    NSString *string = [pboard stringForType: NSStringPboardType];
    if (string)
    {
      NSDocumentController *docController = [NSDocumentController sharedDocumentController];
//      TWDocument  (TWDocument*)
//      NSTextView *doc = (NSTextView*)[docController openUntitledDocumentOfType: @"TWRTFTextType" display: YES];
//      [doc appen: string];
    }
  }
}

@end
