Literate = new ->
  ###
  -- Possible queries
  Read date from post's latest's dateItem.
  Read title from post where it's date is greater than 01/18/1991.
  
  Read title, content, and date, ordered ascending by date 
  from post where the date is greater than 1/1/2001.

  binder = Literate.eval("When date in map is greater than 1/1/2016")
  binder (object, query) -> object.date = new Date()
  ###
  
  _ = @
  @database = {}
  @namespaces = global:{}
  
  init = (collection) =>
    @database[collection] = []
  
  transformCollectionName = (name) ->
    if name[name.length - 1] is 's' and
       name[name.length - 2] isnt 's'
         name.slice 0, name.length - 1
    else name
  
  selectType = (val) ->
    isDate = /^\d{1,2}\/\d{1,2}\/\d{2,4}$/.test val
    isNum = not isNaN val
    # TODO isArray
    return if isDate then new Date val
    else if isNum then Number val
    else val
  
  write = (collection, objs...) =>
    try
    	if not @database[collection] then init collection
    	(@database[collection].push obj) for obj in objs
    catch e then return err:e

  read = (collection, query) =>
    @database[collection]?.filter (obj) ->
      results = []
      for prop, expr of query
        for val in expr
          if typeof val is 'object'
            for mod, subVal of val
              result = if mod is "<" then obj[prop] < subVal
              else if mod is ">" then obj[prop] > subVal
              else true
              results.push result
          else unless obj[prop] is val then return false
      return results.length is 0 or results.every (flag) -> flag
  
  update = (collection, query, newVals) =>
    if not @database[collection] then init collection
    (read collection, query)?.map (obj) ->
        (obj[prop] = val) for prop, val of newVals
        return obj
  
  remove = (collection, query) =>
    if @database[collection]
    	@database[collection] = @database[collection].filter (obj) ->
	      for prop, val of query
	        return if obj[prop] is val then false else true
  
  @eval = (query) ->
    # Find and remove comments
    query = query.replace /\(.+\)/g, ''
    query = query.replace /\-\-.+\S/g,''
    
    # Get each sentance (each query)
    expressions = query.split('.')
    
    results = []
    for expression in expressions
      subQuery = expression
      regex =
        first: /^\s?(.+?)\b/
        map: /^\s?(from|to|into|new)?\s?(.+?)\b/
        
      get =
        first: (str) -> str.match(regex.first)[1]
        # Only after removing first operation/keyword
        map: (str) -> str.match(regex.map)[2]
      
      operation = (get.first subQuery).toLowerCase()
      subQuery = subQuery.replace regex.first, ''
      
      getName = (query) ->
        name = get.map query
        ind = query.indexOf name
        query = query.slice ind + name.length
        [query, name]
      
      getCollection = (query) ->
        [query, collection] = getName query
        [query, transformCollectionName collection]
      
      switch operation
        
        # -------------------------------------------------------------------------------------
        # TODO:
        # - map specific properties
        # - nested properties
        
        when 'read', 'get', 'print'
          [subQuery, collection] = getCollection subQuery
          [queryExpression, modifierExpressions...] = subQuery.split 'then'
          
          query = {}
          queryRgx = new RegExp /\s?(\d)\s(<|>)\s(.+?)\s(<|>)\s(\d)\s?/g # e.g; 3 < number < 9
          while match = queryRgx.exec queryExpression
            [match, num1, mod1, name, mod2, num2] = match
            o1 = {}
            o2 = {}
            o1[if mod1 is '<' then '>' else '<'] = num1
            o2[mod2] = num2
            modifiers = [o1, o2]
            
            if not query[name]? then query[name] = []
            query[name] = query[name].concat modifiers
            
            ind = queryExpression.indexOf match
            queryExpression = (queryExpression.slice 0, ind) +
              (queryExpression.slice ind + match.length)
            
          
          queryRgx = new RegExp /\s?(where|if|for|and|or|,)?\s?(\S+?)\s?(\:|is|<|>)\s?(lesser than|less than|<)?(greater than|>)?\s?(\S+?)\b/g
          while match = queryRgx.exec queryExpression
            [match, s1, name, mod, lesser, greater, value] = match
            #console.log match:match
            value = selectType _.namespaces.global[value] or value
            subExpression =
              if lesser or mod is '<' then "<": value
              else if greater or mod is '>' then ">": value
              else value
            
            if not query[name]? then query[name] = []
            query[name].push subExpression
          
          result = read collection, query
          
          if /\b(\S+)(\+|\-)\b/g.test queryExpression
            modRgx = new RegExp /\b(\S+)(\+|\-)\b/g
            while match = modRgx.exec queryExpression
              [match, name, symbol] = match
              
              direction =
                if symbol is '+' then 1
                else if symbol is '-' then -1
                else throw new Error "Unexpected symbol #{symbol} in query: '#{expression}'"
                
              result = result.sort (a, b) ->
                return if a[name] > b[name] then direction
                else if a[name] < b[name] then -direction else 0
                  
              ind = queryExpression.indexOf match # TODO Make method
              queryExpression = (queryExpression.slice 0, ind) + (queryExpression.slice ind + match.length)
          
          # Run all modifier "then" expressions
          for mod in modifierExpressions
            modRgx = new RegExp /\s?(order by)\s(.+?)\b\s?(descending)?/g
            while match = modRgx.exec mod
              [match, s1, name, dsc] = match
              
              direction = unless dsc is 'descending' then 1 else -1
              result = result.sort (a, b) ->
                return if a[name] > b[name] then direction
                else if a[name] < b[name] then -direction else 0
          
          if operation is 'print' then console.info
          {expression, result: JSON.stringify result}
          
        # -------------------------------------------------------------------------------------
        when 'write', 'add', 'insert'
          [subQuery, collection] = getCollection subQuery
          
          object = {}
          queryRgx = new RegExp /\s?(with|where|for|and|or)?\s?\b(.+?)\s?(\:|is|as)\s?(\d{1,2}\/\d{1,2}\/\d{2,4}|.+?)?\b/g
          while match = queryRgx.exec subQuery
            [match, s1, name, s2, value] = match
            
            value = selectType _.namespaces.global[value] or value
            object[name] = value
          
          result = write collection, object
        
        # -------------------------------------------------------------------------------------
        when 'set', 'update'
          queryRgx = new RegExp /\s?(in|for)\s(.+?)\b/g
          match = queryRgx.exec subQuery
          
          if match[1] isnt 'in' and match[1] isnt 'for'
            msg = "Update expressions require '[in|for] <collection>' to know which collection to update."
            throw new Error msg
          
          collection = match[2]
          if not collection
            msg = "Couldn't find a collection to update in expression."
            throw new Error msg
          
          [objExpression, queryExpression] = subQuery.split collection
          collection = transformCollectionName collection
          
          object = {}
          queryRgx = new RegExp /\s?(with|where|for|and|or)?\s?\b(.+?)\s?(\:|to|as)\s?(.+?)\b/g
          while match = queryRgx.exec objExpression
            [match, s1, name, s2, value] = match
            value = selectType _.namespaces.global[value] or value
            object[name] = value
          
          query = {}
          queryRgx = new RegExp /\s?(with|where|if|for|and|or|,)?\s?(\S+?)\s?(\:|is|<|>)\s?(lesser than|less than|<)?(greater than|>)?\s?(\S+?)\b/g
          while match = queryRgx.exec queryExpression
            [match, s1, name, mod, lesser, greater, value] = match
            value = selectType _.namespaces.global[value] or value
            
            subExpression =
              if lesser or mod is '<' then "<": value
              else if greater or mod is '>' then ">": value
              else value
            
            if not query[name]? then query[name] = []
            query[name].push subExpression
            
          result = update collection, query, object
          
        # -------------------------------------------------------------------------------------
        when 'delete', 'destroy', 'remove'
          [subQuery, collection] = getCollection subQuery
          
          queryRgx = new RegExp /\s?(with|where|for|and|or)?\s?\b(.+?)\s?(\:|is|as)\s?(.+?)\b/g
          query = {}
          while match = queryRgx.exec subQuery
            query[match[2]] = match[4]
          
          result = remove collection, query
        
        # -------------------------------------------------------------------------------------
        when 'when'
          [subQuery, collection] = getCollection subQuery
          # when a test's title is example -- Returns a hook
          # Call myFunc when a test's title is example
          # When a test's title is example, print tests where title is example.
          
          # TODO: bind query to be called when write and update methods are called
          # return a hook function that accepts any number of handler functions
          # handler functions will recieve access to the subscribed object
          # updates and writes can be prevented by returning false in any handler
          
        # -------------------------------------------------------------------------------------
        when 'let', 'var', 'def', 'define'
          [subQuery, variable] = getName subQuery
          [subQuery, value] = getName subQuery
          
          if value in ['equal', 'equals', 'be', '=']
            [subQuery, value] = getName subQuery
          
          argumentNames = []
          if value is 'of'
            funcRgx = new RegExp /\s?(\(|of|and|,)?(\)|equal|equals|=)?\s?\b(.+?)\b/g
            while match = funcRgx.exec subQuery
              [match, s1, stop, name] = match
              if stop? then break
              else if name? then argumentNames.push name
          else subQuery = value + subQuery
            
          console.log {subQuery, value}
          subQuery = subQuery.replace /^.+(\)|equal|equals|=)/, ''
          subQuery = subQuery.replace /divided by/g, '/'
          subQuery = subQuery.replace /is like/g, '=='
          subQuery = subQuery.replace /isnt like/g, '!='
          
          operations = []
          words = subQuery.split /\s/g
          
          expression = ''
          for word in words
            expression += ' ' +
              switch word
                when 'plus' then '+'
                when 'minus' then '-'
                when 'over' then '/'
                when 'times' then '*'
                when 'not' then '!'
                when 'isnt' then '!=='
                when 'is' then '==='
                else word
            
          console.info {expression}
          
          if argumentNames.length > 0
            lines = expression.split /[\n\r]/g
            lines[lines.length - 1] = 'return ' + lines[lines.length - 1]
            expression = lines.join '\\n'
            
            _.namespaces.global[variable] =
              new Function argumentNames, expression
            result = _.namespaces.global[variable]
          else
            val = try eval expression catch err
              console.error err
            if val? then value = val
          
            # keywords
            # plus, minus, divided by, times, not, is,
            # isnt, equals, in, and, or, nor, unless,
            # for, while, from, at, as, on, of, where,
            # if, otherwise, else, then, do
            #
            # transforms
            # plus, minus, divided by, times, not, is, isnt, equals
            # controls
            # <expression> for <map> <query>
            # <expression> while <condition>
            # <expression> if <condition>
            # for <map> <query> do <expression>
            # while <condition> do <expression>
            # if <condition> then <expression> otherwise <expression>
            
            value = selectType value
            _.namespaces.global[variable] = value
            console.info {value}
            result = value
        
        # -------------------------------------------------------------------------------------
        when 'call', 'run', 'do', 'go', 'invoke'
          [subQuery, method] = getName subQuery
          
          if not _.namespaces.global[method]?
            throw new Error "Method '#{method}' does not exist"
          else if typeof _.namespaces.global[method] isnt 'function'
            throw new Error "Variable '#{method}' is not a function"
          else method = _.namespaces.global[method]
          
          
          argumentList = [2,3]
          queryRgx = new RegExp /\s?(with|where|for|and|,)?\s?(\d{1,2}\/\d{1,2}\/\d{2,4}|.+?)?\b/g
          while false and match = queryRgx.exec subQuery
            [match, s1, value] = match
            
            value = selectType _.namespaces.global[value] or value
            argumentList.push = value
          
          console.log {method}
          result = method.apply null, argumentList
          
        # -------------------------------------------------------------------------------------
        else
          msg = "Couldn't find a valid keyword at start of expression: \"#{expression}\""
          throw new Error msg
        
      results.push result
          
    console.log {results}
    return if results.length > 1 then results
    else if results[0] then results[0] else null
  return _
          

  
