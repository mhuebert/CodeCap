_ = require("underscore")
{Vector} = require("immutable")
Draggable = require('react-draggable')
CodeMirror = require("codemirror")

logChange = (change) ->
  "#{change.from.line}:#{change.from.ch} to #{change.to.line}:#{change.to.ch} - #{change.date}"

module.exports = (editor) ->
  editor.on 'changes', @handleChanges
  editor.on 'cursorActivity', @handleCursorActivity
  editor.on 'keyHandled', @handleKey

  @handleKey = (cm, name, event) ->
    history = @state.history.concat [
      type: "key-combo"
      name: name
      time: @getDelta()
    ]
    @setState history: history

  @handleChanges = (cm, changes) ->
    # console.log _(changes).chain().flatten().map(logChange).value()
    history =  @state.history.concat [
      type: "text"
      time: @getDelta()
      changes: changes.map (change, index) ->
        from: _(change.from).clone()
        to: _(change.to).clone()
        text: change.text.slice()
        removed: change.removed.slice()
        date: "#{index} - #{Date.now()}"
    ]
    # console.log history.toJS().filter((change) -> change.type == "text").length
    @setState history: history


  @handleCursorActivity = (cm) ->
    selections = cm.listSelections()
    if selections.length == 1 and selections[0].anchor.ch == selections[0].head.ch
      change =
        type: "cursor"
        cursor: selections[0].head
        time: @getDelta()
    else
      change = 
        type: "selections"
        selections: selections
        time: @getDelta()
    history = @state.history.concat [change]
    @setState history: history

  @applyChange = (change) ->

    switch change.type
      when "text"
        for c in change.changes
          @editor2.replaceRange c.text.join("\n"), c.from, c.to
      when "key-combo"
        @setState shortcutHistory: @state.shortcutHistory.concat [change.name]
      when "cursor"
        @editor2.focus()
        @editor2.setCursor change.cursor
      when "selections"
        @editor2.setSelections change.selections
  @getDelta = ->
    now = Date.now()
    delta = now - @_lastEvent
    @_lastEvent = now
    return delta
  @speed = 2.5

  @play = ->
    if @state.playing or @state.history.length == 0
      @setState {playing: false}
      return
    
    if @state.playbackLocation == @state.history.length-1 
      startLocation = 0
      @goTo 0
    else 
      startLocation = @state.playbackLocation+1

    playFrom = (frameIndex) =>
      if frameIndex == @state.history.length or !@state.playing
        @setState {playing: false}
        return
      change = @state.history.get(frameIndex)
      @applyChange change
      timeOut = switch change.type
        when "key-combo" then 0
        else 30
      @setState {playbackLocation: frameIndex}, ->
        setTimeout ->
          playFrom(frameIndex+1)
        , Math.min((change.time/@speed), 500)
    @setState {playing: true}, ->
      playFrom(Math.round startLocation)
    false

  @playbackLocationIndicatorPosition = ->
    width = this.refs.playbackLine?.getDOMNode().getBoundingClientRect().width

    # offset = switch
    #   when Math.ceil(@state.playbackLocation) == @state.history.length-1
    #     width - 3
    #   else
    Math.round (@state.playbackLocation / (@state.history.length-1) * width)

  @goTo = (index) ->
    [start, finish] = [Math.round(@state.playbackLocation), Math.round(index)]
    operations = switch
      when start < finish
        @state.history.toJS()[start..finish]
      when start > finish
        _(@state.history.toJS()[finish...start]).chain().filter((change) -> change.type in ["text", "key-combo"]).reverse().map(@inverse).value()
      else
        []
    if operations.length == 0
      return
    console.log [start, finish]
    for change in operations
      @applyChange(change)
    # console.log _(@state.history.toJS()).pluck("type")
    @setState playbackLocation: Math.round(index)
  
  @invertOperation = (op) ->
    newOp = _(op).clone()
    newOp.text = op.removed.slice()
    newOp.removed = op.text.slice()
    newOp.from = _(op.from).clone()
    if op.text.join("") != ""
      newOp.to = CodeMirror.changeEnd(op)
    else
      newOp.to = _(op.to).clone()
    newOp

  @inverse = (changeset) ->
    if changeset.type != "text"
      return changeset
    c = _(changeset).clone()
    c.changes = _(changeset.changes)
                        .chain()
                        .sortBy((change)->(change.to.line*1000 + change.ch))
                        .map(@invertOperation)
                        # .map((change)->console.log(logChange(change));change)
                        .value()
    # if c.changes.length > 1
    #   console.log c.changes.map(logChange)
    c
  @handleMouseMove = (e) ->
    playbackLine = this.refs.playbackLine.getDOMNode()
    rect = playbackLine.getBoundingClientRect()
    distanceFromLeft = (e.clientX - rect.left)
    @setState playing: false
    if 0 <= distanceFromLeft <= rect.width
      @goTo (distanceFromLeft/rect.width) * @state.history.length-1
  @back = ->
    @goTo Math.max(@state.playbackLocation-1, 0)
  @forward = ->
    @goTo Math.min(@state.playbackLocation+1, @state.history.length-1)