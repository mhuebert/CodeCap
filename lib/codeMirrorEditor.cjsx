React = require("react/addons")
CodeMirror = require("codemirror")
require("codemirror/keymap/sublime.js")
require("codemirror/mode/clojure/clojure.js")
window._ = _ = require("underscore")
{Vector} = require("immutable")
Draggable = require('react-draggable')

logChange = (change) ->
  "#{change.from.line}:#{change.from.ch} to #{change.to.line}:#{change.to.ch} - #{change.date}"

editorSettings = 
  mode: "clojure"
  lineNumbers: false
  lineWrapping: true
  smartIndent: true
  matchBrackets: true
  theme: 'solarized-light'
  keyMap: 'sublime'
  # editor.setOption("readOnly", true)

module.exports = React.createClass
  getInitialState: ->
    history: Vector()
    shortcutHistory: Vector()
    playbackLocation: 0

  componentDidMount: ->
    window.cm = @editor = CodeMirror.fromTextArea @refs.editor.getDOMNode(), editorSettings
    window.e2 = @editor2 = CodeMirror.fromTextArea @refs.editor2.getDOMNode(), _(editorSettings).chain().clone().extend({readOnly: true}).value()

    @editor.on 'changes', @handleChanges
    @editor.on 'cursorActivity', @handleCursorActivity
    @editor.on 'keyHandled', @handleKey

  _lastEvent: 0
  _historyIndex: 0
  getDelta: ->
    now = Date.now()
    delta = now - @_lastEvent
    @_lastEvent = now
    return delta
  
  handleKey: (cm, name, event) ->
    history = @state.history.concat [
      type: "key-combo"
      name: name
      time: @getDelta()
      index: @_historyIndex
    ]
    @_historyIndex += 1
    @setState history: history

  handleChanges: (cm, changes) ->
    # console.log _(changes).chain().flatten().map(logChange).value()
    history =  @state.history.concat [
      type: "text"
      time: @getDelta()
      index: @_historyIndex
      changes: changes.map (change, index) ->
        from: _(change.from).clone()
        to: _(change.to).clone()
        text: change.text.slice()
        removed: change.removed.slice()
        date: "#{index} - #{Date.now()}"
        index: index
    ]
    @_historyIndex += 1
    # console.log history.toJS().filter((change) -> change.type == "text").length
    @setState history: history


  handleCursorActivity: (cm) ->
    selections = cm.listSelections()
    if selections.length == 1 and selections[0].anchor.ch == selections[0].head.ch
      change =
        type: "cursor"
        cursor: selections[0].head
        time: @getDelta()
        index: @_historyIndex
    else
      change = 
        type: "selections"
        selections: selections
        time: @getDelta()
        index: @_historyIndex

    @_historyIndex += 1
    history = @state.history.concat [change]
    @setState history: history

  applyOperation: (change) ->
    console.log "Operation ##{change.index}"
    switch change.type
      when "text"
        for c in change.changes
          if change.changes.length > 1
            console.log "Operation...#{c.index}"
          @editor2.replaceRange c.text.join("\n"), c.from, c.to
      when "key-combo"
        @setState shortcutHistory: @state.shortcutHistory.concat [change.name]
      when "cursor"
        @editor2.focus()
        @editor2.setCursor change.cursor
      when "selections"
        @editor2.setSelections change.selections
  
  speed: 2.5

  play: ->
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
      @applyOperation change
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

  playbackLocationIndicatorPosition: ->
    width = this.refs.timeline?.getDOMNode().getBoundingClientRect().width

    # offset = switch
    #   when Math.ceil(@state.playbackLocation) == @state.history.length-1
    #     width - 3
    #   else
    Math.round (@state.playbackLocation / (Math.max(0, @state.history.length)) * width)

  goTo: (index) ->
    [currentLocation, finish] = [Math.round(@state.playbackLocation), Math.round(index)]
    operations = switch
      when currentLocation < finish
        console.log "moving from #{currentLocation} to #{finish}"
        @state.history.toJS()[currentLocation...finish]
      when currentLocation > finish
        console.log "moving from #{currentLocation} to #{finish} (inverse)"
        _(@state.history.toJS()[finish...currentLocation]).chain().reverse().map(@inverse).value()
      else
        []
    if operations.length == 0
      return
    # console.log "#{operations.length} operations"
    for change in operations
      @applyOperation(change)
    @setState playbackLocation: Math.round(index)
  
  invertOperation: (op) ->
    newOp = _(op).clone()
    newOp.text = op.removed.slice()
    newOp.removed = op.text.slice()
    newOp.from = _(op.from).clone()
    if op.text.join("") != ""
      newOp.to = CodeMirror.changeEnd(op)
    else
      newOp.to = _(op.to).clone()
    newOp

  inverse: (changeset) ->
    if changeset.type != "text"
      return changeset
    c = _(changeset).clone()
    c.changes = _(changeset.changes)
                        .chain()
                        .map(@invertOperation)
                        .sortBy (operation) -> 

                          console.log sortIndex = -(operation.from.line * 1000) + operation.from.ch
                          sortIndex
                        .value()
    c
  handleMouseMove: (e) ->
    timelineDimensions = this.refs.timeline.getDOMNode().getBoundingClientRect()
    mouseLeftOffset = (e.clientX - timelineDimensions.left)
    @setState playing: false
    if 0 <= mouseLeftOffset <= timelineDimensions.width
      percentOffset = (mouseLeftOffset/timelineDimensions.width)
      zeroIndexedFrame =  percentOffset * (Math.max @state.history.length, 0)
      @goTo zeroIndexedFrame

  back: ->
    @goTo Math.max(@state.playbackLocation-1, 0)
  forward: ->
    @goTo Math.min(@state.playbackLocation+1, @state.history.length)
  
  render: ->
    @transferPropsTo <div>
        <div id="codecap-source">
          <textarea className="editor-1" ref="editor" />
        </div>
        <div id="codecap-preview">
          <div className={"controls "+(if @state.playing then "playing" else "")}>
            <div onClick={@play}><a className="controls-play" href="#"></a></div>
            <div  onMouseMove={@handleMouseMove} ref="timeline" className="playback-line">
              <span style={{left: @playbackLocationIndicatorPosition()+"px"}} className="playback-location" />
            </div>
          </div>
          
          <textarea className="editor-2" ref="editor2" />
          <ul id="shortcut-history">
            {@state.shortcutHistory.toJS().reverse().slice(0,5).map((shortcut, i)-><li key={i}>{shortcut}</li>)}
            <li key="playback">
              Loc: {@state.playbackLocation}
              <br/>
              PlayPos:{@playbackLocationIndicatorPosition()}
              <br/>
              HistoryCount:{@state.history.length}
            </li>
            <li key="back"><a onClick={@back}>back</a></li>
            <li key="forward"><a onClick={@forward}>forward</a></li>
            
          </ul>
            
        </div>
      </div>