# Basic test setup

Literate.database.test = [
  {title:"sample", date: new Date}
  {title:"test", date: new Date '1/18/1991'}
  {title:"test", content:''}
  {title:"sample", content:"Real live content"}
]

testMql = (query, errMessage, condFn) ->
  console.log "Testing: '#{query}\'"
  result = Literate.eval query
  if result?.err then errMessage += " | Error - #{result.err}"
  unless condFn.call result then throw new Error errMessage


# Basic CRUD functionality tests
  
testMql "Read test title:sample", "Read didn't work as expected", ->
  @[0].title is "sample" and @[1].content is "Real live content"

testMql "Get from test where title is sample", "Read didn't work as expected", ->
  @[0].title is "sample" and @[1].content is "Real live content"
  
testMql "Read from test (best collection ever) where title is sample",
  "Read didn't work as expected", ->
    @[0].title is "sample" and @[1].content is "Real live content"

testMql "Read from test if title is sample -- this is great",
  "Read didn't work as expected", ->
    @[0].title is "sample" and @[1].content is "Real live content"
  
testMql "Write to test title:Example content:example",
  "Write didn't work as expected",
    -> not @err and Literate.database.test.length is 5
  
testMql "Insert into tests with title as Example and content as example",
  "Write didn't work as expected",
    -> not @err and Literate.database.test.length is 6

