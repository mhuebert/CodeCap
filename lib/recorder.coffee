CodeMirror = require("codemirror")

module.exports = Recorder = (options={}) ->
  _locked = false
  _lastEvent = 0
  exp = {}
  exp.speed = 2.5
  exp.playing = false
  exp.currentOffset = options.currentOffset || 0
  exp.shortcutHistory = options.shortcutHistory || []

  editor = options.editor || {}
  if !options.history
    newBranchName = Date.now()
    history = {}
    history[newBranchName] = {ops: []}
    currentBranch = newBranchName

  # todo: handle passing in a branch / handle passing in a history without a branch
  currentBranch = options.currentBranch || newBranchName
    
  
  exp.loadEditor = (e) ->
    e.on 'change', editorEvent("change")
    e.on 'cursorActivity', editorEvent("cursor")
    e.on 'keyHandled', editorEvent("key")
    editor = e

  getDelta = ->
    now = Date.now()
    delta = now - _lastEvent
    _lastEvent = now
    return delta

  exp.currentBranch = ->
    history[currentBranch]

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
      
  editorEvent = (name) ->
    =>
      return if _locked == true
      change = changeHandlers[name].apply(this, arguments)
      change.index = history[currentBranch].ops.length
      change.time = getDelta()
      branch = history[currentBranch]
      if change.time < 10 and branch.ops.length > 0
        index = branch.ops.length-1
        changeset = branch.ops[index]
        changeset.push(change)
      else
        branch.ops.push([change])
        exp.currentOffset = exp.currentOffset+1
  applyOperation = (changes) ->
    for change in changes
      switch change.type
        when "text"
          editor.replaceRange change.text.join("\n"), change.from, change.to
        when "key-combo"
          exp.shortcutHistory = exp.shortcutHistory.concat [change.name]
        when "cursor"
          editor.focus()
          editor.setCursor change.cursor
        when "selections"
          editor.setSelections change.selections
  exp.togglePlay = ->
    exp.playing = !exp.playing
    play()
  play = ->
    return false if exp.playing == false
    branch = history[currentBranch]
    if branch.ops.length == 0
      return
    if exp.currentOffset == branch.ops.length
      return

    change = branch.ops[exp.currentOffset]
    _locked = true
    applyOperation change
    _locked = false

    timeOut = switch change[0].type
      when "key-combo" then 0
      else 100
    exp.currentOffset = exp.currentOffset + 1
    setTimeout play, timeOut
    false
  exp.goTo = (index) ->
    exp.playing = false
    if Math.round(index) == 0
      _locked = true
      editor.doc.setValue ""
      _locked = false
      exp.currentOffset = 0
      return
    
    [currentLocation, finish] = [Math.round(exp.currentOffset), Math.round(index)]
    operations = switch
      when currentLocation < finish
        history[currentBranch].ops[currentLocation...finish]
      when currentLocation > finish
        _(history[currentBranch].ops[finish...currentLocation]).chain().reverse().map(inverse).value()
      else
        []
    if operations.length > 0
      exp.currentOffset = Math.round(index)
      _locked = true
      for change in operations
        applyOperation(change)
      _locked = false
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
  inverse = (changes) ->
    _(changes).map(invertOperation).reverse()
  exp.bars = ->
    bars = []
    for key, val of history
      bars.push 
        name: key
        ops: val.ops
        length: val.ops.length
    bars
  exp