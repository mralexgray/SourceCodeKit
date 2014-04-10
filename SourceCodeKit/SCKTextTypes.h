
/*! The type of the token.  This key indicates the type that lexical analysis records for this token.   */
NSString 
* const kSCKTextTokenType,
* const SCKTextTokenTypePunctuation,       /*! Token is punctuation. */
* const SCKTextTokenTypeKeyword,           /*! Token is a keyword. */
* const SCKTextTokenTypeIdentifier,        /*! Token is an identifier. */
* const SCKTextTokenTypeLiteral,           /*! Token is a literal value. */
* const SCKTextTokenTypeComment,           /*! Token is a comment. */
* const kSCKTextSemanticType,              /*! The type that semantic analysis records for this */
* const SCKTextTypeReference,              /*! Reference to a type declared elsewhere. */
* const SCKTextTypeMacroInstantiation,     /*! Instantiation of a macro. */
* const SCKTextTypeMacroDefinition,        /*! Definition of a macro. */
* const SCKTextTypeDeclaration,            /*! A declaration. */
* const SCKTextTypeMessageSend,            /*! A message send expression. */
* const SCKTextTypeDeclRef,                /*! A reference to a declaration. */
* const SCKTextTypePreprocessorDirective,  /*! A preprocessor directive, such as #import or #include. */
* const kSCKDiagnosticSeverity,            /*! The severity of the diagnostic.  An NSNumber from 1 (hint) to 5 (fatal error). */
* const kSCKDiagnosticText,                /*! A human-readable string giving the text of the diagnostic, suitable for display. */
* const kSCKDiagnostic;                    /*! Something is wrong with the text for this range.  
                                               The value for this attribute is a dictionary describing exactly what. */