testMql "Read test title:test. Add to test title:Example content:example",
  "Read/write didn't work as expected", ->
    @[0][0].title is "test" and @[0][1].content is "" and
      not @[1].err and Literate.database.test.length is 7
      
testMql "Set title to test and content to sample in tests",
  "Update didn't work as expected", ->
    @every (obj) -> obj.title is 'test' and obj.content is 'sample'
    
testMql "Update title as sample and content as test for tests",
  "Update didn't work as expected", ->
    @every (obj) -> obj.title is 'sample' and obj.content is 'test'
    
testMql "Set title:test content:sample in tests where title:sample",
  "Update didn't work as expected", ->
    @every (obj) -> obj.title is 'test' and obj.content is 'sample'

testMql "Remove from tests where title is test",
  "Remove didn't work as expected", -> @length is 0

  
alert 'Basic crud tests passed!'


# Operations and expression modifier tests

testMql "Add test name is awesome id is 1 and date is 01/18/1992",
  "Write didn't work as expected", ->
    not @err and Literate.database.test.length is 1

testMql "Add test with name as awesome id as 2 and date as 01/18/1991.
  Add test whose name is alright and date is 01/18/1993",
    "Write didn't work as expected", ->
      not @err and Literate.database.test.length is 3

testMql "Read from tests where name is awesome then order by date",
  "Read/order by date didn't work as expected", ->
    @[0].id is 2 and @[0].name is "awesome" and
    @[0].date.getTime() is (new Date "01/18/1991").getTime()

