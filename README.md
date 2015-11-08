# LiterateScript
An experimental language that can parse natural language key-phrases and provides many shorthand alternatives.

Currently, much of the functionality is limited to a sql-like syntax for manipulating database-like objects.
Here are some working (tested) examples.
  
  Let add2 of x and y equal x plus y. -- This is an end-of-line comment
  Call add2 with 2 and 3 (this is an in-line comment).
  
This will create a method "add2" that accepts two parameters and adds them.

  Add test with title as Example and date as 11/8/15 (this will be automatically saved as a date type).
  
This creates a "test" collection and adds a "test" object with a title and a date.

  Let bestVariable equal NewName.
  Set title to bestVariable in tests where title is Example and date is greater than 1/1/15.
  Print tests where title is bestVariable.
  
Assuming you have created some tests with "add test", running this will update the title of all "Example" titled tests to "NewName".
Print does the same as read, but displays it using console.log before returning it.
  
You can see more working examples in the tests at the end of the script.
