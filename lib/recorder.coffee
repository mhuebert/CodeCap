CodeMirror = require("codemirror")
_ = require("underscore")

earliestBranch = (history) ->
  parseInt(_(history).chain().keys().sort().value())

cleanHistory = (history) ->
  for name, branch of history
    history[name].ops = _(branch.ops).map (ops) -> _(ops).filter (op) -> op.type != "cursor" and op.type != "selections"
  history  

blankHistory = ->

  h = {}
  branch = Date.now().toString()
  h[branch] = 
    name: branch
    ops: []
    offset: 0
    preOffset: 0
    ancestors: []
    children: []
    annotations: []
  h  

Recorder = (options={}) ->
  _locked = false
  _editor = options.editor
  _timer = IntervalTimer()
  _speed = 2.5
  _playing = false
  _triggerRender = options.triggerRender || ->
  _location = _root = history = _marker = _shortcutHistory = null  
  
  setHistory = (h) ->
    history = h || blankHistory()
    _root = earliestBranch(history)
    _location = _marker = 
      offset: 0
      branch: _root 
    _shortcutHistory = []
  setHistory(options.history)

  api = {}

  api.beginning = ->
    branch: _root
    offset: 0
  api.ending = ->
    finalBranch = _(history).chain().values().sortBy((branch)->-parseInt(branch.name)).value()[0]
    branch: finalBranch.name
    offset: finalBranch.ops.length
  api.speed = ->            _speed
  api.setSpeed = (speed) -> _speed = speed

  api.location = ->  
    location = _(_location).clone()
    location.preOffset = history[_location.branch].preOffset
    location
  api.marker = ->  
    marker = _(_marker).clone()
    marker.preOffset = history[_marker.branch].preOffset
    marker
  api.goToMarker = -> api.goToLocation(_marker)

  api.shortcutHistory = -> _shortcutHistory.slice()

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
          children: []
          ops: []
          ancestors: api.branch().ancestors.concat([_location.branch]) 
          offset: _location.offset
          preOffset: api.branch().preOffset + _location.offset
          annotations: []
        
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
      _marker = _(_location).clone()


  beforeChange = (cm, change) -> 
    if !api.locationsEqual(_location, _marker) and _playing == false and _locked == false
      change.cancel()  

  _listeners = []  
  api.initialize = (options) ->
    _editor = _editor || options.editor
    
    _triggerRender = options.triggerRender || _triggerRender
    _listeners = [["change", editorEvent("change")], 
                  ["cursorActivity", editorEvent("cursor")],
                  ["keyHandled", editorEvent("key")],
                  ["beforeChange", beforeChange]]

    if _triggerRender
      _listeners.push(["change", (-> _triggerRender())])              
    for listener in _listeners
      _editor.on listener[0], listener[1]
    if options.history  
      setHistory(options.history)  

  api.dispose = ->
    for listener in _listeners
      _editor.off listener[0], listener[1]  

  api.locationsEqual = (b1, b2) ->
    b1.branch == b2.branch and Math.round(b1.offset) == Math.round(b2.offset)
  api.branch = (name=null) ->
    if !name
      return history[_location.branch]
    history[name]

  

  api.playing = ->    _playing
  api.play = ->       play()
  api.stop = ->       _playing = false
  api.togglePlay = -> 
    if _playing
      _playing = false
      return
    navigate {branch: _root, offset: 0}
    play()

  play = ->
    api.playTo(_marker)
  api.playTo = ->
    # _playing = true
    playTo.apply(this, arguments)
  playTo = (destination, options={transition:1}) ->
    return if _playing == true
    _playing = true
    _marker = destination
    startTime = Date.now()
    totalPath = pathBetweenLocations(history, _location, destination)
    totalOperations = _(totalPath).reduce (sum, segment) ->
      sum + Math.abs(segment[1] - segment[2])
    , 0
    stepForward = =>
      
      transition = options.transition # Math.min(4, Math.max(options.transition, (totalOperations / 30)))


      # Find the target operation based on transition time
      delta = Date.now() - startTime
      percent = Math.min delta/(transition * 1000), 1
      targetOperation = Math.round(percent * totalOperations)

      # Step through totalPath to find the target operation
      operationCount = 0
      for segment, segI in totalPath

        # console.log "segI #{segI}"
        nextSegment = totalPath[segI+1]
        
        # how many operations in this segment?
        segmentOperationCount = Math.round Math.abs(segment[1] - segment[2])
        
        # are we moving forwards or backwards?
        direction = if segment[1] < segment[2] then 1 else -1

        # is the target is in this segment?
        if targetOperation <= operationCount + segmentOperationCount
          if targetOperation == totalOperations and nextSegment and 0 == nextSegment[1] - nextSegment[2] 
            target =
              branch: nextSegment[0]
              offset: nextSegment[1]
          else
            target =
              branch: segment[0]
              offset: Math.round(segment[1] + (direction * (targetOperation - operationCount)))
          break

        # increment the operationcount
        operationCount += segmentOperationCount

      # we have our next operation
      if _playing == false or api.locationsEqual(_location, destination)
        _playing = false
        _triggerRender()
        return

      navigate target
      requestAnimationFrame(stepForward)

      # [branch, i1, i2] = pathBetweenLocations(history, _location, destination)[0]
      # if i1 == i2 #
      #   [branch, i1, i2]  = pathBetweenLocations(history, _location, destination)[1]
      # direction = if i1 < i2 then 1 else -1
      # navigate { branch: branch, offset: i1+direction }
      # setTimeout stepForward, 16
      # stepForward()

    stepForward()
    false

  api.goToPercentOffset = (destination, percentOffset) ->
    destinationBranch = history[destination.branch]
    absoluteOffset = destinationBranch.preOffset + destination.offset
    targetOffset = percentOffset * absoluteOffset
    target = {}
    ancestorChain = destinationBranch.ancestors.concat [destinationBranch.name]
    for ancestorName, index in ancestorChain

      [ancestor, nextAncestor] = [history[ancestorName], history[ancestorChain[index+1]]]
      upperOffsetBound = if nextAncestor then (ancestor.preOffset + nextAncestor.offset) else ancestor.preOffset + ancestor.ops.length
      if targetOffset < upperOffsetBound
        target.branch = ancestor.name
        target.offset = targetOffset - ancestor.preOffset
        break
    api.goToLocation(target)
  api.history = -> history
  api.annotate = (callback=->) ->
    if !(_(history[_location.branch].annotations).find (note) -> api.locationsEqual(note.loc, _location))
      annotation = 
        loc:
          branch: _location.branch
          offset: Math.round(_location.offset)
        time: Date.now()
      history[_location.branch].annotations.push annotation
      _triggerRender ->
        callback(annotation)
    _editor.focus()
    annotation
  api.updateAnnotation = (annotation) ->
    original = _(history[annotation.loc.branch].annotations).find (a) -> a.time == annotation.time
    original.title = annotation.title
    _triggerRender()
  api.setMarkerHere = ->
    _marker = 
      branch: _location.branch
      offset: Math.round(_location.offset)
    
    _editor.focus()
    _triggerRender()
    false

  navigate = (destination) ->
    return if !destination.branch?
    destination.offset = Math.round(destination.offset)
    operations = opsBetweenLocations(history, _location, destination)
    
    # operations = _.filter operations, (op)->
      
    #   op[1]?.type != "selections" and op[0].type != "selections"
    if operations.length > 0
      _locked = true
      _editor.operation ->
        for changes in operations
          applyChanges(_editor, changes)
      _locked = false  
    _triggerRender()
    _location = destination

  api.goToLocation = (destination) ->
    return if _playing == true # or !api.locationsEqual(_marker, destination)
    navigate(destination)
  api.editor = ->
    _editor  
  api.branches = ->
    bars = []
    annotations = []
    width = 0
    
    currentBranch = history[_location.branch]
    ancestors = currentBranch.ancestors.concat(_location.branch)

    # childIndex = indexByChildren(history)
    # sortedBranches = []
    # addSortedBranch = (branch) ->
    #   sortedBranches.push(branch)
    #   children = (childIndex[branch.name] || []).map (n) -> history[n]
    #   children = _(children).sortBy (child) -> -parseInt(child.name)
    #   for child in children
    #     addSortedBranch(child)
    # addSortedBranch(history[_root])

    for name, branch of history
      # for branch in sortedBranches
      #   name = branch.name
      totalWidth = branch.preOffset + branch.ops.length
      activeWidth = switch
        when name == _location.branch
          _location.offset / branch.ops.length * 100
        when name in ancestors
          offset = history[ancestors[ancestors.indexOf(name)+1]].offset
          offset / branch.ops.length * 100
      active = name in api.branch().ancestors or name == _location.branch
      indicators = []
      annotations = annotations.concat branch.annotations
      for annotation in branch.annotations
        annotation.styles = 
          left: (annotation.loc.offset / branch.ops.length)*100+"%"

      if _marker.branch == name
        indicators.push
          className: "targetIndicator "+(if Math.round(_marker.offset) == Math.round(branch.ops.length) then "action-append" else "action-branch")
          styles: {left: (_marker.offset / branch.ops.length)*100+"%"}
      if _location.branch == name
        indicators.push
          className: "playbackLocation"
          styles: {left:(_location.offset / branch.ops.length)*100+"%"}
      if activeWidth > 0
        indicators.push
          className: "activeAreaOfBar"
          styles: {width: activeWidth+"%"}
      bar = 
        name: name
        branch: branch
        totalWidth: totalWidth
        activeWidth: activeWidth || 0
        active: active
        indicators: indicators
        annotations: branch.annotations
      bars.push bar
      width = totalWidth if totalWidth > width
    # New updates always appear at bottom
    bars = _(bars).sortBy (bar) -> parseInt(bar.name)

    totalWidth: width
    bars: bars
    annotations: _(annotations).chain()
                    .sortBy((note) -> parseFloat note.loc.offset)
                    .sortBy((note)->parseInt(note.loc.branch))
                    .value()
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
        # api.shortcutHistory = api.shortcutHistory.concat [change.name]
      when "cursor"
        # editor.focus()
        editor.setCursor change.cursor
      when "selections"
        editor.setSelections change.selections

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
  nextBranch = history[b1.ancestors[b1.ancestors.length-1]]
  path.push [b1.name, loc1.offset,0]
  return pathBetweenLocations(history, {branch: nextBranch.name, offset: b1.offset}, loc2, path)


opsBetweenLocations = (history, loc1, loc2) ->
  path = pathBetweenLocations(history, loc1, loc2)
  operations = []
  for p in path
    [branchName, i1, i2] = p
    operations = operations.concat opsFromList(history[branchName].ops, i1, i2)
  operations

indexByChildren = (history) ->
  index = {}
  for name, branch of history
    if parent = branch.ancestors[branch.ancestors.length-1]
      index[parent] = index[parent] || []
      index[parent].push(name)
  index

module.exports = Recorder
