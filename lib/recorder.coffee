CodeMirror = require("codemirror")
_ = require("underscore")



Recorder = (options={}) ->
  _locked = false
  _editor = options.editor || {}
  _timer = IntervalTimer()
  _speed = 2.5
  _playing = false
  _location =
    offset: options.offset || 0
    branch: Date.now().toString()
  _shortcutHistory = []

  api = {}
  
  api.playing = ->    _playing
  api.play = ->       api.playing = true; play()
  api.stop = ->       api.playing = false
  api.togglePlay = -> api.playing = !api.playing; play()

  api.speed = ->            _speed
  api.setSpeed = (speed) -> _speed = speed

  api.location = ->  _(_location).clone()

  api.shortcutHistory = -> _shortcutHistory.slice()

  if !options.history
    history = {}
    history[_location.branch] = 
      name: _location.branch
      ops: []
      offset: 0
      preOffset: 0
      ancestors: []
  
  api.loadEditor = (editor) ->
    _editor = editor
    _editor.on 'change', editorEvent("change")
    _editor.on 'cursorActivity', editorEvent("cursor")
    _editor.on 'keyHandled', editorEvent("key")
    # e.on "changes", (cm, changes) -> console.log "here", changes.length
    
  api.branch = (name=null) ->
    if !name
      return history[_location.branch]
    history[name]

  editorEvent = (name) ->
    =>
      return if _locked == true
      change = changeHandlers[name].apply(this, arguments)
      change.index = history[_location.branch].ops.length
      change.time = _timer.getInterval()
      if _location.offset != api.branch().ops.length
        # We are not at the end of a branch, so create a new one:
        if change.type != "text"
          return
        branchName = Date.now().toString()
        newBranch =
          name: branchName
          ops: []
          ancestors: api.branch().ancestors.concat([_location.branch]) 
          offset: _location.offset
          preOffset: api.branch().preOffset + _location.offset
        
        history[branchName] = newBranch
        _location = 
          branch: branchName
          offset: 0

      branch = history[_location.branch]
      if change.time < 10 and branch.ops.length > 0
        # append this to the last changeset if time delta is < 10ms
        index = branch.ops.length-1
        changeset = branch.ops[index]
        changeset.push(change)
      else
        branch.ops.push([change])
        _location.offset = _location.offset+1

  play = ->
    if _location.offset == api.branch().ops.length or api.playing == false
      return
    api.goTo {branch: _location.branch, location: _location.offset+1}
    setTimeout play, changeTimeout(api.branch().ops[_location.offset-1])
    false
  
  api.goTo = (destination) ->
    # operations = opsFromList(history[_location.branch].ops, _location.offset, destination.offset)
    operations = opsBetweenLocations(history, _location, destination)
    if operations.length > 0
      # _location.offset = Math.round(offset)
      _locked = true
      _editor.operation ->
        for changes in operations
          applyChanges(_editor, changes)
      _locked = false
    _location = destination
    
  api.branches = ->
    bars = []
    width = 0
    for key, val of history
      totalWidth = val.preOffset + val.ops.length
      bar = 
        name: key
        branch: val
        totalWidth: totalWidth
        active: key in api.branch().ancestors or key == _location.branch
      bars.push bar
      width = totalWidth if totalWidth > width
    bars = _(bars).sortBy((bar) -> bar.branch.preOffset)
    totalWidth: width
    bars: bars
  api


invertOperation = (op) ->
  if op.type != "text"
    return op
  newOp = _(op).clone()
  newOp.text = op.removed.slice()
  newOp.removed = op.text.slice()
  newOp.from = _(op.from).clone()
  if newOp.removed.join("*") != ""
    newOp.to = CodeMirror.changeEnd(op)
  else
    newOp.to = newOp.from
  newOp 

invertChanges = (changes) ->
  _(changes).map(invertOperation).reverse()

applyChanges = (editor, changes) ->
  for change in changes
    switch change.type
      when "text"
        editor.replaceRange change.text.join("\n"), change.from, change.to
      # when "key-combo"
      #   api.shortcutHistory = api.shortcutHistory.concat [change.name]
      when "cursor"
        editor.focus()
        editor.setCursor change.cursor
      when "selections"
        editor.setSelections change.selections