testMql "Add test name is awesome id is 3 and date is 01/18/1993",
  "Write didn't work as expected", ->
    not @err and Literate.database.test.length is 4
    
testMql "Read from tests where name is awesome then order by date",
  "Read/order by date didn't work as expected", ->
    @[0].date.getTime() is (new Date "01/18/1991").getTime() and
    @[1].date.getTime() is (new Date "01/18/1992").getTime() and
    @[2].date.getTime() is (new Date "01/18/1993").getTime()

testMql "Read from tests where name is awesome then order by date descending",
  "Read/order by date descending didn't work as expected", ->
    @[2].date.getTime() is (new Date "01/18/1991").getTime() and
    @[1].date.getTime() is (new Date "01/18/1992").getTime() and
    @[0].date.getTime() is (new Date "01/18/1993").getTime()

    
alert 'Operation and expression modifier tests passed!'
    

# Advanced test setup

Literate.database.test = [
  {title:"test0", content: "test0", number: 35, date: (new Date "11/5/15")}
  {title:"test0", content: "test1", number: 46, date: (new Date "11/6/15")}
  {title:"test1", content: "test0", number: 14, date: (new Date "11/7/15")}
  {title:"test1", content: "test1", number: 26, date: (new Date "11/8/15")}
  {title:"test2", content: "test1", number: 9, date: (new Date "11/9/15"), data: [1,2,3]}
  {title:"test2", content: "test2", number: 3, date: (new Date "11/10/15")}
  {title:"test1", content: "test2", number: 6, date: (new Date "11/11/15")}
  {title:"test2", content: "test1", number: 4, date: (new Date "11/12/15")}
  {title:"test2", content: "test0", number: 5, date: (new Date "11/13/15")}
]


