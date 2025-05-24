package math

import common "../common" // Provides access to common.Engine_Error

// Math-specific error helper functions can be added here if needed.
// For now, this file ensures that the math package correctly refers to 
// the centralized Engine_Error in the common package.
// Other files in the 'math' package that need Engine_Error should:
// 1. Import 'common' directly: import common "../../common" (or appropriate path)
// 2. Or, if they import this 'error.odin' file (e.g. import . "error.odin"), 
//    they would use 'common.Engine_Error'.
// It's generally better for modules to directly import the packages they need.