changeTimeout = (changes) ->
  switch changes[0].type
    when "key-combo" then 0
    else 100


changeHandlers =
  key: (cm, name, event) ->
    type: "key-combo"
    name: name
  change: (cm, change) ->
    type: "text"
    from: _(change.from).clone()
    to: _(change.to).clone()
    text: change.text.slice()
    removed: change.removed.slice()
  cursor: (cm) ->
    selections = cm.listSelections()
    if selections.length == 1 and selections[0].anchor.ch == selections[0].head.ch
      change =
        type: "cursor"
        cursor: selections[0].head
    else
      change = 
        type: "selections"
        selections: selections
    change

IntervalTimer = ->
  _lastEventTimestamp = Date.now()

  getInterval: ->
    now = Date.now()
    delta = now - _lastEventTimestamp
    _lastEventTimestamp = now
    return delta
  reset: ->
    _lastEventTimestamp = Date.now()

opsFromList = (list, i1, i2) ->
  [i1, i2] = [Math.round(i1), Math.round(i2)]
  # operations = Array.prototype.slice.apply(list, [i1, i2].sort().reverse())
  # if i1 > i2
  #   operations = _(operations).chain().reverse().map(invertChanges).value()
  # operations
  switch
    when i1 < i2
      list[i1...i2]
    when i1 > i2
      _(list[i2...i1]).chain().reverse().map(invertChanges).value()
    else
      []

pathBetweenLocations = (history, loc1, loc2, path=[]) ->

  [b1, b2] = [history[loc1.branch], history[loc2.branch]]
  # loc1 and loc2 are on the same branch. finish.
  if b1.name == b2.name
    path.push [b1.name, loc1.offset, loc2.offset]
    return path

  # b2 is a descendant of b1. move down the hierarchy toward it.
  if b1.name in b2.ancestors
    nextBranch = history[b2.ancestors[b2.ancestors.indexOf(b1.name)+1]] || b2
    path.push [b1.name, loc1.offset, nextBranch.offset]
    return pathBetweenLocations(history, {branch: nextBranch.name, offset: 0}, loc2, path)

  # b2 is an ancestor of b1, or a descendant of an ancestor of b1. move up the ancestor chain.
  nextBranch = history[b1.ancestors.slice(-1)[0]]
  path.push [b1.name, loc1.offset,0]
  return pathBetweenLocations(history, {branch: nextBranch.name, offset: b1.offset}, loc2, path)


opsBetweenLocations = (history, loc1, loc2) ->
  path = pathBetweenLocations(history, loc1, loc2)
  operations = []
  for p in path
    [branchName, i1, i2] = p
    operations = operations.concat opsFromList(history[branchName].ops, i1, i2)
  # [loc1, loc2] = [history[loc1.branch], history[loc2.branch]]
  # if loc1.name == loc2.name
  #   return opsFromList(loc1.ops, loc1.offset, loc2.offset)
  # branchNames = [loc1.branch].concat _(loc1.ancestors).without(loc2.ancestors), _(loc2.ancestors).without(loc1.ancestors)
  # if branchNames[branchNames.length-1] != loc2.branch
  #   branchNames.push loc2.branch
  # operations = []
  # currentOffset = loc1.offset
  # finalOffset = Math.round(loc2.offset)
  # for name, index in branchNames
  #   [b1, b2] = [history[name], history[branchNames[index+1]]]
  #   if typeof b2 == 'undefined'
  #     operations = operations.concat opsFromList(b1.ops, currentOffset, finalOffset)
  #     path.push "#{b1.name}: #{currentOffset}>#{finalOffset}"
  #   else if b1.ancestors[b1.ancestors.length-1] == b2.name
  #     operations = operations.concat opsFromList(b1.ops, currentOffset, 0)
  #     path.push "#{b1.name}: #{currentOffset}>#{0}"
  #     currentOffset = b1.offset
  #   else if b2.ancestors[b2.ancestors.length-1] == b1.name
  #     operations = operations.concat opsFromList(b1.ops, currentOffset, b2.offset)
  #     path.push "#{b1.name}: #{currentOffset}>#{b2.offset}"
  #     currentOffset = 0
  #   else
  #     path.push "LOST: #{b1.name}, #{currentOffset}"
  # console.log path, operations.length, operations
  operations

module.exports = Recorder