# Advanced CRUD tests

testMql "Read test where title is test2 and content is test1 then order by date",
  "Read didn't work as expected", ->
    @[0].data.length is 3 and @[1].date.getTime() is (new Date "11/12/15").getTime()

testMql "Get from test where title is test2 and content is test1 then order by date descending",
  "Read didn't work as expected", ->
    @[1].data.length is 3 and @[0].date.getTime() is (new Date "11/12/15").getTime()
    
testMql "Read tests where number is less than 10 then order by number",
  "Read w/ less than didn't work as expected", ->
    @[0].number is 3 and @[1].number is 4 and @[2].number is 5 and
    @[3].number is 6 and @[4].number is 9 and @length is 5

testMql "Read tests number < 9 then order by number",
  "Read w/ less than didn't work as expected", ->
    @[0].number is 3 and @[1].number is 4 and @[2].number is 5 and
    @[3].number is 6 and @length is 4

testMql "Read tests number < 9 and number > 3 then order by number",
  "Read w/ less/greater than didn't work as expected", ->
    @[0].number is 4 and @[1].number is 5 and @[2].number is 6 and @length is 3
    
testMql "Read tests 4 < number < 9 then order by number",
  "Read w/ less/greater than didn't work as expected", ->
    @[0].number is 5 and @[1].number is 6 and @length is 2
   
testMql "Read tests where 4 < number < 6",
  "Read w/ less/greater than didn't work as expected", ->
    @[0].number is 5 and @length is 1
    
testMql "Read tests 1 < number < 4 number-",
  "Read w/ less/greater than didn't work as expected", ->
    @[0].number is 3 and @length is 1

testMql "Let myVar equal example",
  "Simple assignment didn't work as expected", ->
    Literate.namespaces.global.myVar is 'example'
  
testMql "
  Let bestVariable equal lols.
  Set title to bestVariable in tests where title is test0 and content is test0.
  Read tests where title is bestVariable",
  "Assignment with update didn't work", ->
    Literate.namespaces.global.bestVariable is 'lols' and @[2][0].number is 35
    
testMql "
  Let bestVariable equal lols.
  Set title to bestVariable in tests where title is test0 and content is test0.
  Read tests where title is bestVariable",
  "Assignment with update didn't work", ->
    Literate.namespaces.global.bestVariable is 'lols' and @[2][0].number is 35
    
testMql "Let result equal 2 plus 3 minus 6 times 2 divided by 3",
  "Static expression didn't work.", -> @toString() is 1.toString()

testMql "
  Let myFunc of x and y equal x plus y.
  Call myFunc with 2 and 3",
  "Function definition and call didn't work", -> @[1] is 5
  
testMql "
  Let myFunc of x and y equal x plus y.
  Call myFunc with test-number and test-number for tests where title is test1 number+",
  "Function definition and call with query didn't work", ->
    @[0] is 12 and @[1] is 28 and @[2] is 52 and @length is 3
    
alert 'All tests passed!'